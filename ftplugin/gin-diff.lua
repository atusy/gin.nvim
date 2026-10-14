if vim.b.did_ftplugin ~= nil then
  return
end
vim.cmd.runtime("ftplugin/diff.vim")
local win = vim.api.nvim_get_current_win()
vim.schedule(function()
  if vim.api.nvim_win_is_valid(win) then
    vim.wo[win].foldlevel = 1
  end
end)

require("gin.ftplugin").jump_mappings(vim.api.nvim_get_current_buf(), "diff")
