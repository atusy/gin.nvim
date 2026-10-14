if vim.b.did_ftplugin then
  return
end
vim.cmd.runtime("ftplugin/diff.vim")

require("gin.ftplugin").jump_mappings(vim.api.nvim_get_current_buf(), "diff")
