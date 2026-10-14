-- Compound filetypes may already have b:did_ftplugin from their source language.
require("gin.ftplugin").blame_mappings(vim.api.nvim_get_current_buf())
