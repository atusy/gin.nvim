if vim.g.loaded_gin then
  return
end
vim.g.loaded_gin = 1
vim.api.nvim_create_user_command("Gin", function(opts)
  require("gin.command").execute(opts)
end, { nargs = "*", bar = true })
