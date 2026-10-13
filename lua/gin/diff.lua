local uri = require("gin.uri")
local buffer = require("gin.buffer")
local M = {}

function M.output(name)
  local parsed = uri.parse(name)
  local args = { "diff" }
  for _, key in ipairs(vim.fn.sort(vim.tbl_keys(parsed.params))) do
    if key ~= "commitish" and key ~= "enc" and key ~= "ff" then
      local prefix = key:sub(1, 1) == "-" and "" or "--"
      local value = parsed.params[key]
      args[#args + 1] = prefix .. key .. (value ~= "" and "=" .. value or "")
    end
  end
  if parsed.params.commitish then
    args[#args + 1] = parsed.params.commitish
  end
  args[#args + 1] = "--"
  vim.list_extend(args, parsed.fragment and vim.json.decode(parsed.fragment) or {})
  return require("gin.git").run(args, { cwd = parsed.root }).stdout, parsed.root
end

function M.read(buf, name)
  local output, root = M.output(name)
  buffer.replace_output(buf, output, root, "gin-diff", uri.parse(name).params)
  vim.bo[buf].syntax = "diff"
  require("gin.diffjump").setup(buf)
  require("gin.difffold").setup(buf)
end

function M.open(root, options)
  options = options or {}
  local params = vim.deepcopy(options.flags or {})
  params.commitish = options.commitish
  params.enc, params.ff = options.enc or options.encoding, options.ff or options.fileformat
  local paths = {}
  for _, path in ipairs(options.paths or {}) do
    paths[#paths + 1] = require("gin.edit").path(root, path)
  end
  return buffer.open(
    uri.format("gindiff", root, params, #paths > 0 and vim.json.encode(paths) or nil),
    options
  )
end

function M.command(opts)
  local args = vim.deepcopy(vim.g.gin_diff_persistent_args or {})
  vim.list_extend(args, #opts.fargs == 0 and (vim.g.gin_diff_default_args or {}) or opts.fargs)
  local options, residue = require("gin.command").parse(
    args,
    { "worktree", "opener", "enc", "encoding", "ff", "fileformat" }
  )
  options.flags, options.paths = {}, {}
  local path_mode = false
  for _, arg in ipairs(residue) do
    if path_mode then
      options.paths[#options.paths + 1] = arg
    elseif arg == "--" then
      path_mode = true
    elseif arg:sub(1, 1) == "-" then
      local key, value = arg:match("^%-%-([^=]+)=(.*)$")
      key = key or arg:match("^%-%-(.+)$") or arg
      options.flags[key] = value or ""
    else
      assert(not options.commitish, "GinDiff expects [commitish] [-- paths...]")
      options.commitish = arg
    end
  end
  options.bang, options.smods = opts.bang, opts.smods
  return M.open(require("gin.worktree").current(options.worktree), options)
end

return M
