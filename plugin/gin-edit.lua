if vim.g.loaded_gin_edit ~= nil then
  return
end
vim.g.loaded_gin_edit = 1
vim.api.nvim_create_user_command("GinEdit", function(opts)
  require("gin.edit").command(opts)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_edit", { clear = true }),
  pattern = "ginedit://*",
  callback = function(event)
    require("gin.edit").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("BufWriteCmd", {
  group = vim.api.nvim_create_augroup("gin_edit", { clear = false }),
  pattern = "ginedit://*",
  nested = true,
  callback = function(event)
    require("gin.edit").write(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("FileReadCmd", {
  group = vim.api.nvim_create_augroup("gin_edit", { clear = false }),
  pattern = "ginedit://*",
  callback = function(event)
    require("gin.edit").insert(event.buf, event.match)
  end,
})
