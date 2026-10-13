local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.cmd.cd(root)
      dofile(old_cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
    end,
  },
})
T["GinStatus lists the branch and untracked paths in sorted order"] = function()
  vim.fn.writefile({ "z" }, root .. "/z")
  vim.fn.writefile({ "a" }, root .. "/a")
  vim.cmd.GinStatus()
  MiniTest.expect.equality(vim.bo.filetype, "gin-status")
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "## No commits yet on main", "?? a", "?? z" }
  )
end
T["stage and unstage target the selected path from a subdirectory"] = function()
  vim.fn.mkdir(root .. "/sub", "p")
  vim.fn.writefile({ "hello" }, root .. "/sub/space name")
  vim.cmd.cd(root .. "/sub")
  vim.cmd.GinStatus()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Plug>(gin-action-stage)", true, false, true),
    "mx",
    false
  )
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "sub/space name\n")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { 'A  "sub/space name"' })
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Plug>(gin-action-unstage)", true, false, true),
    "mx",
    false
  )
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/space name"), { "hello" })
end
T["staging supports newlines, pathspec magic and leading dashes"] = function()
  local paths = { "line\nbreak", "[literal]", "-dash" }
  for _, path in ipairs(paths) do
    vim.fn.writefile({ "content" }, root .. "/" .. path)
  end
  vim.cmd.GinStatus()
  require("gin.status").action(vim.api.nvim_get_current_buf(), "stage", { 2, 4 })
  local actual = vim.split(H.git(root, "ls-files", "-z"), "\0", { plain = true, trimempty = true })
  table.sort(paths)
  MiniTest.expect.equality(actual, paths)
end
T["unstaging the branch header leaves staged files alone"] = function()
  vim.fn.writefile({ "content" }, root .. "/file")
  H.git(root, "add", "file")
  vim.cmd.GinStatus()
  require("gin.status").action(vim.api.nvim_get_current_buf(), "unstage", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "file\n")
end
T["stage records deleted files in the index"] = function()
  vim.fn.writefile({ "content" }, root .. "/file")
  H.git(root, "add", "file")
  H.git(root, "commit", "-m", "initial")
  vim.fn.delete(root .. "/file")
  vim.cmd.GinStatus()
  require("gin.status").action(vim.api.nvim_get_current_buf(), "stage", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-status"), "D\tfile\n")
end
T["unstage restores both sides of a staged rename"] = function()
  vim.fn.writefile({ "content" }, root .. "/before")
  H.git(root, "add", "before")
  H.git(root, "commit", "-m", "initial")
  H.git(root, "mv", "before", "after")
  vim.cmd.GinStatus()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "R  before -> after" })
  require("gin.status").action(vim.api.nvim_get_current_buf(), "unstage", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/after"), { "content" })
end
T["status path filtering survives reload"] = function()
  vim.fn.writefile({ "content" }, root .. "/one")
  vim.fn.writefile({ "content" }, root .. "/two")
  vim.cmd("GinStatus -- one")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "?? one" })
end
T["visual stage mapping changes only the selected range"] = function()
  for _, path in ipairs({ "a", "b", "c" }) do
    vim.fn.writefile({ "content" }, root .. "/" .. path)
  end
  vim.cmd.GinStatus()
  vim.api.nvim_feedkeys("ggjVj<<", "mx", false)
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "a\nb\n")
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
end
T["Gin command completion refreshes the status view"] = function()
  vim.fn.writefile({ "content" }, root .. "/file")
  vim.cmd.GinStatus()
  vim.cmd("Gin ++wait add -- file")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "A  file" })
end
T["chosen status actions remain repeatable after refresh"] = function()
  for _, path in ipairs({ "one", "two" }) do
    vim.fn.writefile({ "content" }, root .. "/" .. path)
  end
  vim.cmd.GinStatus()
  local action = require("gin.action")
  local input = vim.ui.input
  vim.ui.input = function(_, callback)
    callback("stage")
  end
  local ok, err = pcall(action.call, vim.api.nvim_get_current_buf(), "choice", { 2, 2 })
  vim.ui.input = input
  assert(ok, err)
  action.call(vim.api.nvim_get_current_buf(), "repeat", { 3, 3 })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "one\ntwo\n")
