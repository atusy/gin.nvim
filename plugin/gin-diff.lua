if vim.g.loaded_gin_diff ~= nil then
  return
end
vim.g.loaded_gin_diff = 1
vim.api.nvim_create_user_command("GinDiff", function(opts)
  require("gin.command").friendly(function()
    require("gin.diff").command(opts)
  end, opts.smods)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_diff", { clear = true }),
  pattern = "gindiff://*",
  callback = function(event)
    require("gin.diff").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("FileReadCmd", {
  group = vim.api.nvim_create_augroup("gin_diff", { clear = false }),
  pattern = "gindiff://*",
  callback = function(event)
    require("gin.buffer").insert_output(
      event.buf,
      event.match,
      require("gin.diff").output(event.match, "both")
    )
  end,
})
