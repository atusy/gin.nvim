local H = require("tests.helpers")
local root, hash
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.mkdir(root .. "/sub", "p")
      vim.fn.writefile({ "one", "two" }, root .. "/sub/space # file.md")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      hash = vim.trim(H.git(root, "rev-parse", "HEAD"))
      H.git(root, "remote", "add", "origin", "git@github.com:owner/repo.git")
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.g.gin_browse_persistent_args = nil
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
T["browse builds encoded file ranges and immutable permalinks"] = function()
  local url = require("gin.browse").url(
    root,
    "HEAD",
    { path = "sub/space # file.md", range = { 1, 2 }, permalink = true }
  )
  MiniTest.expect.equality(
    url,
    "https://github.com/owner/repo/blob/" .. hash .. "/sub/space%20%23%20file.md?plain=1#L1-L2"
  )
end
T["browse supports home and commit routes across hosting services"] = function()
  for _, spec in ipairs({
    { "https://gitlab.com/group/sub/repo.git", "https://gitlab.com/group/sub/repo", "/-/commit/" },
    { "ssh://git@bitbucket.org/owner/repo.git", "https://bitbucket.org/owner/repo", "/commits/" },
  }) do
    H.git(root, "remote", "set-url", "origin", spec[1])
    MiniTest.expect.equality(require("gin.browse").url(root, "HEAD", { home = true }), spec[2])
    MiniTest.expect.equality(
      require("gin.browse").url(root, "HEAD", { commit = true }),
      spec[2] .. spec[3] .. hash
    )
  end
end
T["GinBrowse no-browser yanks a current-file URL with a range"] = function()
  vim.cmd.edit(vim.fn.fnameescape(root .. "/sub/space # file.md"))
  vim.cmd("1,2GinBrowse --no-browser ++yank=a")
  MiniTest.expect.equality(
    vim.fn.getreg("a"),
    "https://github.com/owner/repo/blob/main/sub/space%20%23%20file.md?plain=1#L1-L2"
  )
end
T["GinBrowse zero address omits the line fragment"] = function()
  vim.cmd.edit(vim.fn.fnameescape(root .. "/sub/space # file.md"))
  vim.cmd("0GinBrowse --no-browser ++yank=a")
  MiniTest.expect.equality(
    vim.fn.getreg("a"),
    "https://github.com/owner/repo/blob/main/sub/space%20%23%20file.md"
  )
end
T["browse selects a containing remote and prefers origin when both contain"] = function()
  H.git(root, "remote", "add", "upstream", "https://github.com/upstream/repo.git")
  H.git(root, "update-ref", "refs/remotes/upstream/main", hash)
  MiniTest.expect.equality(
    require("gin.browse").url(root, "HEAD", { home = true }),
    "https://github.com/upstream/repo"
  )
  H.git(root, "update-ref", "refs/remotes/origin/main", hash)
  MiniTest.expect.equality(
    require("gin.browse").url(root, "HEAD", { home = true }),
    "https://github.com/owner/repo"
  )
  MiniTest.expect.equality(
    require("gin.browse").url(root, "HEAD", { home = true, remote = "upstream" }),
    "https://github.com/upstream/repo"
  )
end
T["browse selects remotes by ancestry rather than the presence of any ref"] = function()
  H.git(root, "update-ref", "refs/remotes/origin/main", hash)
  vim.fn.writefile({ "new" }, root .. "/new")
  H.git(root, "add", "new")
  H.git(root, "commit", "-m", "new commit")
  H.git(root, "remote", "add", "upstream", "https://github.com/upstream/repo.git")
  H.git(root, "update-ref", "refs/remotes/upstream/main", "HEAD")
  MiniTest.expect.equality(
    require("gin.browse").url(root, "HEAD", { home = true }),
    "https://github.com/upstream/repo"
  )
  MiniTest.expect.equality(
    require("gin.browse").url(root, hash, { commit = true }),
    "https://github.com/owner/repo/commit/" .. hash
  )
end
T["status browse action uses the selected repository-relative path"] = function()
  vim.fn.writefile({ "modified" }, root .. "/sub/space # file.md")
  vim.g.gin_browse_persistent_args = { "--no-browser", "++worktree=" .. root }
  vim.cmd.cd(root .. "/sub")
  vim.cmd.GinStatus()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "browse:permalink:yank", { 2, 2 })
  MiniTest.expect.equality(
    vim.fn.getreg('"'),
    "https://github.com/owner/repo/blob/" .. hash .. "/sub/space%20%23%20file.md"
  )
end
T["history browse commit action uses the selected commit"] = function()
  vim.g.gin_browse_persistent_args = { "--no-browser", "++worktree=" .. root }
  vim.cmd("GinLog --oneline")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "browse:commit:yank", { 1, 1 })
  MiniTest.expect.equality(vim.fn.getreg('"'), "https://github.com/owner/repo/commit/" .. hash)
end
T["browse PR finds a merge containing the selected commit"] = function()
  H.git(root, "checkout", "-b", "topic")
  vim.fn.writefile({ "topic" }, root .. "/topic")
  H.git(root, "add", "topic")
  H.git(root, "commit", "-m", "topic change")
  local topic = vim.trim(H.git(root, "rev-parse", "HEAD"))
  H.git(root, "checkout", "main")
  H.git(root, "merge", "--no-ff", "-m", "Merge pull request #42 from owner/topic", "topic")
  H.git(root, "update-ref", "refs/remotes/origin/main", "HEAD")
  H.git(root, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
  MiniTest.expect.equality(
    require("gin.browse").url(root, topic, { pr = true }),
    "https://github.com/owner/repo/pull/42"
  )
  vim.cmd("GinBrowse --pr --no-browser ++repository ++yank=a HEAD")
  MiniTest.expect.equality(vim.fn.getreg("a"), "https://github.com/owner/repo/pull/42")
end
T["browse PR reports a missing merge instead of generating an unrelated URL"] = function()
  H.git(root, "update-ref", "refs/remotes/origin/main", "HEAD")
  MiniTest.expect.error(function()
    require("gin.browse").url(root, "HEAD", { pr = true })
  end, "No pull request found")
end
return T
