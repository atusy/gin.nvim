local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.mkdir(root .. "/sub", "p")
      local base = { "first", "1", "2", "3", "4", "5", "6", "7", "8", "last" }
      vim.fn.writefile(base, root .. "/sub/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      base[1], base[10] = "changed first", "changed last"
      vim.fn.writefile(base, root .. "/sub/file")
      vim.cmd.cd(root .. "/sub")
      dofile(old_cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd("silent! tabonly!")
      vim.cmd("silent! only!")
      vim.wo.previewwindow = false
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
      vim.g.gin_patch_disable_default_mappings = nil
    end,
  },
})
for _, value in ipairs({ false, true, 0, 1 }) do
  T["mapping flag " .. tostring(value) .. " retains working Plug actions"] = function()
    vim.g.gin_patch_disable_default_mappings = value
    vim.cmd("GinPatch file")
    local disabled = value == true or value == 1
    MiniTest.expect.equality(vim.fn.maparg("dor", "n"), disabled and "" or "<Plug>(gin-diffget-r)")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<Plug>(gin-diffget-r)", true, false, true),
      "mx",
      false
    )
    vim.cmd.write()
    MiniTest.expect.equality(H.git(root, "show", ":sub/file"):match("^[^\n]+"), "changed first")
  end
end
for _, value in ipairs({ "true", vim.NIL, {} }) do
  T["mapping configuration rejects " .. vim.inspect(value) .. " before opening panes"] = function()
    vim.cmd.edit("file")
    local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local index = H.git(root, "ls-files", "--stage")
    local windows = vim.api.nvim_tabpage_list_wins(0)
    vim.g.gin_patch_disable_default_mappings = value
    require("tests.helpers").command_error(function()
      vim.cmd("GinPatch file")
    end, "g:gin_patch_disable_default_mappings must be a boolean or number")
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
T["GinPatch stages only the chosen hunk from a subdirectory"] = function()
  vim.cmd("GinPatch file")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 3)
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  MiniTest.expect.equality(vim.wo.diff, true)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys("dor", "mx", false)
  vim.cmd.write()
  local index = H.git(root, "show", ":sub/file")
  MiniTest.expect.equality(index:find("changed first", 1, true) ~= nil, true)
  MiniTest.expect.equality(index:find("changed last", 1, true), nil)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file")[10], "changed last")
end
T["explicit encoding and fileformat apply to every patch pane"] = function()
  local path = "sub/encoded | file"
  vim.fn.writefile({ "café\r", "" }, root .. "/" .. path, "b")
  H.git(root, "add", path)
  H.git(root, "commit", "-m", "encoded")
  local original_index = H.git(root, "show", ":" .. path)
  vim.cmd("GinPatch ++enc=latin1 ++ff=unix " .. vim.fn.fnameescape("encoded | file"))
  local expected = vim.fn.iconv("café", "latin1", "utf-8") .. "\r"
  local working
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { expected })
    MiniTest.expect.equality(vim.bo[buf].fileencoding, "latin1")
    MiniTest.expect.equality(vim.bo[buf].fileformat, "unix")
    if vim.bo[buf].buftype == "" then
      working = win
    end
  end
  assert(working, "working pane exists")
  vim.api.nvim_set_current_win(working)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { expected .. "!" })
  vim.cmd.write()
  MiniTest.expect.equality(vim.fn.readfile(root .. "/" .. path, "b"), { "café\r!", "" })
  MiniTest.expect.equality(H.git(root, "show", ":" .. path), original_index)
end
T["status patch honors persistent pane settings and stages the chosen hunk"] = function()
  vim.cmd.GinStatus()
  local status = vim.api.nvim_get_current_buf()
  local tabs = #vim.api.nvim_list_tabpages()
  local previous = vim.g.gin_patch_persistent_args
  vim.g.gin_patch_persistent_args = { "++no-head", "++opener=split" }
  local ok, err = pcall(function()
    MiniTest.expect.error(function()
      require("gin.action").call(status, "patch:both", { 2, 2 })
    end, "Duplicate Gin option: %+%+opener")
    vim.g.gin_patch_persistent_args = { "++no-head", "++worktree=" .. root }
    require("gin.action").call(status, "patch:both", { 2, 2 })
    MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
    MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
    MiniTest.expect.equality(vim.bo.buftype, "acwrite")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_feedkeys("dor", "mx", false)
    vim.cmd.write()
    local index = H.git(root, "show", ":sub/file")
    MiniTest.expect.equality(index:find("changed first", 1, true) ~= nil, true)
    MiniTest.expect.equality(index:find("changed last", 1, true), nil)
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file")[10], "changed last")
  end)
  vim.g.gin_patch_persistent_args = previous
  assert(ok, err)
