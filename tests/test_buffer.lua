local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.cmd.cd(root)
      dofile(old_cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
    end,
  },
})
T["GinBuffer opens Git output in an immutable scratch buffer"] = function()
  vim.fn.writefile({ "hello" }, root .. "/file")
  vim.cmd("GinBuffer status --short")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "?? file" })
  MiniTest.expect.equality(vim.bo.buftype, "nofile")
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.bo.filetype, "gin-buffer")
  MiniTest.expect.equality(require("gin.worktree").current(), vim.uv.fs_realpath(root))
end
return T
