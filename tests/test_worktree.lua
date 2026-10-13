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
T["file symlinks resolve target repositories after checking their own directory"] = function()
  vim.fn.writefile({ "target" }, root .. "/file")
  local directory = root .. " symlink"
  vim.fn.mkdir(directory, "p")
  assert(vim.uv.fs_symlink(root .. "/file", directory .. "/link"))
  vim.cmd.edit(vim.fn.fnameescape(directory .. "/link"))
  local worktree = require("gin.worktree")
  local component = require("gin.component.worktree")
  for _, expected in ipairs({ root, directory }) do
    if expected == directory then
      H.git(directory, "init", "--initial-branch=local-link")
    end
    MiniTest.expect.equality(worktree.current(), vim.uv.fs_realpath(expected))
    component.full()
    require("gin.component").refresh()
    MiniTest.expect.equality(
      vim.wait(3000, function()
        return component.full() == vim.uv.fs_realpath(expected)
      end, 10),
      true
    )
  end
end
T["Gin URI buffers resolve their repository without cached buffer variables"] = function()
  local worktree = require("gin.worktree")
  local component = require("gin.component.worktree")
  local outside = worktree.find(saved_cwd)
  for _, scheme in ipairs({
    "gin",
    "ginbranch",
    "gindiff",
    "ginedit",
    "ginlog",
    "ginreflog",
    "ginstash",
    "ginstatus",
  }) do
    vim.cmd.enew({ bang = true })
    component.full()
    require("gin.component").refresh()
    MiniTest.expect.equality(
      vim.wait(3000, function()
        return component.full() == outside
      end, 10),
      true
    )
    local name = require("gin.uri").format(scheme, root, { commitish = "HEAD" }, "space # name")
    vim.api.nvim_buf_set_name(0, name)
    MiniTest.expect.equality(vim.b.gin_worktree, nil)
    MiniTest.expect.equality(worktree.current(), vim.uv.fs_realpath(root))
    MiniTest.expect.equality(worktree.find(name), vim.uv.fs_realpath(root))
    component.full()
    require("gin.component").refresh()
    MiniTest.expect.equality(
      vim.wait(3000, function()
        return component.full() == vim.uv.fs_realpath(root)
      end, 10),
      true
    )
  end
end
T["public worktree utility resolves the current view and explicit paths"] = function()
  vim.fn.mkdir(root .. "/sub", "p")
  vim.cmd.enew()
  vim.api.nvim_buf_set_name(0, require("gin.uri").format("ginstatus", root, {}, nil))
  local util = require("gin.util")
  MiniTest.expect.equality(util.worktree(), vim.uv.fs_realpath(root))
  MiniTest.expect.equality(util.worktree(root .. "/sub"), vim.uv.fs_realpath(root))
  MiniTest.expect.error(function()
    util.worktree(root .. "/missing")
  end, "No git repository")
  MiniTest.expect.error(function()
    util.worktree(42)
  end, "string")
end
return T
