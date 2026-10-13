local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.cmd.cd(root)
      dofile(old_cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
    end,
  },
})
T["GinStatus lists the branch and untracked paths in sorted order"] = function()
  vim.fn.writefile({ "z" }, root .. "/z")
  vim.fn.writefile({ "a" }, root .. "/a")
  vim.cmd.GinStatus()
  MiniTest.expect.equality(vim.bo.filetype, "gin-status")
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "## No commits yet on main", "?? a", "?? z" }
  )
end
T["stage and unstage target the selected path from a subdirectory"] = function()
  vim.fn.mkdir(root .. "/sub", "p")
  vim.fn.writefile({ "hello" }, root .. "/sub/space name")
  vim.cmd.cd(root .. "/sub")
  vim.cmd.GinStatus()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Plug>(gin-action-stage)", true, false, true),
    "mx",
    false
  )
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "sub/space name\n")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { 'A  "sub/space name"' })
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Plug>(gin-action-unstage)", true, false, true),
    "mx",
    false
  )
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/space name"), { "hello" })
end
return T
