if vim.g.loaded_gin_log ~= nil then
  return
end
vim.g.loaded_gin_log = 1
vim.api.nvim_create_user_command("GinLog", function(opts)
  require("gin.command").friendly(function()
    require("gin.log").command(opts)
  end, opts.smods)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_log", { clear = true }),
  pattern = "ginlog://*",
  callback = function(event)
    require("gin.log").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("FileReadCmd", {
  group = vim.api.nvim_create_augroup("gin_log", { clear = false }),
  pattern = "ginlog://*",
  callback = function(event)
    require("gin.log").insert(event.buf, event.match)
  end,
})
