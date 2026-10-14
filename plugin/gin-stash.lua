if vim.g.loaded_gin_stash ~= nil then
  return
end
vim.g.loaded_gin_stash = 1
vim.api.nvim_create_user_command("GinStash", function(opts)
  require("gin.command").friendly(function()
    require("gin.stash").command(opts)
  end, opts.smods)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_stash", { clear = true }),
  pattern = "ginstash://*",
  callback = function(event)
    require("gin.stash").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("FileReadCmd", {
  group = vim.api.nvim_create_augroup("gin_stash", { clear = false }),
  pattern = "ginstash://*",
  callback = function(event)
    require("gin.stash").insert(event.buf, event.match)
  end,
})
