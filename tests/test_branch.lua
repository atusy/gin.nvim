local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local merge_autoedit = vim.env.GIT_MERGE_AUTOEDIT
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
      vim.env.GIT_MERGE_AUTOEDIT = merge_autoedit
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
T["default branch columns align names by display width"] = function()
  H.git(root, "branch", "long-branch-name")
  H.git(root, "branch", "日本語")
  for _, pattern in ipairs({ "*", "m*" }) do
    vim.cmd("GinBranch --no-color " .. pattern)
    for _ = 1, 2 do
      MiniTest.expect.equality(
        table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n",
        H.git(root, "branch", "--list", "-vv", "--no-color", "--", pattern)
      )
      vim.cmd.edit()
    end
  end
end
T["remote branch display preserves prefixes and symbolic targets"] = function()
  H.git(root, "update-ref", "refs/remotes/origin/topic", "HEAD")
  H.git(root, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/topic")
  for _, flag in ipairs({ "--all", "--remotes", "-a", "-r", "--all --remotes", "--remotes --all" }) do
    vim.cmd("GinBranch --no-color " .. flag)
    for _ = 1, 2 do
      MiniTest.expect.equality(
        table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n",
        H.git(root, "branch", "--list", "-vv", "--no-color", unpack(vim.split(flag, " ")))
      )
      local rows = vim.b.gin_branches
      for index, row in ipairs(rows) do
        if row.kind == "alias" then
          MiniTest.expect.equality(row.target, "origin/HEAD")
          MiniTest.expect.equality(row.branch, "HEAD")
        elseif row.kind == "remote" then
          MiniTest.expect.equality(row.target, "origin/topic")
          MiniTest.expect.equality(row.branch, "topic")
          require("gin.action").call(
            vim.api.nvim_get_current_buf(),
            "yank:target",
            { index, index }
          )
          MiniTest.expect.equality(vim.fn.getreg('"'), "origin/topic")
        end
      end
      vim.cmd.edit()
    end
  end
end
T["custom branch formats retain sorted switch targets across reload"] = function()
  vim.cmd("GinBranch --sort=-refname --format=%(refname:short):%(subject)")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
    "topic:initial",
    "main:initial",
  })
  require("gin.action").call(vim.api.nvim_get_current_buf(), "switch", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "branch", "--show-current"), "topic\n")
end
T["branch deletion changes refs and reloads the view"] = function()
  vim.cmd.GinBranch()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "branch", "--list", "topic"), "")
  MiniTest.expect.equality(#vim.b.gin_branches, 1)
end
T["multiline branch formats preserve NULs and deduplicate deletion targets"] = function()
  vim.cmd("GinBranch --format=%(refname:short)%00%0a%(subject)")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
    "main\0",
    "initial",
    "topic\0",
    "initial",
  })
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 3, 4 })
  MiniTest.expect.equality(H.git(root, "branch", "--list", "topic"), "")
  MiniTest.expect.equality(H.git(root, "branch", "--show-current"), "main\n")
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
  vim.cmd("GinBranch --remotes --format=%(subject)%0a%(refname:short)")
  MiniTest.expect.equality(vim.b.gin_branches[1].target, "origin/topic")
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "initial", "origin/topic" }
  )
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 2, 2 })
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
  H.git(root, "branch", "--set-upstream-to=main", "topic")
  H.git(root, "worktree", "add", root .. "/linked", "topic")
  vim.cmd("GinBranch topic")
  local function expect_display(pattern)
    MiniTest.expect.equality(
      table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n",
      H.git(root, "branch", "--list", "-vv", "--no-color", "--", pattern)
    )
  end
  expect_display("topic")
  vim.cmd.edit()
  expect_display("topic")
  prompt_action("move", { 1, 1 }, root .. "/moved")
  MiniTest.expect.equality(vim.fn.isdirectory(root .. "/linked"), 0)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/moved/file"), { "base" })
  MiniTest.expect.equality(H.git(root .. "/moved", "branch", "--show-current"), "topic\n")
  expect_display("topic")
  vim.cmd("GinBranch main")
  expect_display("main")
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
  local process = require("gin.action").call(vim.api.nvim_get_current_buf(), "merge", { 1, 1 })
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return process:is_closing()
    end, 10),
    true
  )
  MiniTest.expect.equality(process:wait(5000).code, 0)
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), H.git(root, "rev-parse", "topic"))
  MiniTest.expect.equality(vim.fn.readfile(root .. "/topic-file"), { "topic" })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "")
