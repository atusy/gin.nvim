if vim.b.did_ftplugin then
  return
end
vim.b.did_ftplugin = 1
require("gin.ftplugin").jump_mappings(vim.api.nvim_get_current_buf(), "buffer")
