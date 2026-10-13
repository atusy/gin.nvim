local T = MiniTest.new_set()
T["ANSI highlights survive colorscheme changes with the current terminal palette"] = function()
  local ansi = require("gin.ansi")
  local old = vim.g.terminal_color_1
  local _, marks = ansi.parse({ "\27[31mred\27[m" })
  local name = marks[1][4]
  vim.api.nvim_set_hl(0, name, {})
  vim.g.terminal_color_1 = "#123456"
  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "test" })
  local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
  vim.g.terminal_color_1 = old
  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "test-restore" })
  MiniTest.expect.equality({ hl.fg, hl.ctermfg }, { 0x123456, 1 })
end
return T
