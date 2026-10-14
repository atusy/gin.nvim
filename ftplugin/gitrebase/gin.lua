-- Initialize runtime cleanup before appending our alias cleanup.
vim.cmd.runtime("ftplugin/gitrebase.vim")
require("gin.editor").aliases()