end
T["edit action opens the selected working file from a subdirectory"] = function()
  vim.fn.mkdir(root .. "/sub", "p")
  vim.fn.writefile({ "working" }, root .. "/sub/file.lua")
  vim.cmd.cd(root .. "/sub")
  vim.cmd.GinStatus()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "mx", false)
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_name(0),
    vim.uv.fs_realpath(root) .. "/sub/file.lua"
  )
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "working" })
end
T["cached status edit opens the selected index file in a split"] = function()
  vim.fn.mkdir(root .. "/sub", "p")
  vim.fn.writefile({ "index" }, root .. "/sub/file.lua")
  H.git(root, "add", "sub/file.lua")
  vim.fn.writefile({ "working" }, root .. "/sub/file.lua")
  vim.cmd.cd(root .. "/sub")
  vim.cmd.GinStatus()
  local status_buf = vim.api.nvim_get_current_buf()
  local windows = #vim.api.nvim_tabpage_list_wins(0)
  require("gin.action").call(status_buf, "edit:cached:split", { 2, 2 })
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), windows + 1)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "index" })
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  vim.cmd.close()
end
T["yank path uses the requested register and absolute file path"] = function()
  vim.fn.writefile({ "working" }, root .. "/file")
  vim.cmd.GinStatus()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys('"ayy', "mx", false)
  MiniTest.expect.equality(vim.fn.getreg("a"), vim.uv.fs_realpath(root) .. "/file")
end
T["restore reverts only the selected working file"] = function()
  for _, path in ipairs({ "one", "two" }) do
    vim.fn.writefile({ "base" }, root .. "/" .. path)
  end
  H.git(root, "add", ".")
  H.git(root, "commit", "-m", "initial")
  for _, path in ipairs({ "one", "two" }) do
    vim.fn.writefile({ "changed" }, root .. "/" .. path)
  end
  vim.cmd.GinStatus()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "restore", { 2, 2 })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/one"), { "base" })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/two"), { "changed" })
end
for _, variant in ipairs({ "ours", "theirs", "conflict:merge", "conflict:diff3" }) do
  T["restore " .. variant .. " uses unmerged index stages"] = function()
    local git = require("gin.git")
    local records = {}
    for stage, content in ipairs({ "base", "ours", "theirs" }) do
      local hash = vim.trim(
        git.run({ "hash-object", "-w", "--stdin" }, { cwd = root, stdin = content .. "\n" }).stdout
      )
      records[#records + 1] = "100644 " .. hash .. " " .. stage .. "\tfile\0"
    end
    git.run({ "update-index", "-z", "--index-info" }, { cwd = root, stdin = table.concat(records) })
    vim.fn.writefile({ "unresolved" }, root .. "/file")
    vim.cmd.GinStatus()
    require("gin.action").call(vim.api.nvim_get_current_buf(), "restore:" .. variant, { 2, 2 })
    local content = table.concat(vim.fn.readfile(root .. "/file"), "\n")
    if variant == "ours" or variant == "theirs" then
      MiniTest.expect.equality(content, variant)
    else
      MiniTest.expect.equality(content:find("<<<<<<<", 1, true) ~= nil, true)
      MiniTest.expect.equality(content:find("ours", 1, true) ~= nil, true)
      MiniTest.expect.equality(content:find("theirs", 1, true) ~= nil, true)
      MiniTest.expect.equality(content:find("base", 1, true) ~= nil, variant == "conflict:diff3")
    end
    MiniTest.expect.equality(
      #vim.split(H.git(root, "ls-files", "--unmerged"), "\n", { trimempty = true }),
      3
    )
  end
end
T["add intent-to-add and rm affect only the index"] = function()
  vim.fn.writefile({ "content" }, root .. "/file")
  vim.cmd.GinStatus()
  local buf = vim.api.nvim_get_current_buf()
  require("gin.action").call(buf, "add:intent-to-add", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "ls-files"), "file\n")
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "")
  require("gin.action").call(buf, "rm", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "ls-files"), "")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "content" })
end
return T
