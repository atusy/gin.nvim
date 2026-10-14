local H = require("tests.helpers")
local cwd = vim.fn.getcwd()
local root
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
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

return T