end
T["GinPatch can unstage one hunk without a working-tree pane"] = function()
  H.git(root, "add", "sub/file")
  vim.cmd("GinPatch ++no-worktree file")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys("dol", "mx", false)
  vim.cmd.write()
  local index = H.git(root, "show", ":sub/file")
  MiniTest.expect.equality(index:find("changed first", 1, true), nil)
  MiniTest.expect.equality(index:find("changed last", 1, true) ~= nil, true)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file")[1], "changed first")
end
T["GinPatch defaults to the current file and can omit HEAD"] = function()
  vim.cmd.edit("file")
  vim.cmd("GinPatch ++no-head")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys("do", "mx", false)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, 1, false), { "changed first" })
end
T["reopening patch with fewer panes removes stale directional mappings"] = function()
  vim.cmd("GinPatch file")
  vim.cmd("only!")
  vim.cmd("GinPatch ++no-head file")
  MiniTest.expect.equality(vim.fn.maparg("dol", "n"), "")
  MiniTest.expect.equality(vim.fn.maparg("<Plug>(gin-diffget-l)", "n"), "")
end
T["reopening patch preserves user mappings to its Plug actions"] = function()
  vim.cmd("GinPatch file")
  vim.keymap.set("n", "Q", "<Plug>(gin-diffget)", { buffer = true, remap = true })
  vim.cmd("only!")
  vim.cmd("GinPatch ++no-head file")
  MiniTest.expect.equality(vim.fn.maparg("Q", "n"), "<Plug>(gin-diffget)")
end
T["status patch action opens the selected file in a new tab"] = function()
  vim.cmd.GinStatus()
  local tabs = #vim.api.nvim_list_tabpages()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys("pp", "mx", false)
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 3)
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  MiniTest.expect.equality(vim.b.gin_path, "sub/file")
end
for _, side in ipairs({ "head", "worktree" }) do
  T["status patch " .. side .. " applies only the selected hunk"] = function()
    if side == "head" then
      H.git(root, "add", "sub/file")
    end
    vim.cmd.GinStatus()
    local tabs = #vim.api.nvim_list_tabpages()
    require("gin.action").call(vim.api.nvim_get_current_buf(), "patch:" .. side, { 2, 2 })
    MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
    MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
    MiniTest.expect.equality(vim.b.gin_path, "sub/file")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_feedkeys("do", "mx", false)
    vim.cmd.write()
    local index = vim.split(H.git(root, "show", ":sub/file"), "\n", { trimempty = true })
    MiniTest.expect.equality(index[1], side == "head" and "first" or "changed first")
    MiniTest.expect.equality(index[10], side == "head" and "changed last" or "last")
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file")[1], "changed first")
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file")[10], "changed last")
  end
end
for _, case in ipairs({
  { source = "head", keys = "dp", target = "index", staged = true },
  { source = "worktree", keys = "dp", target = "index" },
  { source = "index", keys = "dp", target = "worktree" },
  { source = "worktree", keys = "do", target = "worktree" },
}) do
  T[case.source .. " " .. case.keys .. " updates only the target patch hunk"] = function()
    if case.staged then
      H.git(root, "add", "sub/file")
    end
    local before_index = H.git(root, "show", ":sub/file")
    local before_working = vim.fn.readfile(root .. "/sub/file")
    local panes = require("gin.patch").command({ fargs = { "file" }, smods = {} })
    vim.api.nvim_set_current_win(vim.fn.bufwinid(panes[case.source]))
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_feedkeys(case.keys, "mx", false)
    local target = panes[case.target]
    local lines = vim.api.nvim_buf_get_lines(target, 0, -1, false)
    local staging = case.source == "worktree" and case.keys == "dp"
    MiniTest.expect.equality(lines[1], staging and "changed first" or "first")
    MiniTest.expect.equality(
      lines[10],
      (case.target == "worktree" or case.staged) and "changed last" or "last"
    )
    MiniTest.expect.equality(H.git(root, "show", ":sub/file"), before_index)
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), before_working)
    vim.api.nvim_set_current_win(vim.fn.bufwinid(target))
    vim.cmd.write()
    if case.target == "index" then
      MiniTest.expect.equality(H.git(root, "show", ":sub/file"), table.concat(lines, "\n") .. "\n")
      MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), before_working)
    else
      MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), lines)
      MiniTest.expect.equality(H.git(root, "show", ":sub/file"), before_index)
    end
  end
