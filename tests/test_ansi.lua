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
T["extended ANSI colors and resets use UTF-8 byte columns"] = function()
  local ansi = require("gin.ansi")
  local plain, marks =
    ansi.parse({ "é\27[1;38;5;196m赤\27[22;39m!\27[48;2;1;2;3;3mZ\27[23;49m." })
  MiniTest.expect.equality(plain, { "é赤!Z." })
  MiniTest.expect.equality(#marks, 2)
  MiniTest.expect.equality({ marks[1][1], marks[1][2], marks[1][3] }, { 0, 2, 5 })
  MiniTest.expect.equality({ marks[2][1], marks[2][2], marks[2][3] }, { 0, 6, 7 })
  local first = vim.api.nvim_get_hl(0, { name = marks[1][4], link = false })
  local second = vim.api.nvim_get_hl(0, { name = marks[2][4], link = false })
  MiniTest.expect.equality({ first.fg, first.ctermfg, first.bold }, { 0xff0000, 196, true })
  MiniTest.expect.equality({ second.bg, second.italic }, { 0x010203, true })
  MiniTest.expect.equality(second.fg, nil)
  MiniTest.expect.equality(second.bold, nil)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, plain)
  ansi.apply(buf, marks)
  local spans = vim.api.nvim_buf_get_extmarks(
    buf,
    vim.api.nvim_create_namespace("gin_ansi"),
    0,
    -1,
    { details = true }
  )
  MiniTest.expect.equality(
    { spans[1][3], spans[1][4].end_col, spans[2][3], spans[2][4].end_col },
    { 2, 5, 6, 7 }
  )
  ansi.apply(buf, {})
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_create_namespace("gin_ansi"), 0, -1, {}),
    {}
  )
  vim.api.nvim_buf_delete(buf, { force = true })
end
return T
