local H = require("tests.helpers")
local cwd = vim.fn.getcwd()
local root, other, original_start
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
      if original_start then
        require("gin.git").start = original_start
        original_start = nil
      end
      if other then
        H.cleanup(other)
        other = nil
      end
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
T["command events refresh no-upstream detached and unborn branches"] = function()
  local branch = require("gin.component.branch")
  local traffic = require("gin.component.traffic")
  branch.ascii()
  H.git(root, "switch", "-c", "topic")
  vim.api.nvim_exec_autocmds("User", { pattern = "GinCommandPost" })
  MiniTest.expect.equality(
    vim.wait(3000, function()
      return branch.ascii() == "topic" and traffic.ascii() == ""
    end, 10),
    true
  )
  H.git(root, "switch", "--detach", "HEAD")
  vim.api.nvim_exec_autocmds("User", { pattern = "GinCommandPost" })
  MiniTest.expect.equality(
    vim.wait(3000, function()
      return branch.ascii() == ""
    end, 10),
    true
  )
  H.git(root, "switch", "--orphan", "unborn")
  vim.api.nvim_exec_autocmds("User", { pattern = "GinCommandPost" })
  MiniTest.expect.equality(
    vim.wait(3000, function()
      return branch.ascii() == "unborn"
    end, 10),
    true
  )
end
T["leaving a repository clears cached component values"] = function()
  local worktree = require("gin.component.worktree")
  worktree.full()
  require("gin.component").refresh()
  MiniTest.expect.equality(
    vim.wait(3000, function()
      return worktree.full() == vim.uv.fs_realpath(root)
    end, 10),
    true
  )
  vim.cmd.cd(vim.fs.dirname(root))
  MiniTest.expect.equality(
    vim.wait(3000, function()
      return worktree.full() == ""
    end, 10),
    true
  )
  MiniTest.expect.equality(require("gin.component.branch").ascii(), "")
  MiniTest.expect.equality(require("gin.component.traffic").ascii(), "")
end
T["late results from another repository cannot replace current components"] = function()
  local component = require("gin.component")
  local branch = require("gin.component.branch")
  local worktree = require("gin.component.worktree")
  branch.ascii()
  other = H.repo()
  H.git(other, "switch", "--orphan", "new-context")
  local git = require("gin.git")
  original_start = git.start
  local held = {}
  git.start = function(args, opts, callback)
    if args[1] == "rev-list" and opts.cwd == vim.uv.fs_realpath(root) then
      return original_start(args, opts, function(result)
        held[#held + 1] = function()
          callback(result)
        end
      end)
    end
    return original_start(args, opts, callback)
  end
  component.refresh()
  MiniTest.expect.equality(
    vim.wait(3000, function()
      return #held > 0
    end, 10),
    true
  )
  vim.cmd.cd(other)
  MiniTest.expect.equality(
    vim.wait(3000, function()
      return branch.ascii() == "new-context"
    end, 10),
    true
  )
  for _, release in ipairs(held) do
    release()
  end
  local drained = false
  vim.schedule(function()
    drained = true
  end)
  MiniTest.expect.equality(
    vim.wait(3000, function()
      return drained
    end, 10),
    true
  )
  MiniTest.expect.equality(branch.ascii(), "new-context")
  MiniTest.expect.equality(worktree.full(), vim.uv.fs_realpath(other))
  MiniTest.expect.equality(require("gin.component.traffic").ascii(), "")
end
return T
