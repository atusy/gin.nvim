local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.mkdir(root .. "/sub", "p")
      vim.fn.writefile({ "committed" }, root .. "/sub/file.lua")
      H.git(root, "add", "sub/file.lua")
      H.git(root, "commit", "-m", "initial")
      vim.fn.writefile({ "index" }, root .. "/sub/file.lua")
      H.git(root, "add", "sub/file.lua")
      vim.fn.writefile({ "working" }, root .. "/sub/file.lua")
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
T["GinEdit reads an immutable revision using repository-relative paths"] = function()
  vim.cmd("GinEdit HEAD sub/file.lua")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "committed" })
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.bo.buftype, "nowrite")
  MiniTest.expect.equality(vim.bo.filetype, "lua")
end
T["writing GinEdit changes only the index from a subdirectory"] = function()
  vim.cmd("GinEdit sub/file.lua")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "index" })
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "edited index" })
  vim.cmd.write()
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "edited index\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "working" })
  MiniTest.expect.equality(vim.bo.modified, false)
end
return T