end
T["merge no-ff edits the message and records both parents"] = function()
  vim.env.GIT_MERGE_AUTOEDIT = "yes"
  advance_topic()
  H.git(root, "config", "user.name", "Gin Test")
  H.git(root, "config", "user.email", "gin@example.invalid")
  H.git(root, "config", "core.editor", "true")
  local before, topic = H.git(root, "rev-parse", "main"), H.git(root, "rev-parse", "topic")
  vim.cmd("GinBranch topic")
  local process =
    require("gin.action").call(vim.api.nvim_get_current_buf(), "merge:no-ff", { 1, 1 })
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "edited merge message" })
  vim.cmd.Apply()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return process:is_closing()
    end, 10),
    true
  )
  MiniTest.expect.equality(process:wait(5000).code, 0)
  MiniTest.expect.equality(H.git(root, "log", "-1", "--format=%s"), "edited merge message\n")
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
  local message
  local notify = vim.notify
  vim.notify = function(text)
    message = text
  end
  local ok, err = pcall(function()
    local process =
      require("gin.action").call(vim.api.nvim_get_current_buf(), "merge:ff-only", { 1, 1 })
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return message ~= nil
      end, 10),
      true
    )
    MiniTest.expect.equality(process:wait(5000).code ~= 0, true)
    MiniTest.expect.equality(message:find("git exited", 1, true) ~= nil, true)
  end)
  vim.notify = notify
  assert(ok, err)
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), before)
  MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
end
for _, failure in ipairs({ "cancelled editor", "conflicting files" }) do
  T["merge recovers from " .. failure .. " through Gin commit"] = function()
    vim.env.GIT_MERGE_AUTOEDIT = "yes"
    H.git(root, "config", "user.name", "Gin Test")
    H.git(root, "config", "user.email", "gin@example.invalid")
    H.git(root, "config", "core.editor", "true")
    if failure == "conflicting files" then
      H.git(root, "checkout", "topic")
      vim.fn.writefile({ "topic version" }, root .. "/file")
      H.git(root, "commit", "-am", "topic change")
      H.git(root, "checkout", "main")
      vim.fn.writefile({ "main version" }, root .. "/file")
      H.git(root, "commit", "-am", "main change")
    else
      advance_topic()
    end
    local before, topic = H.git(root, "rev-parse", "main"), H.git(root, "rev-parse", "topic")
    vim.cmd("GinBranch topic")
    local posts, message = 0, nil
    local event = vim.api.nvim_create_autocmd("User", {
      pattern = "GinCommandPost",
      callback = function()
        posts = posts + 1
      end,
    })
    local notify = vim.notify
    vim.notify = function(text)
      message = text
    end
    local ok, err = pcall(function()
      local process =
        require("gin.action").call(vim.api.nvim_get_current_buf(), "merge:no-ff", { 1, 1 })
      if failure == "cancelled editor" then
        MiniTest.expect.equality(
          vim.wait(5000, function()
            return vim.b.gin_editor_request ~= nil
          end, 10),
          true
        )
        vim.cmd.Cancel()
      end
      MiniTest.expect.equality(
        vim.wait(5000, function()
          return message ~= nil
        end, 10),
        true
      )
      MiniTest.expect.equality(process:wait(5000).code ~= 0, true)
      MiniTest.expect.equality(posts, 0)
      MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), before)
      MiniTest.expect.equality(H.git(root, "rev-parse", "MERGE_HEAD"), topic)
      if failure == "conflicting files" then
        MiniTest.expect.equality(H.git(root, "show", ":1:file"), "base\n")
        MiniTest.expect.equality(H.git(root, "show", ":2:file"), "main version\n")
        MiniTest.expect.equality(H.git(root, "show", ":3:file"), "topic version\n")
        MiniTest.expect.equality(vim.b.gin_editor_request, nil)
        vim.fn.writefile({ "resolved content" }, root .. "/file")
        H.git(root, "add", "file")
      else
        MiniTest.expect.equality(H.git(root, "show", ":topic-file"), "topic\n")
      end
      vim.cmd("Gin commit")
      MiniTest.expect.equality(
        vim.wait(5000, function()
          return vim.b.gin_editor_request ~= nil
        end, 10),
        true
      )
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "recovered merge" })
      vim.cmd.Apply()
      MiniTest.expect.equality(
        vim.wait(5000, function()
          return posts == 1
        end, 10),
        true
      )
      MiniTest.expect.equality(H.git(root, "log", "-1", "--format=%s"), "recovered merge\n")
      MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^1"), before)
      MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^2"), topic)
      MiniTest.expect.equality(vim.fn.filereadable(root .. "/.git/MERGE_HEAD"), 0)
      MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
      if failure == "conflicting files" then
        MiniTest.expect.equality(H.git(root, "show", "HEAD:file"), "resolved content\n")
      else
        MiniTest.expect.equality(H.git(root, "show", "HEAD:topic-file"), "topic\n")
      end
    end)
    vim.notify = notify
    vim.api.nvim_del_autocmd(event)
    assert(ok, err)
  end
