if vim.g.loaded_gin_branch ~= nil then
  return
end
vim.g.loaded_gin_branch = 1
vim.api.nvim_create_user_command("GinBranch", function(opts)
  require("gin.command").friendly(function()
    require("gin.branch").command(opts)
  end, opts.smods)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_branch", { clear = true }),
  pattern = "ginbranch://*",
  callback = function(event)
    require("gin.branch").read(event.buf, event.match)
  end,
})
