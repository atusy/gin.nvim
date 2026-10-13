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
      vim.cmd("silent! tabonly!")
      vim.cmd("silent! only!")
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
T["show split retains tag view and jumps to the shown revision"] = function()
  vim.cmd("GinTag light")
  local tag = vim.api.nvim_get_current_buf()
  require("gin.action").call(tag, "show:split", { 1, 1 })
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
  MiniTest.expect.equality(vim.api.nvim_win_get_buf(vim.fn.bufwinid(tag)), tag)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local row
  for i, line in ipairs(lines) do
    if line == "+base" then
      row = i
    end
  end
  assert(row)
  MiniTest.expect.equality(vim.fn.foldlevel(row), 1)
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Plug>(gin-diffjump-smart)", true, false, true),
    "mx",
    false
  )
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "base")
  MiniTest.expect.equality(vim.bo.modifiable, false)
end
T["show tab opens the selected object in another tab"] = function()
  vim.cmd("GinTag release")
  local tabs = #vim.api.nvim_list_tabpages()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "show:tabedit", { 1, 1 })
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(text:find("release notes", 1, true) ~= nil, true)
end

T["tag emojify retains selected deletion targets across reload"] = function()
  H.git(root, "tag", "-a", "emoji", "-m", ":sparkles: release")
  local commit = vim.trim(H.git(root, "rev-parse", "emoji"))
  vim.cmd("GinTag ++emojify")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.b.gin_tags[1], { tag = "emoji", commit = commit })
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]:find("✨ release", 1, true) ~= nil,
    true
  )
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "tag", "--list"), "light\nrelease\n")
end

T["tag decoding options survive reload and preserve deletion targets"] = function()
  H.git(root, "tag", "-a", "encoded", "-m", "caf" .. string.char(233))
  vim.cmd("GinTag ++enc=latin1 ++ff=unix encoded")
  vim.cmd.edit()
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]:find("café", 1, true) ~= nil,
    true
  )
  MiniTest.expect.equality(vim.bo.fileencoding, "latin1")
  MiniTest.expect.equality(vim.bo.fileformat, "unix")
  MiniTest.expect.equality(vim.b.gin_tags[1].tag, "encoded")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "tag", "--list", "encoded"), "")
end
return T
