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
T["GinDiff cached comparison survives URI reload"] = function()
  vim.cmd("GinDiff --cached -U0 -- sub/file")
  vim.cmd.edit()
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("-base\n+index", 1, true) ~= nil, true)
end
T["GinDiff compares an explicit revision range"] = function()
  H.git(root, "commit", "-m", "second")
  vim.cmd("GinDiff HEAD^..HEAD -- sub/file")
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("-base\n+index", 1, true) ~= nil, true)
  MiniTest.expect.equality(content:find("working", 1, true), nil)
end
T["status smart diff selects the cached changes when both sides differ"] = function()
  vim.cmd.GinStatus()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys("dd", "mx", false)
  MiniTest.expect.equality(vim.bo.filetype, "gin-diff")
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("-base\n+index", 1, true) ~= nil, true)
end
return T
