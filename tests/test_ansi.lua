local T = MiniTest.new_set()
for _, case in ipairs({
  { 1, 22, "bold" },
  { 3, 23, "italic" },
  { 4, 24, "underline" },
  { 7, 27, "reverse" },
  { 9, 29, "strikethrough" },
}) do
  T["SGR " .. case[3] .. " resets independently of foreground color"] = function()
    local plain, marks = require("gin.ansi").parse({
      ("\27[31;%dmA\27[%dmB\27[39mC"):format(case[1], case[2]),
    })
    MiniTest.expect.equality(plain, { "ABC" })
    MiniTest.expect.equality(#marks, 2)
    local active = vim.api.nvim_get_hl(0, { name = marks[1][4], link = false })
    local reset = vim.api.nvim_get_hl(0, { name = marks[2][4], link = false })
    MiniTest.expect.equality(active[case[3]], true)
    MiniTest.expect.equality(reset[case[3]], nil)
    MiniTest.expect.equality({ active.ctermfg, reset.ctermfg }, { 1, 1 })
    MiniTest.expect.equality({ marks[1][2], marks[1][3], marks[2][2], marks[2][3] }, { 0, 1, 1, 2 })
  end
end
T["dim uses Comment and intensity reset restores the retained color without bold"] = function()
  local plain, marks = require("gin.ansi").parse({ "\27[31;1;2mA\27[22mB\27[mC" })
  MiniTest.expect.equality(plain, { "ABC" })
  MiniTest.expect.equality(#marks, 2)
  MiniTest.expect.equality(marks[1][4], "Comment")
  local restored = vim.api.nvim_get_hl(0, { name = marks[2][4], link = false })
  MiniTest.expect.equality(restored.ctermfg, 1)
  MiniTest.expect.equality(restored.bold, nil)
end
T["unsupported and unknown SGR attributes leave supported attributes intact"] = function()
  local plain, marks = require("gin.ansi").parse({ "\27[31;4mA\27[5;8;999mB\27[25;28mC\27[mD" })
  MiniTest.expect.equality(plain, { "ABCD" })
  MiniTest.expect.equality(#marks, 3)
  for _, mark in ipairs(marks) do
    MiniTest.expect.equality(mark[4], "GinColorF1Underline")
  end
end
T["CSI stripping preserves ordinary text and non-CSI escape sequences"] = function()
  local text = "é\27]0;title\7\27[ 2K\27["
  MiniTest.expect.equality(require("gin.csi").strip(text), text)
end
T["non-color CSI is removed without resetting colors or shifting byte columns"] = function()
  local plain, marks = require("gin.ansi").parse({ "\27[31mé\27[2K赤\27[?25l!\27[m." })
  MiniTest.expect.equality(plain, { "é赤!." })
  MiniTest.expect.equality(#marks, 3)
  MiniTest.expect.equality(
    { marks[1][2], marks[1][3], marks[2][2], marks[2][3], marks[3][2], marks[3][3] },
    { 0, 2, 2, 5, 5, 6 }
  )
  MiniTest.expect.equality(marks[1][4], marks[2][4])
  MiniTest.expect.equality(marks[2][4], marks[3][4])
end
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
T["ANSI groups retain upstream color and attribute names"] = function()
  local plain, marks = require("gin.ansi").parse({
    "\27[1;3;4;7;9;31;48;2;1;2;3mX\27[0m \27[38;2;10;11;12mY\27[0m \27[2mZ",
  })
  MiniTest.expect.equality(plain, { "X Y Z" })
  MiniTest.expect.equality({ marks[1][4], marks[2][4], marks[3][4] }, {
    "GinColorF1B010203BoldInverseItalicStrikeUnderline",
    "GinColorF0a0b0c",
    "Comment",
  })
end
return T
