-- Initialize runtime cleanup before appending our alias cleanup.
vim.cmd.runtime("ftplugin/gitcommit.vim")
require("gin.editor").aliases()
