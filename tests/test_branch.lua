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
local function prompt_action(name, range, value)
  local original, callback = vim.ui.input, nil
  vim.ui.input = function(_, done)
    callback = done
  end
  local ok, err = pcall(require("gin.action").call, vim.api.nvim_get_current_buf(), name, range)
  vim.ui.input = original
  assert(ok, err)
  assert(callback, "Expected an input prompt")
  callback(value)
end
T["new branch starts from the selected ref and switches to it"] = function()
  vim.cmd("GinBranch topic")
  local source = H.git(root, "rev-parse", "topic")
  prompt_action("new", { 1, 1 }, "created")
  MiniTest.expect.equality(H.git(root, "branch", "--show-current"), "created\n")
  MiniTest.expect.equality(H.git(root, "rev-parse", "created"), source)
end
T["move renames the selected branch and cancellation leaves refs intact"] = function()
  vim.cmd("GinBranch topic")
  prompt_action("move", { 1, 1 }, nil)
  MiniTest.expect.equality(H.git(root, "branch", "--list", "topic") ~= "", true)
  prompt_action("move", { 1, 1 }, "renamed")
  MiniTest.expect.equality(H.git(root, "branch", "--list", "topic"), "")
  MiniTest.expect.equality(H.git(root, "rev-parse", "renamed"), H.git(root, "rev-parse", "HEAD"))
end
T["orphan creation switches to an unborn branch"] = function()
  vim.cmd.GinBranch()
  prompt_action("new:orphan", { 1, 1 }, "empty-history")
  MiniTest.expect.equality(H.git(root, "symbolic-ref", "HEAD"), "refs/heads/empty-history\n")
  MiniTest.expect.equality(H.git(root, "ls-files"), "")
end
T["move relocates a linked worktree without renaming its branch"] = function()
  H.git(root, "worktree", "add", root .. "/linked", "topic")
  vim.cmd("GinBranch topic")
  prompt_action("move", { 1, 1 }, root .. "/moved")
  MiniTest.expect.equality(vim.fn.isdirectory(root .. "/linked"), 0)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/moved/file"), { "base" })
  MiniTest.expect.equality(H.git(root .. "/moved", "branch", "--show-current"), "topic\n")
  H.git(root, "worktree", "remove", root .. "/moved")
end
T["new force resets an existing branch to the selected starting ref"] = function()
  H.git(root, "checkout", "topic")
  vim.fn.writefile({ "topic" }, root .. "/file")
  H.git(root, "commit", "-am", "topic change")
  H.git(root, "checkout", "main")
  vim.cmd("GinBranch main")
  prompt_action("new:force", { 1, 1 }, "topic")
  MiniTest.expect.equality(H.git(root, "rev-parse", "topic"), H.git(root, "rev-parse", "main"))
  MiniTest.expect.equality(H.git(root, "branch", "--show-current"), "topic\n")
end
local function worktree_action(action, branch, path)
  local original, count = vim.ui.input, 0
  vim.ui.input = function(_, done)
    count = count + 1
    if count == 1 then
      done(branch)
    else
      done(path)
    end
  end
  local ok, err =
    pcall(require("gin.action").call, vim.api.nvim_get_current_buf(), action, { 1, 1 })
  vim.ui.input = original
  assert(ok, err)
end
T["worktree creates a named branch from the selection and changes cwd"] = function()
  vim.cmd("GinBranch topic")
  worktree_action("worktree", "feature/new", root .. "/new tree")
  MiniTest.expect.equality(vim.fn.getcwd(), vim.uv.fs_realpath(root .. "/new tree"))
  MiniTest.expect.equality(H.git(root .. "/new tree", "branch", "--show-current"), "feature/new\n")
  MiniTest.expect.equality(
    H.git(root, "rev-parse", "feature/new"),
    H.git(root, "rev-parse", "topic")
  )
  MiniTest.expect.equality(vim.fn.readfile(root .. "/new tree/file"), { "base" })
  vim.cmd.cd(root)
  H.git(root, "worktree", "remove", root .. "/new tree")
end
T["cancelling the worktree path creates neither branch nor directory"] = function()
  vim.cmd("GinBranch topic")
  worktree_action("worktree", "cancelled", nil)
  MiniTest.expect.equality(H.git(root, "branch", "--list", "cancelled"), "")
  MiniTest.expect.equality(vim.fn.getcwd(), vim.uv.fs_realpath(root))
end
T["orphan worktree starts with an empty index"] = function()
  vim.cmd.GinBranch()
  worktree_action("worktree:orphan", "orphan", root .. "/orphan")
  MiniTest.expect.equality(H.git(root .. "/orphan", "symbolic-ref", "HEAD"), "refs/heads/orphan\n")
  MiniTest.expect.equality(H.git(root .. "/orphan", "ls-files"), "")
  vim.cmd.cd(root)
  H.git(root, "worktree", "remove", root .. "/orphan")
end
T["Gin commands refresh branch refs without moving the cursor"] = function()
  vim.cmd.GinBranch()
  vim.api.nvim_win_set_cursor(0, { 2, 3 })
  vim.cmd("silent Gin ++wait branch z-new")
  MiniTest.expect.equality(#vim.b.gin_branches, 3)
  MiniTest.expect.equality(vim.b.gin_branches[3].branch, "z-new")
  MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0), { 2, 3 })
  vim.cmd("silent Gin ++wait branch -d z-new")
  MiniTest.expect.equality(#vim.b.gin_branches, 2)
end
T["branch refresh registrations are not duplicated by reload"] = function()
  vim.cmd.GinBranch()
  local buf = vim.api.nvim_get_current_buf()
  vim.cmd.edit()
  vim.cmd.edit()
  local group = "gin_branch_" .. buf
  MiniTest.expect.equality(#vim.api.nvim_get_autocmds({ group = group, event = "User" }), 1)
  vim.api.nvim_buf_delete(buf, { force = true })
  MiniTest.expect.equality(pcall(vim.api.nvim_get_autocmds, { group = group }), false)
end
local function advance_topic()
  H.git(root, "checkout", "topic")
  vim.fn.writefile({ "topic" }, root .. "/topic-file")
  H.git(root, "add", "topic-file")
  H.git(root, "commit", "-m", "topic change")
  H.git(root, "checkout", "main")
end
T["merge fast-forwards to the selected branch"] = function()
  advance_topic()
  vim.cmd("GinBranch topic")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "merge", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), H.git(root, "rev-parse", "topic"))
  MiniTest.expect.equality(vim.fn.readfile(root .. "/topic-file"), { "topic" })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "")
end
T["merge no-ff records both parents"] = function()
  advance_topic()
  H.git(root, "config", "user.name", "Gin Test")
  H.git(root, "config", "user.email", "gin@example.invalid")
  H.git(root, "config", "core.editor", "true")
  local before, topic = H.git(root, "rev-parse", "main"), H.git(root, "rev-parse", "topic")
  vim.cmd("GinBranch topic")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "merge:no-ff", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^1"), before)
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^2"), topic)
end
T["merge ff-only rejects divergent history without changing HEAD"] = function()
  advance_topic()
  vim.fn.writefile({ "main" }, root .. "/main-file")
  H.git(root, "add", "main-file")
  H.git(root, "commit", "-m", "main change")
  local before = H.git(root, "rev-parse", "HEAD")
  vim.cmd("GinBranch topic")
  MiniTest.expect.error(function()
    require("gin.action").call(vim.api.nvim_get_current_buf(), "merge:ff-only", { 1, 1 })
  end, "git exited")
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), before)
  MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
end
return T
