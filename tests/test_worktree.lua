local H = require("tests.helpers")
local root
local saved_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(saved_cwd)
      vim.fn.delete(root .. " linked", "rf")
      vim.fn.delete(root .. " symlink", "rf")
      H.cleanup(root)
    end,
  },
})
T["discovers repository from an existing file in a subdirectory"] = function()
  vim.fn.mkdir(root .. "/sub", "p")
  vim.fn.writefile({ "text" }, root .. "/sub/file")
  MiniTest.expect.equality(
    require("gin.worktree").find(root .. "/sub/file"),
    vim.uv.fs_realpath(root)
  )
end
T["current buffer repository takes priority over cwd"] = function()
  vim.fn.writefile({ "hello" }, root .. "/file")
  vim.cmd.edit(vim.fn.fnameescape(root .. "/file"))
  MiniTest.expect.equality(require("gin.worktree").current(), vim.uv.fs_realpath(root))
end
T["linked worktree resolves to its own root"] = function()
  H.git(root, "commit", "--allow-empty", "-m", "initial")
  local linked = root .. " linked"
  H.git(root, "worktree", "add", "-b", "linked", linked)
  vim.fn.mkdir(linked .. "/sub", "p")
  MiniTest.expect.equality(
    require("gin.worktree").find(linked .. "/sub"),
    vim.uv.fs_realpath(linked)
  )
end
T["symlinked directory resolves to the real root"] = function()
  local link = root .. " symlink"
  assert(vim.uv.fs_symlink(root, link))
  MiniTest.expect.equality(require("gin.worktree").find(link), vim.uv.fs_realpath(root))
end
T["explicit missing repository fails without falling back"] = function()
  vim.cmd.cd(root)
  MiniTest.expect.error(function()
    require("gin.worktree").current(root .. "/missing")
  end, "No git repository found")
end
return T
