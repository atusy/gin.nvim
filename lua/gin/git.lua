local M = {}

---Run Git with literal argv and preserve its output and exit status.
---@param args string[]
---@param opts? {cwd?: string, env?: table, stdin?: string, timeout?: integer, check?: boolean}
---@return vim.SystemCompleted
function M.run(args, opts)
  opts = opts or {}
  local cmd = { "git", "--no-pager", "--literal-pathspecs", "--no-optional-locks" }
  vim.list_extend(cmd, args)
  local result = vim
    .system(cmd, {
      cwd = opts.cwd,
      env = opts.env,
      stdin = opts.stdin,
    })
    :wait(opts.timeout or 30000)
  if opts.check ~= false and result.code ~= 0 then
    error(("git exited %d: %s"):format(result.code, vim.trim(result.stderr or "")), 0)
  end
  return result
end

return M
