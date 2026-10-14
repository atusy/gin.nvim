if vim.g.loaded_gin_tag ~= nil then
  return
end
vim.g.loaded_gin_tag = 1
vim.api.nvim_create_user_command("GinTag", function(opts)
  require("gin.tag").command(opts)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_tag", { clear = true }),
  pattern = "gintag://*",
  callback = function(event)
    require("gin.tag").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("FileReadCmd", {
  group = vim.api.nvim_create_augroup("gin_tag", { clear = false }),
  pattern = "gintag://*",
  callback = function(event)
    require("gin.tag").insert(event.buf, event.match)
  end,
})
