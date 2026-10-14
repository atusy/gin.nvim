local H = require("tests.helpers")
local cwd = vim.fn.getcwd()
local root
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = vim.uv.fs_realpath(H.repo())
      vim.fn.writefile({ "fixture" }, root .. "/file")
      H.git(root, "add", "file")
      vim.cmd.cd(root)
    end,
    post_case = function()
      vim.cmd("silent! tabonly!")
      vim.cmd("silent! only!")
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})

T["GinEdit accepts modifiers inside its opener"] = function()
  local original = vim.api.nvim_get_current_win()
  vim.cmd([[GinEdit ++opener=botright\ vsplit file]])
  MiniTest.expect.equality(vim.api.nvim_get_current_win() ~= original, true)
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "fixture")
  MiniTest.expect.equality(vim.fn.winlayout()[1], "row")
  MiniTest.expect.equality(vim.fn.winlayout()[2][2][2], vim.api.nvim_get_current_win())
end

T["compound preview opener returns the preview when its buffer is already visible"] = function()
  vim.cmd.edit(root .. "/file")
  local original, expected = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  local buf, win = require("gin.buffer").open(root .. "/file", { opener = "botright pedit" })
  MiniTest.expect.equality(buf, expected)
  MiniTest.expect.equality(win ~= original, true)
  MiniTest.expect.equality(vim.wo[win].previewwindow, true)
  MiniTest.expect.equality(vim.api.nvim_win_get_buf(win), buf)
  MiniTest.expect.equality(vim.api.nvim_get_current_win(), original)
end

for _, opener in ipairs({ "new", "tabnew", "botright vsplit", "silent belowright split" }) do
  T[opener .. " returns the new window even when its buffer is already visible"] = function()
    local name = root .. "/space | literal%# file"
    vim.fn.writefile({ "special" }, name)
    vim.cmd.edit(vim.fn.fnameescape(name))
    local original, expected = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    local buf, win = require("gin.buffer").open(name, { opener = opener })
    MiniTest.expect.equality(buf, expected)
    MiniTest.expect.equality(win ~= original, true)
    MiniTest.expect.equality(vim.api.nvim_get_current_win(), win)
    MiniTest.expect.equality(vim.api.nvim_win_get_buf(win), buf)
    MiniTest.expect.equality(vim.api.nvim_buf_get_name(buf), name)
    MiniTest.expect.equality(vim.api.nvim_get_current_line(), "special")
  end
end

for _, opener in ipairs({ "botright pedit", "vertical ped" }) do
  T[opener .. " preserves focus and decodes special filenames"] = function()
    local name = root .. "/space | literal%# file"
    vim.fn.writefile({ "caf" .. string.char(233) .. "\r" }, name)
    local original = vim.api.nvim_get_current_win()
    local buf, win =
      require("gin.buffer").open(name, { opener = opener, enc = "latin1", ff = "dos" })
    MiniTest.expect.equality(vim.api.nvim_get_current_win(), original)
    MiniTest.expect.equality(win ~= original, true)
    MiniTest.expect.equality(vim.wo[win].previewwindow, true)
    MiniTest.expect.equality(vim.api.nvim_win_get_buf(win), buf)
    MiniTest.expect.equality(vim.api.nvim_buf_get_name(buf), name)
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "café" })
    MiniTest.expect.equality(
      { vim.bo[buf].fileencoding, vim.bo[buf].fileformat },
      { "latin1", "dos" }
    )
  end
end

return T
