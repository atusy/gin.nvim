local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.writefile({ "base" }, root .. "/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      H.git(root, "branch", "topic")
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
T["branch view lists refs and switches the selected branch"] = function()
  vim.cmd.GinBranch()
  MiniTest.expect.equality(vim.bo.filetype, "gin-branch")
  local rows = vim.b.gin_branches
  MiniTest.expect.equality({ rows[1].branch, rows[2].branch }, { "main", "topic" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys("\r", "mx", false)
  MiniTest.expect.equality(H.git(root, "branch", "--show-current"), "topic\n")
  MiniTest.expect.equality(vim.b.gin_branches[2].head, "*")
end
T["branch deletion changes refs and reloads the view"] = function()
  vim.cmd.GinBranch()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "branch", "--list", "topic"), "")
  MiniTest.expect.equality(#vim.b.gin_branches, 1)
end
T["branch patterns and named-register yanks survive reload"] = function()
  vim.cmd("GinBranch top*")
  vim.cmd.edit()
  MiniTest.expect.equality(#vim.b.gin_branches, 1)
  vim.api.nvim_feedkeys('"ayy', "mx", false)
  MiniTest.expect.equality(vim.fn.getreg("a"), "topic")
end
T["deleting a remote branch removes the remote ref"] = function()
  H.git(root, "init", "--bare", "remote.git")
  H.git(root, "remote", "add", "origin", root .. "/remote.git")
  H.git(root, "push", "origin", "topic")
  vim.cmd("GinBranch --remotes")
  MiniTest.expect.equality(vim.b.gin_branches[1].target, "origin/topic")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "ls-remote", "origin", "refs/heads/topic"), "")
  MiniTest.expect.equality(#vim.b.gin_branches, 0)
end
T["deleting the current branch fails without removing its worktree"] = function()
  vim.cmd("GinBranch main")
  MiniTest.expect.error(function()
    require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 1, 1 })
  end, "git exited")
  MiniTest.expect.equality(H.git(root, "branch", "--show-current"), "main\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "base" })
end
return T
