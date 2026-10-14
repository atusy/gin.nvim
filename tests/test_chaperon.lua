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
      vim.wo.previewwindow = false
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
      vim.g.gin_chaperon_disable_default_mappings = nil
      vim.g.gin_chaperon_supplement_disable = nil
      vim.g.gin_chaperon_supplement_height = nil
    end,
  },
})
for _, value in ipairs({ false, true, 0, 1 }) do
  T["mapping flag " .. tostring(value) .. " retains working Plug actions"] = function()
    vim.g.gin_chaperon_disable_default_mappings = value
    vim.cmd("GinChaperon file")
    local disabled = value == true or value == 1
    MiniTest.expect.equality(vim.fn.maparg("dor", "n"), disabled and "" or "<Plug>(gin-diffget-r)")
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<Plug>(gin-diffget-r)", true, false, true),
      "mx",
      false
    )
    vim.cmd.write()
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), { "before", "ours", "after" })
  end
end
for _, value in ipairs({ "true", vim.NIL, {} }) do
  T["mapping configuration rejects " .. vim.inspect(value) .. " before opening panes"] = function()
    vim.cmd.edit("file")
    local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local index = H.git(root, "ls-files", "--stage")
    local windows = vim.api.nvim_tabpage_list_wins(0)
    vim.g.gin_chaperon_disable_default_mappings = value
    require("tests.helpers").command_error(function()
      vim.cmd("GinChaperon file")
    end, "g:gin_chaperon_disable_default_mappings must be a boolean or number")
    MiniTest.expect.equality(vim.api.nvim_get_current_buf(), buf)
    MiniTest.expect.equality(vim.api.nvim_get_current_win(), win)
    MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false), lines)
    MiniTest.expect.equality(vim.bo[buf].modified, false)
    MiniTest.expect.equality(vim.wo[win].diff, false)
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), lines)
    MiniTest.expect.equality(H.git(root, "ls-files", "--stage"), index)
  end
end
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
for _, name in ipairs({ "gin_chaperon_supplement_disable", "gin_chaperon_supplement_height" }) do
  for _, value in ipairs({ "4", false, vim.NIL, {} }) do
    T[name .. " rejects " .. vim.inspect(value) .. " before changing the editor"] = function()
      vim.cmd.edit("file")
      local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local index = H.git(root, "ls-files", "--stage")
      local windows = vim.api.nvim_tabpage_list_wins(0)
      vim.g[name] = value
      require("tests.helpers").command_error(function()
        vim.cmd("GinChaperon file")
      end, "g:" .. name .. " must be a number")
      MiniTest.expect.equality(vim.api.nvim_get_current_buf(), buf)
      MiniTest.expect.equality(vim.api.nvim_get_current_win(), win)
      MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false), lines)
      MiniTest.expect.equality(vim.bo[buf].modified, false)
      MiniTest.expect.equality(vim.wo[win].diff, false)
      MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), lines)
      MiniTest.expect.equality(H.git(root, "ls-files", "--stage"), index)
    end
  end
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
    vim.g.gin_chaperon_persistent_args = { "++no-ours", "++worktree=" .. root }
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
for _, side in ipairs({ "theirs", "ours" }) do
  T["status " .. side .. " action resolves using its sole side"] = function()
    vim.cmd.GinStatus()
    require("gin.action").call(vim.api.nvim_get_current_buf(), "chaperon:" .. side, { 2, 2 })
    MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
    MiniTest.expect.equality(vim.fn.maparg(side == "theirs" and "dor" or "dol", "n"), "")
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys("do", "mx", false)
    vim.cmd.write()
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), { "before", side, "after" })
    MiniTest.expect.equality(H.git(root, "ls-files", "--unmerged") ~= "", true)
    vim.cmd("Gin ++wait add -- %:p")
    MiniTest.expect.equality(H.git(root, "ls-files", "--unmerged"), "")
    MiniTest.expect.equality(H.git(root, "show", ":sub/file"), "before\n" .. side .. "\nafter\n")
  end
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
for _, opener in ipairs({ "split", "vsplit", "pedit" }) do
  for _, sides in ipairs({ false, true }) do
    T[opener .. " uses the opened conflict window, sides=" .. tostring(sides)] = function()
      vim.cmd.edit("file")
      local original = vim.api.nvim_get_current_win()
      local file = vim.api.nvim_get_current_buf()
      vim.cmd(
        "botright GinChaperon ++opener="
          .. opener
          .. (sides and " file" or " ++no-ours ++no-theirs file")
      )
      MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), sides and 4 or 2)
      MiniTest.expect.equality(vim.api.nvim_get_current_buf(), file)
      MiniTest.expect.equality(vim.api.nvim_get_current_win() ~= original, true)
      MiniTest.expect.equality(vim.wo[original].diff, false)
      MiniTest.expect.equality(vim.wo.diff, true)
      MiniTest.expect.equality(vim.wo.previewwindow, opener == "pedit")
      MiniTest.expect.equality(
        vim.api.nvim_buf_get_lines(file, 0, -1, false),
        { "before", "after" }
      )
      MiniTest.expect.equality(H.git(root, "ls-files", "--unmerged") ~= "", true)
    end
  end
