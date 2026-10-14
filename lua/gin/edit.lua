local git = require("gin.git")
local uri = require("gin.uri")
local buffer = require("gin.buffer")
local unicode = require("gin.unicode")
local M = {}

---GinEdit's relative paths are relative to the repository, as in Git tree objects.
function M.path(root, filename)
  -- Repository paths are literal; filename-expression expansion happens earlier.
  if filename:sub(1, 1) == "~" then
    filename = "./" .. filename
  end
  local path = vim.fs.normalize(filename, { expand_env = false })
  if path:sub(1, 1) == "/" then
    local parent = vim.uv.fs_realpath(vim.fs.dirname(path))
    path = (parent or vim.fs.dirname(path)) .. "/" .. vim.fs.basename(path)
    assert(path:sub(1, #root + 1) == root .. "/", "Path is outside the repository: " .. filename)
    path = path:sub(#root + 2)
  end
  assert(
    path ~= "" and path ~= "." and path ~= ".." and not path:match("^%.%./"),
    "Invalid repository path: " .. filename
  )
  return path
end

function M.decode(data, options, buf)
  local encoding = options.enc or options.encoding
  local bomb
  if not encoding or encoding == "" then
    local candidates = vim.split(vim.o.fileencodings, ",", { plain = true })
    data, encoding, bomb = require("gin.encoding").detect(data, candidates)
  else
    data, bomb = require("gin.encoding").decode(data, encoding, { fatal = false })
  end
  local ff = options.ff or options.fileformat
  if not ff then
    local formats = vim.split(vim.o.fileformats, ",", { trimempty = true })
    local without_crlf = data:gsub("\r\n", "")
    if
      vim.tbl_contains(formats, "dos")
      and data:find("\r\n", 1, true)
      and not without_crlf:find("\n", 1, true)
    then
      ff = "dos"
    elseif vim.tbl_contains(formats, "unix") and data:find("\n", 1, true) then
      ff = "unix"
    elseif vim.tbl_contains(formats, "mac") and data:find("\r", 1, true) then
      ff = "mac"
    else
      ff = formats[1] or vim.bo[buf or 0].fileformat
    end
  end
  if ff == "dos" then
    -- Forced DOS reads still accept LF-only lines, as native file reads do.
    data = data:gsub("\r\n", "\n")
  end
  local separator = ff == "mac" and "\r" or "\n"
  local eol = data:sub(-#separator) == separator
  if eol then
    data = data:sub(1, -#separator - 1)
  end
  local lines = vim.split(data, separator, { plain = true })
  if ff == "mac" then
    -- Native Mac reads represent literal LF bytes as CR inside buffer lines.
    for i, line in ipairs(lines) do
      lines[i] = line:gsub("\n", "\r")
    end
  end
  return lines, { bomb = bomb, endofline = eol, fileformat = ff, fileencoding = encoding }
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  assert(parsed.fragment, "GinEdit requires a path")
  local path = M.path(parsed.root, parsed.fragment)
  local treeish = (parsed.params.commitish or "") .. ":" .. path
  local data = git.run({ "show", treeish }, { cwd = parsed.root, progress = true }).stdout
  local lines, options = M.decode(data, buffer.read_options(parsed.params), buf)
  buffer.replace(buf, lines, parsed.root, vim.filetype.match({ filename = path, buf = buf }) or "")
  vim.b[buf].gin_path = path
  vim.bo[buf].modifiable = true
  for key, value in pairs(options) do
    vim.bo[buf][key] = value
  end
  vim.bo[buf].modified = false
  local readonly = parsed.params.commitish and parsed.params.commitish ~= ""
  vim.bo[buf].modifiable = not readonly
  vim.bo[buf].buftype = readonly and "nowrite" or "acwrite"
end

function M.encode(buf)
  local binary = vim.bo[buf].binary
  local ff = binary and "unix" or vim.bo[buf].fileformat
  local separator = ff == "dos" and "\r\n" or ff == "mac" and "\r" or "\n"
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if ff == "mac" then
    for i, line in ipairs(lines) do
      lines[i] = line:gsub("\r", "\n")
    end
  end
  local data = table.concat(lines, separator)
  if vim.bo[buf].endofline or (data ~= "" and vim.bo[buf].fixendofline and not binary) then
    data = data .. separator
  end
  local encoding = vim.bo[buf].fileencoding
  if
    vim.bo[buf].bomb
    and not binary
    and (unicode.supports(encoding) or encoding == "" or encoding == "utf-8" or encoding == "utf8")
  then
    data = "\239\187\191" .. data
  end
  if unicode.supports(encoding) then
    data = unicode.encode(data, encoding)
  elseif encoding ~= "" and encoding ~= "utf-8" and encoding ~= "utf8" then
    data = vim.fn.iconv(data, "utf-8", encoding)
  end
  return data
end

function M.write(buf, name)
  local ignore_all = vim.tbl_contains(vim.split(vim.o.eventignore, ","), "all")
  local parsed = uri.parse(name)
  assert(
    not parsed.params.commitish or parsed.params.commitish == "",
    "Cannot write a revision buffer"
  )
  local path = M.path(parsed.root, assert(parsed.fragment, "GinEdit requires a path"))
  local records = git.run({ "ls-files", "--stage", "-z", "--", path }, { cwd = parsed.root }).stdout
  local mode
  for record in records:gmatch("([^%z]+)%z") do
    local candidate, stage, filename = record:match("^(%d+) %x+ (%d)\t(.*)$")
    if stage == "0" and filename == path then
      mode = candidate
    end
  end
  assert(mode, "Path has no stage-zero index entry: " .. path)
  local hash = vim.trim(
    git.run(
      { "hash-object", "-w", "--stdin", mode == "120000" and "--no-filters" or "--path=" .. path },
      { cwd = parsed.root, stdin = M.encode(buf), progress = true }
    ).stdout
  )
  git.run(
    { "update-index", "-z", "--index-info" },
    { cwd = parsed.root, stdin = mode .. " " .. hash .. "\t" .. path .. "\0", progress = true }
  )
  vim.bo[buf].modified = false
  vim.api.nvim_exec_autocmds("BufWritePost", { buffer = buf, modeline = false })
  if not ignore_all then
    require("gin.command").post()
  end
end

function M.insert(buf, name)
  local parsed = uri.parse(name)
  local path = M.path(parsed.root, assert(parsed.fragment, "GinEdit requires a path"))
  local data = git.run(
    { "show", (parsed.params.commitish or "") .. ":" .. path },
    { cwd = parsed.root, progress = true }
  ).stdout
  if data ~= "" then
    local lines = M.decode(data, buffer.read_options(parsed.params), buf)
    local after = vim.fn.line("'[")
    local empty = vim.api.nvim_buf_line_count(buf) == 1
      and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
    if empty then
      after = 0
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    else
      vim.api.nvim_buf_set_lines(buf, after, after, false, lines)
    end
    vim.api.nvim_buf_set_mark(buf, "[", after + 1, 0, {})
    vim.api.nvim_buf_set_mark(buf, "]", after + #lines, 0, {})
  end
  vim.api.nvim_exec_autocmds("FileReadPost", { pattern = name, modeline = false })
end

function M.open(root, path, options)
  options = options or {}
  return buffer.open(
    uri.format("ginedit", root, {
      commitish = options.commitish,
      enc = options.enc or options.encoding,
      ff = options.ff or options.fileformat,
    }, M.path(root, path)),
    options
  )
end

function M.command(opts)
  local args = require("gin.command").arguments("edit", opts.fargs)
  local options, residue = require("gin.command").parse(
    args,
    { "worktree", "opener", "enc", "encoding", "ff", "fileformat" }
  )
  assert(#residue == 1 or #residue == 2, "GinEdit expects [commitish] path")
  options.commitish = #residue == 2 and residue[1] or nil
  options.bang, options.smods = opts.bang, opts.smods
  return M.open(require("gin.worktree").current(options.worktree), residue[#residue], options)
end

return M
