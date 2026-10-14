if vim.g.loaded_gin_status ~= nil then
  return
end
vim.g.loaded_gin_status = 1
vim.api.nvim_create_user_command("GinStatus", function(opts)
  require("gin.command").friendly(function()
    require("gin.status").command(opts)
  end, opts.smods)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_status", { clear = true }),
  pattern = "ginstatus://*",
  callback = function(event)
    require("gin.status").read(event.buf, event.match)
  end,
})
