if vim.g.loaded_gin_patch ~= nil then
  return
end
vim.g.loaded_gin_patch = 1
vim.api.nvim_create_user_command("GinPatch", function(opts)
  require("gin.command").friendly(function()
    require("gin.patch").command(opts)
  end, opts.smods)
end, { nargs = "*", bar = true, bang = true })
