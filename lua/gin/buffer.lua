local M = {}

function M.open(name, opts)
  local opener = opts.opener or "edit"
  if not vim.tbl_contains({ "edit", "split", "vsplit", "tabedit", "pedit" }, opener) then
    error("Unsupported Gin opener: " .. opener, 0)
  end
  local args = {}
  for _, spec in ipairs({ { "enc", "encoding" }, { "ff", "fileformat" } }) do
    local value = opts[spec[1]] or opts[spec[2]]
    if value then
      args[#args + 1] = "++" .. spec[1] .. "=" .. vim.fn.fnameescape(value)
    end
  end
  if #args > 0 then
    -- nvim_cmd does not parse ++opt arguments; let Ex parse the escaped command.
    args[#args + 1] = vim.fn.fnameescape(name)
    vim.api.nvim_cmd({
      cmd = "execute",
      args = {
        vim.fn.string(opener .. (opts.bang and "!" or "") .. " " .. table.concat(args, " ")),
      },
      mods = opts.smods,
    }, {})
  else
    vim.api.nvim_cmd(
      { cmd = opener, args = { vim.fn.fnameescape(name) }, bang = opts.bang, mods = opts.smods },
      {}
    )
  end
  local buf, win = vim.fn.bufnr(name), vim.api.nvim_get_current_win()
  if opener == "pedit" then
    for _, candidate in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.wo[candidate].previewwindow and vim.api.nvim_win_get_buf(candidate) == buf then
        win = candidate
        break
      end
    end
  end
  return buf, win
end

function M.replace(buf, lines, root, filetype)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "unload"
  vim.bo[buf].swapfile = false
  vim.b[buf].gin_worktree = root
  if vim.bo[buf].filetype ~= filetype then
    vim.bo[buf].filetype = filetype
  end
end

function M.lines(output)
  output = require("gin.csi").strip(output:gsub("\r\n", "\n"))
  if output:sub(-1) == "\n" then
    output = output:sub(1, -2)
  end
  return vim.split(output, "\n", { plain = true })
end

function M.read_options(options)
  local explicit = require("gin.command").parse(
    vim.split(vim.v.cmdarg, " ", { trimempty = true }),
    { "enc", "encoding", "ff", "fileformat" }
  )
  local result = vim.deepcopy(options or {})
  result.enc = explicit.enc or explicit.encoding or result.enc or result.encoding
  result.ff = explicit.ff or explicit.fileformat or result.ff or result.fileformat
  return result
end

function M.replace_output(buf, output, root, filetype, options)
  options = M.read_options(options)
  local lines, decoded = require("gin.edit").decode(output, options or {})
  if options and options.emojify ~= nil then
    lines = vim.tbl_map(require("gin.emoji").emojify, lines)
  end
  local plain, marks = require("gin.ansi").parse(lines)
  M.replace(buf, plain, root, filetype)
  require("gin.ansi").apply(buf, marks)
  vim.bo[buf].modifiable = true
  for key, value in pairs(decoded) do
    vim.bo[buf][key] = value
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

local function arguments(parsed)
  assert(parsed.fragment, "Gin buffer requires command arguments")
  if parsed.legacy then
    return vim.split(parsed.fragment:gsub("%$$", ""), " ", { plain = true })
  end
  return require("gin.uri").split(parsed.fragment)
end

function M.read(buf, name)
  local uri = require("gin.uri").parse(name)
  local args = {}
  if uri.params.monochrome == nil then
    for _, key in ipairs({ "branch", "diff", "status", "ui" }) do
      vim.list_extend(args, { "-c", "color." .. key .. "=always" })
    end
  end
  vim.list_extend(args, arguments(uri))
  local result = require("gin.git").run(args, {
    cwd = uri.root,
    processor = uri.params.processor,
    progress = true,
  })
  M.replace_output(buf, result.stdout, uri.root, uri.params.filetype or "gin-buffer", uri.params)
  if uri.params.diffjump then
    require("gin.diffjump").setup(buf)
  end
  if uri.params.difffold ~= nil then
    require("gin.difffold").setup(buf)
  end
end

function M.insert_output(buf, name, output)
  local options = require("gin.command").parse(
    vim.split(vim.v.cmdarg, " ", { trimempty = true }),
    { "enc", "encoding", "ff", "fileformat" }
  )
  if output ~= "" then
    local lines = require("gin.edit").decode(require("gin.csi").strip(output), options)
    if require("gin.uri").parse(name).params.emojify ~= nil then
      lines = vim.tbl_map(require("gin.emoji").emojify, lines)
    end
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

function M.insert(buf, name)
  local parsed = require("gin.uri").parse(name)
  local result = require("gin.git").run(
    arguments(parsed),
    { cwd = parsed.root, processor = parsed.params.processor, progress = "both" }
  )
  M.insert_output(buf, name, result.stdout)
end

function M.command(opts)
  local options, args = require("gin.command").parse(opts.fargs, {
    "worktree",
    "opener",
    "filetype",
    "monochrome",
    "emojify",
    "processor",
    "diffjump",
    "difffold",
    "enc",
    "encoding",
    "ff",
    "fileformat",
  })
  local root = require("gin.worktree").current(options.worktree)
  local uri = require("gin.uri")
  local name = uri.format("gin", root, {
    filetype = options.filetype or "gin-buffer",
    monochrome = options.monochrome and "" or nil,
    emojify = options.emojify and "" or nil,
    processor = options.processor,
    diffjump = options.diffjump == true and "" or options.diffjump,
    difffold = options.difffold and "" or nil,
    enc = options.enc or options.encoding,
    ff = options.ff or options.fileformat,
  }, uri.join(args))
  return M.open(name, { opener = options.opener, bang = opts.bang, smods = opts.smods })
end

return M