end
T["reopening chaperon refreshes visible conflict stages"] = function()
  local panes = require("gin.chaperon").command({ fargs = { "file" }, smods = {} })
  local working = vim.fn.readfile(root .. "/sub/file")
  local resolution = { "before", "manual resolution", "after" }
  vim.api.nvim_buf_set_lines(panes.worktree, 0, -1, false, resolution)
  local git = require("gin.git")
  for stage, content in pairs({ [2] = "new ours", [3] = "new theirs" }) do
    local hash = vim.trim(git.run({ "hash-object", "-w", "--stdin" }, {
      cwd = root,
      stdin = "before\n" .. content .. "\nafter\n",
    }).stdout)
    git.run({ "update-index", "-z", "--index-info" }, {
      cwd = root,
      stdin = "100644 " .. hash .. " " .. stage .. "\tsub/file\0",
    })
  end
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(panes.ours, 1, 2, false), { "ours" })
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(panes.theirs, 1, 2, false), { "theirs" })
  local reopened =
    require("gin.chaperon").command({ fargs = { "++opener=tabedit", "file" }, smods = {} })
  MiniTest.expect.equality(reopened.ours, panes.ours)
  MiniTest.expect.equality(reopened.theirs, panes.theirs)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(reopened.ours, 1, 2, false), { "new ours" })
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(reopened.theirs, 1, 2, false),
    { "new theirs" }
  )
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), working)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(reopened.worktree, 0, -1, false), resolution)
end
for _, operation in ipairs({ "cherry-pick", "rebase", "revert" }) do
  T[operation .. " conflict supplements use the active operation head"] = function()
    H.git(root, "merge", "--abort")
    local ours = vim.trim(H.git(root, "rev-parse", "main"))
    local theirs = vim.trim(H.git(root, "rev-parse", "topic"))
    local args, alias, expected_head
    if operation == "cherry-pick" then
      args, alias, expected_head = { "cherry-pick", "topic" }, "CHERRY_PICK_HEAD", theirs
    elseif operation == "rebase" then
      args, alias, expected_head = { "rebase", "topic" }, "REBASE_HEAD", ours
    else
      H.git(root, "checkout", "topic")
      args, alias, expected_head = { "revert", "--no-edit", "main" }, "REVERT_HEAD", ours
    end
    local result = require("gin.git").run(args, { cwd = root, check = false })
    MiniTest.expect.equality(result.code, 1)
    MiniTest.expect.equality(vim.trim(H.git(root, "rev-parse", alias)), expected_head)
    local index = H.git(root, "ls-files", "--stage")
    local working = vim.fn.readfile(root .. "/sub/file")
    vim.g.gin_chaperon_supplement_disable = 0
    vim.g.gin_chaperon_supplement_height = 4
    local panes = require("gin.chaperon").command({ fargs = { "file" }, smods = {} })
    local logs = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if not vim.wo[win].diff then
        local buf = vim.api.nvim_win_get_buf(win)
        local command = require("gin.uri").parse(vim.api.nvim_buf_get_name(buf)).fragment
        logs[command] = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
        MiniTest.expect.equality(vim.wo[win].winfixheight, true)
      end
    end
    MiniTest.expect.equality(vim.tbl_count(logs), 3)
    MiniTest.expect.equality(
      logs["log -1 " .. alias .. " -p"],
      H.git(root, "log", "-1", alias, "-p")
    )
    MiniTest.expect.equality(logs["log -1 HEAD -p"], H.git(root, "log", "-1", "HEAD", "-p"))
    MiniTest.expect.equality(
      logs["log --oneline --left-right " .. alias .. "...HEAD"],
      H.git(root, "log", "--oneline", "--left-right", alias .. "...HEAD")
    )
    for stage, side in pairs({ [2] = "ours", [3] = "theirs" }) do
      MiniTest.expect.equality(
        table.concat(vim.api.nvim_buf_get_lines(panes[side], 0, -1, false), "\n") .. "\n",
        H.git(root, "show", ":" .. stage .. ":sub/file")
      )
    end
    MiniTest.expect.equality(vim.api.nvim_get_current_buf(), panes.worktree)
    MiniTest.expect.equality(H.git(root, "ls-files", "--stage"), index)
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), working)
  end
end
for _, side in ipairs({ "ours", "theirs" }) do
  T[side .. " diffput resolves the working buffer before explicit write and stage"] = function()
    local working = vim.fn.readfile(root .. "/sub/file")
    local index = H.git(root, "ls-files", "--stage")
    local panes = require("gin.chaperon").command({ fargs = { "file" }, smods = {} })
    vim.api.nvim_set_current_win(vim.fn.bufwinid(panes[side]))
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys("dp", "mx", false)
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(panes.worktree, 0, -1, false),
      { "before", side, "after" }
    )
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), working)
    MiniTest.expect.equality(H.git(root, "ls-files", "--stage"), index)
    vim.api.nvim_set_current_win(vim.fn.bufwinid(panes.worktree))
    vim.cmd.write()
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), { "before", side, "after" })
    MiniTest.expect.equality(H.git(root, "ls-files", "--stage"), index)
    vim.cmd("Gin ++wait add -- %:p")
    MiniTest.expect.equality(H.git(root, "ls-files", "--unmerged"), "")
    MiniTest.expect.equality(H.git(root, "show", ":sub/file"), "before\n" .. side .. "\nafter\n")
  end
end
return T
