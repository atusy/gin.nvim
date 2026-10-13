local M = {}

function M.ascii()
  return require("gin.component").get("branch", "ascii")
end

function M.unicode()
  return require("gin.component").get("branch", "unicode")
end

return M
