local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.mkdir(root .. "/sub", "p")
      vim.fn.writefile({ "base" }, root .. "/sub/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      vim.fn.writefile({ "index" }, root .. "/sub/file")
      H.git(root, "add", ".")
      vim.fn.writefile({ "working" }, root .. "/sub/file")
      vim.cmd.cd(root .. "/sub")
      dofile(old_cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
    end,
  },
})
T["GinDiff compares the selected working file to the index"] = function()
  vim.cmd("GinDiff -- sub/file")
  MiniTest.expect.equality(vim.bo.filetype, "gin-diff")
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("-index\n+working", 1, true) ~= nil, true)
  MiniTest.expect.equality(vim.bo.modifiable, false)
end
return T
