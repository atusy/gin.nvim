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
T["GinBuffer reload preserves special arguments"] = function()
  vim.fn.writefile({ "hello" }, root .. "/space # name")
  vim.cmd([[GinBuffer ls-files --others -- space\ #\ name]])
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "space # name" })
  vim.cmd("edit")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "space # name" })
end
T["GinBuffer respects a split modifier"] = function()
  local windows = #vim.api.nvim_tabpage_list_wins(0)
  vim.cmd("botright GinBuffer ++opener=vsplit status --short")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), windows + 1)
  vim.cmd.close()
end
return T
