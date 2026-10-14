if vim.g.loaded_gin_chaperon ~= nil then
  return
end
vim.g.loaded_gin_chaperon = 1
vim.api.nvim_create_user_command("GinChaperon", function(opts)
  require("gin.command").friendly(function()
    require("gin.chaperon").command(opts)
  end, opts.smods)
end, { nargs = "*", bar = true, bang = true })
