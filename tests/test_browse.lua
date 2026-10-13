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
return T