end
local function diverge()
  advance_topic()
  H.git(root, "config", "user.name", "Gin Test")
  H.git(root, "config", "user.email", "gin@example.invalid")
  vim.fn.writefile({ "main" }, root .. "/main-file")
  H.git(root, "add", "main-file")
  H.git(root, "commit", "-m", "main change")
end
T["rebase replays current changes onto the selected branch"] = function()
  diverge()
  vim.cmd("GinBranch topic")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "rebase", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^"), H.git(root, "rev-parse", "topic"))
  MiniTest.expect.equality(vim.fn.readfile(root .. "/main-file"), { "main" })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/topic-file"), { "topic" })
  MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
end
T["rebase exec runs the supplied command after replay"] = function()
  diverge()
  vim.cmd("GinBranch topic")
  prompt_action("rebase:x", { 1, 1 }, "git config gin.executed yes")
  MiniTest.expect.equality(H.git(root, "config", "gin.executed"), "yes\n")
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^"), H.git(root, "rev-parse", "topic"))
end
T["instant drop removes the selected commit while retaining descendants"] = function()
  advance_topic()
  H.git(root, "config", "user.name", "Gin Test")
  H.git(root, "config", "user.email", "gin@example.invalid")
  H.git(root, "merge", "--ff-only", "topic")
  vim.fn.writefile({ "later" }, root .. "/later")
  H.git(root, "add", "later")
  H.git(root, "commit", "-m", "later change")
  local base = H.git(root, "rev-parse", "topic^")
  vim.cmd("GinBranch topic")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "rebase:instant-drop", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^"), base)
  MiniTest.expect.equality(vim.fn.filereadable(root .. "/topic-file"), 0)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/later"), { "later" })
end
T["interactive branch rebase executes the supplied command after Apply"] = function()
  diverge()
  vim.cmd("GinBranch topic")
  local completed = false
  local event = vim.api.nvim_create_autocmd("User", {
    pattern = "GinCommandPost",
    once = true,
    callback = function()
      completed = true
    end,
  })
  prompt_action("rebase:i:x", { 1, 1 }, "git config gin.executed interactive")
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  local todo = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(
    todo:find("exec git config gin.executed interactive", 1, true) ~= nil,
    true
  )
  vim.cmd.Apply()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return completed
    end, 10),
    true
  )
  pcall(vim.api.nvim_del_autocmd, event)
  MiniTest.expect.equality(H.git(root, "config", "gin.executed"), "interactive\n")
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^"), H.git(root, "rev-parse", "topic"))
end

T["branch decoding options survive reload and preserve switch targets"] = function()
  H.git(root, "checkout", "topic")
  H.git(
    root,
    "-c",
    "i18n.commitEncoding=ISO-8859-1",
    "commit",
    "--allow-empty",
    "-m",
    "caf" .. string.char(233)
  )
  local commit = H.git(root, "rev-parse", "HEAD")
  H.git(root, "checkout", "main")
  vim.cmd("GinBranch ++encoding=latin1 ++fileformat=unix topic")
  vim.cmd.edit()
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]:find("café", 1, true) ~= nil,
    true
  )
  MiniTest.expect.equality(vim.bo.fileencoding, "latin1")
  MiniTest.expect.equality(vim.bo.fileformat, "unix")
  MiniTest.expect.equality(vim.b.gin_branches[1].target, "topic")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "switch", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "branch", "--show-current"), "topic\n")
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), commit)
end
T["custom branch colors preserve switch targets and explicit monochrome"] = function()
  H.git(root, "config", "color.branch", "never")
  local format = "--format=%(color:blue)%(refname:short)%(color:reset)"
  vim.cmd("GinBranch " .. format)
  local ns = vim.api.nvim_create_namespace("gin_ansi")
  for _ = 1, 2 do
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "main", "topic" })
    local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
    MiniTest.expect.equality(#marks, 2)
    MiniTest.expect.equality(marks[2][4].hl_group, "GinColorF4")
    vim.cmd.edit()
  end
  require("gin.action").call(vim.api.nvim_get_current_buf(), "switch", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "branch", "--show-current"), "topic\n")
  vim.cmd("GinBranch --no-color " .. format)
  MiniTest.expect.equality(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}), {})
  MiniTest.expect.equality(H.git(root, "config", "color.branch"), "never\n")
end
return T
