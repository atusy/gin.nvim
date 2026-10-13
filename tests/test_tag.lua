local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.writefile({ "base" }, root .. "/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      H.git(root, "tag", "light")
      H.git(root, "tag", "-a", "release", "-m", "release notes")
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
T["tag view lists lightweight and annotated tags and yanks names"] = function()
  vim.cmd.GinTag()
  MiniTest.expect.equality(vim.bo.filetype, "gin-tag")
  MiniTest.expect.equality({ vim.b.gin_tags[1].tag, vim.b.gin_tags[2].tag }, { "light", "release" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys('"ayy', "mx", false)
  MiniTest.expect.equality(vim.fn.getreg("a"), "release")
end
T["tag delete removes only selected refs"] = function()
  vim.cmd.GinTag()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "tag", "--list"), "release\n")
  MiniTest.expect.equality(#vim.b.gin_tags, 1)
end
T["tag show opens annotated tag content"] = function()
  vim.cmd("GinTag rel*")
  vim.cmd.edit()
  vim.api.nvim_feedkeys("\r", "mx", false)
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("release notes", 1, true) ~= nil, true)
end
T["tag detach switches to the tagged commit"] = function()
  vim.cmd.GinTag()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "switch:detach", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "branch", "--show-current"), "")
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), H.git(root, "rev-parse", "light"))
end
return T
