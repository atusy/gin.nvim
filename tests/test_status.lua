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
T["GinStatus lists the branch and untracked paths in sorted order"] = function()
  vim.fn.writefile({ "z" }, root .. "/z")
  vim.fn.writefile({ "a" }, root .. "/a")
  vim.cmd.GinStatus()
  MiniTest.expect.equality(vim.bo.filetype, "gin-status")
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "## No commits yet on main", "?? a", "?? z" }
  )
end
return T
