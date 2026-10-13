local M = {}

function M.name()
  return require("gin.component").get("worktree", "name")
end

function M.full()
  return require("gin.component").get("worktree", "full")
end

return M
