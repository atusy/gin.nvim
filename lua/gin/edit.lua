local git = require("gin.git")
local uri = require("gin.uri")
local buffer = require("gin.buffer")
local M = {}

---GinEdit's relative paths are relative to the repository, as in Git tree objects.
function M.path(root, filename)
  local path = vim.fs.normalize(filename)
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

function M.decode(data, options)
  local encoding = options.enc or options.encoding or "utf-8"
  if encoding ~= "utf-8" and encoding ~= "utf8" then
    data = vim.fn.iconv(data, encoding, "utf-8")
  end
  local bomb = data:sub(1, 3) == "\239\187\191"
  if bomb then
    data = data:sub(4)
  end
  local ff = options.ff or options.fileformat or (data:find("\r\n", 1, true) and "dos" or "unix")
  local separator = ff == "dos" and "\r\n" or ff == "mac" and "\r" or "\n"
  local eol = data:sub(-#separator) == separator
  if eol then
    data = data:sub(1, -#separator - 1)
  end
  return vim.split(data, separator, { plain = true }),
    { bomb = bomb, endofline = eol, fileformat = ff, fileencoding = encoding }
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  assert(parsed.fragment, "GinEdit requires a path")
  local path = M.path(parsed.root, parsed.fragment)
  local treeish = (parsed.params.commitish or "") .. ":" .. path
  local data = git.run({ "show", treeish }, { cwd = parsed.root }).stdout
  local lines, options = M.decode(data, parsed.params)
  buffer.replace(buf, lines, parsed.root, vim.filetype.match({ filename = path, buf = buf }) or "")
  vim.b[buf].gin_path = path
  vim.bo[buf].modifiable = true
  for key, value in pairs(options) do
    vim.bo[buf][key] = value
  end
  vim.bo[buf].modified = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nowrite"
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
  local args = vim.deepcopy(vim.g.gin_edit_persistent_args or {})
  vim.list_extend(args, #opts.fargs == 0 and (vim.g.gin_edit_default_args or {}) or opts.fargs)
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
