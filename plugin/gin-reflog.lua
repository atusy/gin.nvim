if vim.g.loaded_gin_reflog ~= nil then
  return
end
vim.g.loaded_gin_reflog = 1
vim.api.nvim_create_user_command("GinReflog", function(opts)
  require("gin.command").friendly(function()
    require("gin.log").command(opts, "reflog")
  end, opts.smods)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_reflog", { clear = true }),
  pattern = "ginreflog://*",
  callback = function(event)
    require("gin.log").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("FileReadCmd", {
  group = vim.api.nvim_create_augroup("gin_reflog", { clear = false }),
  pattern = "ginreflog://*",
  callback = function(event)
    require("gin.log").insert(event.buf, event.match)
  end,
})
