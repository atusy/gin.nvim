local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.mkdir(root .. "/sub", "p")
      local base = { "first", "1", "2", "3", "4", "5", "6", "7", "8", "last" }
      vim.fn.writefile(base, root .. "/sub/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      base[1], base[10] = "changed first", "changed last"
      vim.fn.writefile(base, root .. "/sub/file")
      vim.cmd.cd(root .. "/sub")
      dofile(old_cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd("only!")
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
    end,
  },
})
T["GinPatch stages only the chosen hunk from a subdirectory"] = function()
  vim.cmd("GinPatch file")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 3)
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  MiniTest.expect.equality(vim.wo.diff, true)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys("dor", "mx", false)
  vim.cmd.write()
  local index = H.git(root, "show", ":sub/file")
  MiniTest.expect.equality(index:find("changed first", 1, true) ~= nil, true)
  MiniTest.expect.equality(index:find("changed last", 1, true), nil)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file")[10], "changed last")
end
T["GinPatch can unstage one hunk without a working-tree pane"] = function()
  H.git(root, "add", "sub/file")
  vim.cmd("GinPatch ++no-worktree file")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys("dol", "mx", false)
  vim.cmd.write()
  local index = H.git(root, "show", ":sub/file")
  MiniTest.expect.equality(index:find("changed first", 1, true), nil)
  MiniTest.expect.equality(index:find("changed last", 1, true) ~= nil, true)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file")[1], "changed first")
end
T["GinPatch defaults to the current file and can omit HEAD"] = function()
  vim.cmd.edit("file")
  vim.cmd("GinPatch ++no-head")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys("do", "mx", false)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, 1, false), { "changed first" })
end
T["reopening patch with fewer panes removes stale directional mappings"] = function()
  vim.cmd("GinPatch file")
  vim.cmd("only!")
  vim.cmd("GinPatch ++no-head file")
  MiniTest.expect.equality(vim.fn.maparg("dol", "n"), "")
  MiniTest.expect.equality(vim.fn.maparg("<Plug>(gin-diffget-l)", "n"), "")
end
return T
