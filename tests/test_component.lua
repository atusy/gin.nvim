local H = require("tests.helpers")
local cwd = vim.fn.getcwd()
local root
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      H.git(root, "commit", "--allow-empty", "-m", "base")
      H.git(root, "switch", "-c", "remote-side")
      H.git(root, "commit", "--allow-empty", "-m", "remote")
      H.git(root, "update-ref", "refs/remotes/origin/main", "HEAD")
      H.git(root, "switch", "main")
      H.git(root, "commit", "--allow-empty", "-m", "local")
      H.git(root, "remote", "add", "origin", root)
      H.git(root, "config", "branch.main.remote", "origin")
      H.git(root, "config", "branch.main.merge", "refs/heads/main")
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(root)
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
T["components asynchronously publish branch traffic and worktree values"] = function()
  local branch = require("gin.component.branch")
  local traffic = require("gin.component.traffic")
  local worktree = require("gin.component.worktree")
  local events = 0
  local autocmd = vim.api.nvim_create_autocmd("User", {
    pattern = "GinComponentPost",
    callback = function()
      events = events + 1
    end,
  })
  branch.ascii()
  traffic.ascii()
  worktree.full()
  MiniTest.expect.equality(
    vim.wait(3000, function()
      return branch.ascii() == "main -> origin/main" and traffic.ascii() == "^1v1" and events > 0
    end, 10),
    true
  )
  MiniTest.expect.equality(branch.unicode(), "main → origin/main")
  MiniTest.expect.equality(traffic.unicode(), "↑1↓1")
  MiniTest.expect.equality(worktree.full(), vim.uv.fs_realpath(root))
  MiniTest.expect.equality(worktree.name(), vim.fs.basename(root))
  vim.api.nvim_del_autocmd(autocmd)
end
return T
