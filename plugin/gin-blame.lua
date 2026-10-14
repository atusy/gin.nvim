if vim.g.loaded_gin_blame ~= nil then
  return
end
vim.g.loaded_gin_blame = 1
vim.api.nvim_create_user_command("GinBlame", function(opts)
  require("gin.command").friendly(function()
    require("gin.blame").command(opts)
  end, opts.smods)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_blame", { clear = true }),
  pattern = "ginblame://*",
  callback = function(event)
    require("gin.blame").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_blame", { clear = false }),
  pattern = "ginblamenav://*",
  callback = function(event)
    require("gin.blame").read_nav(event.buf)
  end,
})
require("gin.blame").highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("gin_blame", { clear = false }),
  callback = function()
    require("gin.blame").highlights()
  end,
})
