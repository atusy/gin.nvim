if vim.g.loaded_gin_proxy ~= nil then
  return
end
vim.g.loaded_gin_proxy = 1

-- Terminal jobs inherit these overrides just like Gin's own Git processes.
for name, value in pairs(require("gin.editor").environment() or {}) do
  vim.env[name] = value
end
