local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      H.git(root, "config", "user.name", "Gin Test")
      H.git(root, "config", "user.email", "gin@example.invalid")
      vim.fn.mkdir(root .. "/sub", "p")
      vim.fn.writefile({ "before", "base", "after" }, root .. "/sub/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "base")
      H.git(root, "branch", "topic")
      vim.fn.writefile({ "before", "ours", "after" }, root .. "/sub/file")
      H.git(root, "commit", "-am", "ours")
      H.git(root, "checkout", "topic")
      vim.fn.writefile({ "before", "theirs", "after" }, root .. "/sub/file")
      H.git(root, "commit", "-am", "theirs")
      H.git(root, "checkout", "main")
      local result = require("gin.git").run(
        { "merge", "--no-edit", "topic" },
        { cwd = root, check = false }
      )
      assert(result.code == 1, result.stderr)
      vim.cmd.cd(root .. "/sub")
      vim.g.gin_chaperon_supplement_disable = 1
      dofile(old_cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd("silent! tabonly!")
      vim.cmd("silent! only!")
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
      vim.g.gin_chaperon_supplement_disable = nil
      vim.g.gin_chaperon_supplement_height = nil
    end,
  },
})
T["GinChaperon resolves a conflict from the ours pane"] = function()
  vim.cmd("GinChaperon file")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 3)
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/sub/file")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "before", "after" })
  MiniTest.expect.equality(vim.bo.modified, true)
  MiniTest.expect.equality(vim.wo.diff, true)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys("dor", "mx", false)
  vim.cmd.write()
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), { "before", "ours", "after" })
  MiniTest.expect.equality(H.git(root, "ls-files", "--unmerged") ~= "", true)
  vim.cmd("Gin ++wait add -- %:p")
  MiniTest.expect.equality(H.git(root, "ls-files", "--unmerged"), "")
  MiniTest.expect.equality(H.git(root, "show", ":sub/file"), "before\nours\nafter\n")
end
T["default supplements show both commits and their comparison"] = function()
  vim.g.gin_chaperon_supplement_disable = nil
  vim.g.gin_chaperon_supplement_height = 4
  local original = vim.fn.readfile(root .. "/sub/file")
  vim.cmd("GinChaperon file")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 6)
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/sub/file")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), original)
  local logs, diffs = {}, 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.wo[win].diff then
      diffs = diffs + 1
    else
      MiniTest.expect.equality(vim.wo[win].winfixheight, true)
      MiniTest.expect.equality(vim.api.nvim_win_get_height(win), 4)
      local buf = vim.api.nvim_win_get_buf(win)
      local name = vim.api.nvim_buf_get_name(buf)
      local args = require("gin.uri").parse(name).fragment
      logs[args] = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    end
  end
  MiniTest.expect.equality(diffs, 3)
  MiniTest.expect.equality(logs["log -1 MERGE_HEAD -p"]:find("+theirs", 1, true) ~= nil, true)
  MiniTest.expect.equality(logs["log -1 HEAD -p"]:find("+ours", 1, true) ~= nil, true)
  local comparison = logs["log --oneline --left-right MERGE_HEAD...HEAD"]
  MiniTest.expect.equality(comparison:find("theirs", 1, true) ~= nil, true)
  MiniTest.expect.equality(comparison:find("ours", 1, true) ~= nil, true)
end
T["status chaperon opens the selected conflict in a new tab"] = function()
  vim.cmd.GinStatus()
  local tabs = #vim.api.nvim_list_tabpages()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys("!!", "mx", false)
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 3)
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/sub/file")
end
T["status chaperon honors persistent pane settings through conflict resolution"] = function()
  vim.cmd.GinStatus()
  local status = vim.api.nvim_get_current_buf()
  local tabs = #vim.api.nvim_list_tabpages()
  local previous = vim.g.gin_chaperon_persistent_args
  vim.g.gin_chaperon_persistent_args = { "++no-ours", "++opener=split" }
  local ok, err = pcall(function()
    MiniTest.expect.error(function()
      require("gin.action").call(status, "chaperon:both", { 2, 2 })
    end, "Duplicate Gin option: %+%+opener")
    vim.g.gin_chaperon_persistent_args = { "++no-ours" }
    require("gin.action").call(status, "chaperon:both", { 2, 2 })
    MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
    MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys("do", "mx", false)
    vim.cmd.write()
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), { "before", "theirs", "after" })
    MiniTest.expect.equality(H.git(root, "ls-files", "--unmerged") ~= "", true)
    vim.cmd("Gin ++wait add -- %:p")
    MiniTest.expect.equality(H.git(root, "ls-files", "--unmerged"), "")
    MiniTest.expect.equality(H.git(root, "show", ":sub/file"), "before\ntheirs\nafter\n")
  end)
  vim.g.gin_chaperon_persistent_args = previous
  assert(ok, err)
end
T["status theirs action resolves using its sole side"] = function()
  vim.cmd.GinStatus()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "chaperon:theirs", { 2, 2 })
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
  MiniTest.expect.equality(vim.fn.maparg("dor", "n"), "")
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys("do", "mx", false)
  vim.cmd.write()
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), { "before", "theirs", "after" })
end
T["GinChaperon defaults to current file and can omit theirs"] = function()
  vim.cmd.edit("file")
  vim.cmd("GinChaperon ++no-theirs")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
  MiniTest.expect.equality(vim.fn.maparg("dol", "n"), "")
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys("do", "mx", false)
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "before", "ours", "after" }
  )
end
return T
