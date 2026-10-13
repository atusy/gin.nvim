local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      H.git(root, "config", "user.name", "Gin Test")
      H.git(root, "config", "user.email", "gin@example.invalid")
      vim.fn.mkdir(root .. "/sub", "p")
      vim.fn.writefile({ "before", "base", "after" }, root .. "/sub/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "base")
      H.git(root, "branch", "topic")
      vim.fn.writefile({ "before", "ours", "after" }, root .. "/sub/file")
      H.git(root, "commit", "-am", "ours")
      H.git(root, "checkout", "topic")
      vim.fn.writefile({ "before", "theirs", "after" }, root .. "/sub/file")
      H.git(root, "commit", "-am", "theirs")
      H.git(root, "checkout", "main")
      local result = require("gin.git").run(
        { "merge", "--no-edit", "topic" },
        { cwd = root, check = false }
      )
      assert(result.code == 1, result.stderr)
      vim.cmd.cd(root .. "/sub")
      vim.g.gin_chaperon_supplement_disable = 1
      dofile(old_cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd("silent! tabonly!")
      vim.cmd("silent! only!")
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
      vim.g.gin_chaperon_supplement_disable = nil
    end,
  },
})
T["GinChaperon resolves a conflict from the ours pane"] = function()
  vim.cmd("GinChaperon file")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 3)
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/sub/file")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "before", "after" })
  MiniTest.expect.equality(vim.bo.modified, true)
  MiniTest.expect.equality(vim.wo.diff, true)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys("dor", "mx", false)
  vim.cmd.write()
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), { "before", "ours", "after" })
  MiniTest.expect.equality(H.git(root, "ls-files", "--unmerged") ~= "", true)
  vim.cmd("Gin ++wait add -- %:p")
  MiniTest.expect.equality(H.git(root, "ls-files", "--unmerged"), "")
  MiniTest.expect.equality(H.git(root, "show", ":sub/file"), "before\nours\nafter\n")
end
return T