end
T["reopening patch refreshes an index already visible in another window"] = function()
  local panes = require("gin.patch").command({ fargs = { "file" }, smods = {} })
  vim.api.nvim_set_current_win(vim.fn.bufwinid(panes.worktree))
  H.git(root, "add", "sub/file")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(panes.index, 0, 1, false), { "first" })
  local reopened = require("gin.patch").command({ fargs = { "file" }, smods = {} })
  MiniTest.expect.equality(reopened.index, panes.index)
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(reopened.index, 0, 1, false),
    { "changed first" }
  )
end
T["reopening patch retains unsaved index edits"] = function()
  local panes = require("gin.patch").command({ fargs = { "file" }, smods = {} })
  vim.api.nvim_buf_set_lines(panes.index, 0, 1, false, { "unsaved index" })
  local before = H.git(root, "show", ":sub/file")
  vim.api.nvim_set_current_win(vim.fn.bufwinid(panes.worktree))
  local reopened = require("gin.patch").command({ fargs = { "file" }, smods = {} })
  MiniTest.expect.equality(reopened.index, panes.index)
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(reopened.index, 0, 1, false),
    { "unsaved index" }
  )
  MiniTest.expect.equality(vim.bo[reopened.index].modified, true)
  MiniTest.expect.equality(H.git(root, "show", ":sub/file"), before)
end
for _, method in ipairs({ "get", "put" }) do
  for _, selection in ipairs({ "2GV9j", "11GV9k" }) do
    T["visual " .. method .. " " .. selection .. " stages only the selected change"] = function()
      local base = {}
      for i = 1, 22 do
        base[i] = "line " .. i
      end
      vim.fn.writefile(base, root .. "/sub/selection")
      H.git(root, "add", "sub/selection")
      H.git(root, "commit", "-m", "selection")
      local working = vim.deepcopy(base)
      working[3], working[10], working[20] = "changed 3", "changed 10", "changed 20"
      local expected = vim.deepcopy(base)
      expected[3], expected[10] = working[3], working[10]
      vim.fn.writefile(working, root .. "/sub/selection")
      local panes = require("gin.patch").command({ fargs = { "selection" }, smods = {} })
      vim.cmd.diffupdate()
      local source = method == "get" and panes.index or panes.worktree
      vim.api.nvim_set_current_win(vim.fn.bufwinid(source))
      vim.api.nvim_feedkeys(selection .. (method == "get" and "dor" or "dp"), "mx", false)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(panes.index, 0, -1, false), expected)
      MiniTest.expect.equality(
        H.git(root, "show", ":sub/selection"),
        table.concat(base, "\n") .. "\n"
      )
      vim.api.nvim_set_current_win(vim.fn.bufwinid(panes.index))
      vim.cmd.write()
      MiniTest.expect.equality(
        H.git(root, "show", ":sub/selection"),
        table.concat(expected, "\n") .. "\n"
      )
      MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/selection"), working)
    end
  end
end
for _, opener in ipairs({ "split", "vsplit" }) do
  T[opener .. " opener focuses the new index window when the buffer is already visible"] = function()
    vim.cmd("GinEdit sub/file")
    local original = vim.api.nvim_get_current_win()
    local index = vim.api.nvim_get_current_buf()
    vim.cmd("botright GinPatch ++opener=" .. opener .. " ++no-head ++no-worktree file")
    MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
    MiniTest.expect.equality(vim.api.nvim_get_current_buf(), index)
    MiniTest.expect.equality(vim.api.nvim_get_current_win() ~= original, true)
    MiniTest.expect.equality(vim.wo[original].diff, false)
    MiniTest.expect.equality(vim.wo.diff, true)
  end
end
for _, existing in ipairs({ false, true }) do
  T["preview opener selects the index preview, existing=" .. tostring(existing)] = function()
    vim.cmd("GinEdit sub/file")
    local original = vim.api.nvim_get_current_win()
    local index = vim.api.nvim_get_current_buf()
    if existing then
      vim.cmd("pedit file")
    end
    vim.cmd("GinPatch ++opener=pedit ++no-head ++no-worktree file")
    MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
    MiniTest.expect.equality(vim.api.nvim_get_current_buf(), index)
    MiniTest.expect.equality(vim.wo.previewwindow, true)
    MiniTest.expect.equality(vim.api.nvim_get_current_win() ~= original, true)
    MiniTest.expect.equality(vim.wo[original].diff, false)
    MiniTest.expect.equality(vim.wo.diff, true)
  end
end
return T
