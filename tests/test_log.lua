local H = require("tests.helpers")
local root, first, second
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.writefile({ "first" }, root .. "/one")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "first change")
      first = vim.trim(H.git(root, "rev-parse", "HEAD"))
      vim.fn.writefile({ "second" }, root .. "/two")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "second change")
      second = vim.trim(H.git(root, "rev-parse", "HEAD"))
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd("silent! tabonly!")
      vim.cmd("silent! only!")
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
T["log preserves history order and yanks selected commits"] = function()
  vim.cmd("GinLog --oneline")
  local entries = require("gin.log").candidates(vim.api.nvim_get_current_buf(), { 1, 2 })
  MiniTest.expect.equality(#entries, 2)
  MiniTest.expect.equality(second:sub(1, #entries[1].commit), entries[1].commit)
  vim.api.nvim_feedkeys('"ayy', "mx", false)
  MiniTest.expect.equality(vim.fn.getreg("a"), entries[1].commit)
end
T["log revision and path filters survive reload"] = function()
  vim.cmd("GinLog --oneline HEAD -- one")
  vim.cmd.edit()
  local entries = require("gin.log").candidates(vim.api.nvim_get_current_buf(), { 1, 99 })
  MiniTest.expect.equality(#entries, 1)
  MiniTest.expect.equality(first:sub(1, #entries[1].commit), entries[1].commit)
end
T["log show opens the selected commit diff"] = function()
  vim.cmd("GinLog --oneline")
  vim.api.nvim_feedkeys("\r", "mx", false)
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("+second", 1, true) ~= nil, true)
end
T["default and graph formats identify commit headers"] = function()
  for _, command in ipairs({ "GinLog", "GinLog --graph --oneline" }) do
    vim.cmd(command)
    local rows = require("gin.log").candidates(vim.api.nvim_get_current_buf(), { 1, 999 })
    MiniTest.expect.equality(#rows, 2)
    MiniTest.expect.equality(second:sub(1, #rows[1].commit), rows[1].commit)
    MiniTest.expect.equality(first:sub(1, #rows[2].commit), rows[2].commit)
  end
end
T["branch log action opens the selected branch history in a split"] = function()
  H.git(root, "branch", "older", first)
  vim.cmd("GinBranch older")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "log:split", { 1, 1 })
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
  MiniTest.expect.equality(vim.bo.filetype, "gin-log")
  local rows = require("gin.log").candidates(vim.api.nvim_get_current_buf(), { 1, 999 })
  MiniTest.expect.equality(rows, { { commit = first } })
end
return T
