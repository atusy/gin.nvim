local M = {}

---Run Git with literal argv and preserve its output and exit status.
---@param args string[]
---@param opts? {cwd?: string, env?: table, stdin?: string|boolean, timeout?: integer, check?: boolean}
---@param callback? fun(result: vim.SystemCompleted)
---@return vim.SystemObj
function M.start(args, opts, callback)
  opts = opts or {}
  local cmd = { "git", "--no-pager", "--literal-pathspecs", "--no-optional-locks" }
  vim.list_extend(cmd, args)
  return vim.system(cmd, {
    cwd = opts.cwd,
    env = opts.env,
    stdin = opts.stdin,
    timeout = opts.timeout or 30000,
  }, callback)
end

function M.run(args, opts)
  opts = opts or {}
  local result = M.start(args, opts):wait()
  if opts.check ~= false and result.code ~= 0 then
    error(("git exited %d: %s"):format(result.code, vim.trim(result.stderr or "")), 0)
  end
  return result
end

return M
