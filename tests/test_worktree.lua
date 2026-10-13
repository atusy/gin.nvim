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
      vim.fn.delete(root, "rf")
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
return T
