if vim.g.loaded_gin_browse ~= nil then
  return
end
vim.g.loaded_gin_browse = 1
vim.api.nvim_create_user_command("GinBrowse", function(opts)
  require("gin.command").friendly(function()
    require("gin.browse").command(opts)
  end, {})
end, { nargs = "*", bar = true, range = 0 })
