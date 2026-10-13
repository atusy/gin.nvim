local M = {}

function M.ascii()
  return require("gin.component").get("traffic", "ascii")
end

function M.unicode()
  return require("gin.component").get("traffic", "unicode")
end

return M
