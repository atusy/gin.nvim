local H = require("tests.helpers")
local root, first, second
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.mkdir(root .. "/sub", "p")
      vim.fn.writefile({ "one", "two", "three" }, root .. "/sub/file.lua")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      first = vim.trim(H.git(root, "rev-parse", "HEAD"))
      vim.fn.writefile({ "one", "changed", "three" }, root .. "/sub/file.lua")
      H.git(root, "commit", "-am", "second")
      second = vim.trim(H.git(root, "rev-parse", "HEAD"))
      vim.cmd.cd(root .. "/sub")
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.tabonly({ bang = true })
      vim.cmd.only({ bang = true })
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
T["blame opens synchronized attribution and committed content from a subdirectory"] = function()
  vim.fn.writefile({ "dirty" }, root .. "/sub/file.lua")
  local tabs = #vim.api.nvim_list_tabpages()
  vim.cmd("GinBlame file.lua")
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 3)
  MiniTest.expect.equality(vim.bo.filetype, "gin-blame-nav")
  local nav = vim.api.nvim_get_current_buf()
  local file = vim.b.gin_blame_file_bufnr
  local lines = vim.api.nvim_buf_get_lines(file, 0, -1, false)
  MiniTest.expect.equality(lines, { "", "one", "", "changed", "", "three" })
  local map = vim.b[nav].gin_blame_line_map
  MiniTest.expect.equality(
    { map[2].commitSha, map[4].commitSha, map[6].commitSha },
    { first, second, first }
  )
  MiniTest.expect.equality(
    { map[2].originalLineNumber, map[4].lineNumber, map[6].originalLineNumber },
    { 1, 2, 3 }
  )
  MiniTest.expect.equality(vim.b[file].gin_blame_file_line_to_physical, { 2, 4, 6 })
  MiniTest.expect.equality(vim.bo[file].filetype, "lua.gin-blame")
  MiniTest.expect.equality(vim.bo[file].modifiable, false)
  for _, buf in ipairs({ nav, file }) do
    local win = vim.fn.bufwinid(buf)
    MiniTest.expect.equality(
      { vim.wo[win].scrollbind, vim.wo[win].cursorbind, vim.wo[win].wrap },
      { true, true, false }
    )
  end
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "dirty" })
end
return T
