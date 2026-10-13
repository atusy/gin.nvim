local git = require("gin.git")
local M = {}

---@param anchor string
---@return string
function M.find(anchor)
  local stat = vim.uv.fs_stat(anchor)
  if not stat then
    error("No git repository found (searched from " .. anchor .. ")", 0)
  end
  local dir = stat.type == "directory" and anchor or vim.fs.dirname(anchor)
  local result = git.run({ "rev-parse", "--show-toplevel" }, { cwd = dir, check = false })
  if result.code ~= 0 then
    error("No git repository found (searched from " .. anchor .. ")", 0)
  end
  return vim.uv.fs_realpath((result.stdout:gsub("\n$", "")))
end

---Resolve the current buffer before falling back to the window's cwd.
---@param explicit? string
---@return string
function M.current(explicit)
  if explicit then
    return M.find(vim.fn.expand(explicit))
  end
  local worktree = vim.b.gin_worktree
  if worktree then
    return M.find(worktree)
  end
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= "" then
    local ok, root = pcall(M.find, name)
    if ok then
      return root
    end
  end
  return M.find(vim.fn.getcwd())
end

return M
