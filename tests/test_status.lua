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
T["echo exposes pinned status fields for tracked renamed and untracked paths"] = function()
  for _, path in ipairs({ "both", "deleted", "modified", "old name", "staged" }) do
    vim.fn.writefile({ "base" }, root .. "/" .. path)
  end
  H.git(root, "add", ".")
  H.git(root, "commit", "-m", "base")
  for _, path in ipairs({ "both", "modified", "staged", "untracked" }) do
    vim.fn.writefile({ "change" }, root .. "/" .. path)
  end
  H.git(root, "add", "both", "staged")
  vim.fn.writefile({ "another change" }, root .. "/both")
  vim.fn.delete(root .. "/deleted")
  H.git(root, "mv", "old name", "new name")
  local expected = {
    { XY = "MM", path = "both" },
    { XY = ".D", path = "deleted" },
    { XY = ".M", path = "modified" },
    { XY = "R.", path = "new name", origPath = "old name" },
    { XY = "M.", path = "staged" },
    { XY = "??", path = "untracked" },
  }
  local canonical = H.git(root, "rev-parse", "--show-toplevel"):gsub("\n$", "")
  for _, entry in ipairs(expected) do
    entry.path = canonical .. "/" .. entry.path
    if entry.origPath then
      entry.origPath = canonical .. "/" .. entry.origPath
    end
  end
  local before = H.git(root, "status", "--porcelain=v1", "-z")
  vim.cmd.GinStatus()
  for _ = 1, 2 do
    for _, range in ipairs({ { 1, 7 }, { 5, 5 }, { 1, 1 } }) do
      local echo, output = vim.api.nvim_echo
      vim.api.nvim_echo = function(chunks)
        output = chunks[1][1]
      end
      local ok, err =
        pcall(require("gin.action").call, vim.api.nvim_get_current_buf(), "echo", range)
      vim.api.nvim_echo = echo
      assert(ok, err)
      local selected = range[2] == 7 and expected or range[1] == 5 and { expected[4] } or {}
      MiniTest.expect.equality(vim.json.decode(output), selected)
    end
    vim.cmd.edit()
  end
  MiniTest.expect.equality(H.git(root, "status", "--porcelain=v1", "-z"), before)
end
T["legacy status URIs retain path filters during staging and reload"] = function()
  vim.fn.mkdir(root .. "/sub", "p")
  vim.fn.writefile({ "target" }, root .. "/sub/target$")
  vim.fn.writefile({ "other" }, root .. "/other")
  vim.cmd.cd(root .. "/sub")
  local name = "ginstatus://"
    .. root
    .. ";untracked-files=no&untracked-files=all#[%22sub/target$%22]$"
  require("gin.buffer").open(name, {})
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "?? sub/target$" })
  vim.cmd.edit()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "stage", { 2, 2 })
  H.drain()
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), "sub/target$\0")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "A  sub/target$" })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/other"), { "other" })
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
  H.drain()
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
for _, name in ipairs({ "stage", "add" }) do
  T[name .. " displays filter progress before completing the index update"] = function()
    vim.fn.writefile({ "content" }, root .. "/file")
    vim.cmd.GinStatus()
    vim.fn.writefile({ "file filter=progress" }, root .. "/.git/info/attributes")
    H.git(root, "config", "filter.progress.required", "true")
    H.git(
      root,
      "config",
      "filter.progress.clean",
      [[printf 'filter waiting\n' >&2; i=0; while test ! -f .git/action-seen; do i=$((i+1)); test "$i" -lt 100 || exit 9; sleep 0.01; done; tr a-z A-Z]]
    )
    local echo, live = vim.api.nvim_echo, false
    local more, height = vim.o.more, vim.o.cmdheight
    vim.api.nvim_echo = function(chunks, history)
      if not history and chunks[1][1] == "filter waiting" then
        live = true
        vim.fn.writefile({}, root .. "/.git/action-seen")
      end
    end
    local ok, err =
      pcall(require("gin.action").call, vim.api.nvim_get_current_buf(), name, { 2, 2 })
    vim.api.nvim_echo = echo
    assert(ok, err)
    MiniTest.expect.equality(live, true)
    MiniTest.expect.equality(H.git(root, "show", ":file"), "CONTENT\n")
    MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "content" })
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { more, height })
  end
end
T["unstaging the branch header leaves staged files alone"] = function()
  vim.fn.writefile({ "content" }, root .. "/file")
  H.git(root, "add", "file")
  vim.cmd.GinStatus()
  require("gin.status").action(vim.api.nvim_get_current_buf(), "unstage", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "file\n")
end
T["staging under eventignore all does not publish a delayed completion"] = function()
  vim.fn.writefile({ "first" }, root .. "/file")
  vim.cmd.GinStatus()
  H.drain()
  local events = 0
  local autocmd = vim.api.nvim_create_autocmd("User", {
    pattern = "GinCommandPost",
    callback = function()
      events = events + 1
    end,
  })
  local ignored = vim.o.eventignore
  local ok, err = pcall(function()
    vim.o.eventignore = "all"
    require("gin.action").call(vim.api.nvim_get_current_buf(), "stage", { 2, 2 })
    vim.o.eventignore = ignored
    H.drain()
    MiniTest.expect.equality(events, 0)
    MiniTest.expect.equality(H.git(root, "show", ":file"), "first\n")
    vim.fn.writefile({ "second" }, root .. "/file")
    require("gin.action").call(vim.api.nvim_get_current_buf(), "stage", { 2, 2 })
    H.drain()
    MiniTest.expect.equality(events, 1)
    MiniTest.expect.equality(H.git(root, "show", ":file"), "second\n")
  end)
  vim.o.eventignore = ignored
  vim.api.nvim_del_autocmd(autocmd)
  assert(ok, err)
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
T["reset targets only the selected destination of a staged rename"] = function()
  vim.fn.writefile({ "content" }, root .. "/before")
  H.git(root, "add", "before")
  H.git(root, "commit", "-m", "initial")
  H.git(root, "mv", "before", "after")
  vim.cmd.GinStatus()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "reset", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-status"), "D\tbefore\n")
  MiniTest.expect.equality(H.git(root, "ls-files", "--others", "--exclude-standard"), "after\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/after"), { "content" })
  MiniTest.expect.equality(vim.fn.filereadable(root .. "/before"), 0)
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
  H.drain()
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
  vim.cmd("GinStatus --untracked-files=all")
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "mx", false)
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_name(0),
    vim.uv.fs_realpath(root) .. "/sub/file.lua"
  )
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "working" })
end
T["revision edit actions honor persistent decoding arguments"] = function()
  vim.fn.writefile({ "caf" .. string.char(233) }, root .. "/%encoded")
  H.git(root, "add", ".")
  H.git(root, "commit", "-m", "initial")
  vim.fn.writefile({ "changed" }, root .. "/%encoded")
  vim.cmd.GinStatus()
  local status = vim.api.nvim_get_current_buf()
  local previous = vim.g.gin_edit_persistent_args
  vim.g.gin_edit_persistent_args = { "++enc=latin1", "++opener=vsplit" }
  local windows = #vim.api.nvim_tabpage_list_wins(0)
  local ok, err = pcall(function()
    MiniTest.expect.error(function()
      require("gin.action").call(status, "edit:cached", { 2, 2 })
    end, "Duplicate Gin option: %+%+opener")
    vim.g.gin_edit_persistent_args = { "++enc=latin1", "++worktree=" .. root }
    for _, source in ipairs({ "cached", "HEAD" }) do
      require("gin.action").call(status, "edit:" .. source, { 2, 2 })
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "café" })
      MiniTest.expect.equality(vim.bo.fileencoding, "latin1")
      MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), windows)
    end
  end)
  vim.g.gin_edit_persistent_args = previous
  assert(ok, err)
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
T["original path yank preserves empty rows alongside renamed paths"] = function()
  for _, path in ipairs({ "old name", "unchanged" }) do
    vim.fn.writefile({ path }, root .. "/" .. path)
  end
  H.git(root, "add", ".")
  H.git(root, "commit", "-m", "initial")
  H.git(root, "mv", "old name", "new name")
  vim.fn.writefile({ "working" }, root .. "/unchanged")
  vim.cmd.GinStatus()
  local buf = vim.api.nvim_get_current_buf()
  local before = H.git(root, "status", "--porcelain=v1", "-z")
  require("gin.action").call(buf, "yank:path:orig", { 2, 3 })
  MiniTest.expect.equality(vim.fn.getreg('"'), vim.uv.fs_realpath(root) .. "/old name\n")
  require("gin.action").call(buf, "yank:path:orig", { 3, 3 })
  MiniTest.expect.equality(vim.fn.getreg('"'), "")
  MiniTest.expect.equality(H.git(root, "status", "--porcelain=v1", "-z"), before)
end
T["forced removal drops only the selected index entry and preserves working files"] = function()
  for _, path in ipairs({ "one", "two" }) do
    vim.fn.writefile({ "base" }, root .. "/" .. path)
  end
  H.git(root, "add", ".")
  H.git(root, "commit", "-m", "initial")
  for _, path in ipairs({ "one", "two" }) do
    vim.fn.writefile({ "staged" }, root .. "/" .. path)
  end
  H.git(root, "add", ".")
  for _, path in ipairs({ "one", "two" }) do
    vim.fn.writefile({ "working" }, root .. "/" .. path)
  end
  vim.cmd.GinStatus()
  local buf = vim.api.nvim_get_current_buf()
  MiniTest.expect.error(function()
    require("gin.action").call(buf, "rm", { 2, 2 })
  end, "git exited")
  H.drain()
  MiniTest.expect.equality(H.git(root, "ls-files"), "one\ntwo\n")
  MiniTest.expect.equality(H.git(root, "show", ":one"), "staged\n")
  require("gin.action").call(buf, "rm:force", { 2, 2 })
  H.drain()
  MiniTest.expect.equality(H.git(root, "ls-files"), "two\n")
  MiniTest.expect.equality(H.git(root, "show", ":two"), "staged\n")
  for _, path in ipairs({ "one", "two" }) do
    MiniTest.expect.equality(vim.fn.readfile(root .. "/" .. path), { "working" })
    MiniTest.expect.equality(H.git(root, "show", "HEAD:" .. path), "base\n")
  end
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
T["stash saves only selected paths and ignores an empty selection"] = function()
  H.git(root, "config", "user.name", "Gin Test")
  H.git(root, "config", "user.email", "gin@example.invalid")
  for _, path in ipairs({ "one", "two" }) do
    vim.fn.writefile({ "base" }, root .. "/" .. path)
  end
  H.git(root, "add", ".")
  H.git(root, "commit", "-m", "initial")
  for _, path in ipairs({ "one", "two" }) do
    vim.fn.writefile({ "changed" }, root .. "/" .. path)
  end
  vim.cmd.GinStatus()
  local buf = vim.api.nvim_get_current_buf()
  require("gin.action").call(buf, "stash", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "stash", "list"), "")
  require("gin.action").call(buf, "stash", { 2, 2 })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/one"), { "base" })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/two"), { "changed" })
  MiniTest.expect.equality(H.git(root, "show", "stash:one"), "changed\n")
end
T["intent-to-add stage and unstage retain new-file entries"] = function()
  vim.fn.writefile({ "content" }, root .. "/file")
  vim.cmd.GinStatus()
  local buf = vim.api.nvim_get_current_buf()
  local action = require("gin.action")
  action.call(buf, "stage:intent-to-add", { 2, 2 })
  H.drain()
  MiniTest.expect.equality(H.git(root, "ls-files"), "file\n")
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "")
  action.call(buf, "stage", { 2, 2 })
  H.drain()
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "file\n")
  action.call(buf, "unstage:intent-to-add", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "ls-files"), "file\n")
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "")
end
T["intent-to-add registers new files before a later staging failure"] = function()
  vim.fn.writefile({ "base" }, root .. "/tracked")
  H.git(root, "add", "tracked")
  H.git(root, "commit", "-m", "initial")
  vim.fn.writefile({ "changed" }, root .. "/tracked")
  vim.fn.writefile({ "new content" }, root .. "/new-file")
  vim.fn.writefile({ "tracked filter=reject" }, root .. "/.git/info/attributes")
  H.git(root, "config", "filter.reject.clean", "false")
  H.git(root, "config", "filter.reject.required", "true")
  vim.cmd.GinStatus()
  MiniTest.expect.error(function()
    require("gin.action").call(vim.api.nvim_get_current_buf(), "stage:intent-to-add", { 1, 999 })
  end, "git exited")
  MiniTest.expect.equality(H.git(root, "ls-files", "--", "new-file"), "new-file\n")
  MiniTest.expect.equality(H.git(root, "show", ":new-file"), "")
  MiniTest.expect.equality(H.git(root, "show", ":tracked"), "base\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/new-file"), { "new content" })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/tracked"), { "changed" })
  H.drain()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, 2, false), { " A new-file" })
end
T["stash keep-index preserves selected staged content"] = function()
  H.git(root, "config", "user.name", "Gin Test")
  H.git(root, "config", "user.email", "gin@example.invalid")
  vim.fn.writefile({ "base" }, root .. "/file")
  H.git(root, "add", ".")
  H.git(root, "commit", "-m", "initial")
  vim.fn.writefile({ "staged" }, root .. "/file")
  H.git(root, "add", ".")
  vim.fn.writefile({ "working" }, root .. "/file")
  vim.cmd.GinStatus()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "stash:keep-index", { 2, 2 })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "staged" })
  MiniTest.expect.equality(H.git(root, "show", ":file"), "staged\n")
  MiniTest.expect.equality(H.git(root, "show", "stash:file"), "working\n")
end
T["restore staged leaves the working file untouched"] = function()
  vim.fn.writefile({ "base" }, root .. "/file")
  H.git(root, "add", ".")
  H.git(root, "commit", "-m", "initial")
  vim.fn.writefile({ "staged" }, root .. "/file")
  H.git(root, "add", ".")
  vim.fn.writefile({ "working" }, root .. "/file")
  vim.cmd.GinStatus()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "restore:staged", { 2, 2 })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "working" })
  MiniTest.expect.equality(H.git(root, "show", ":file"), "base\n")
end

T["status decoding preserves raw staging paths across reload"] = function()
  local filename = "café"
  vim.fn.writefile({ "content" }, root .. "/" .. filename)
  vim.cmd("GinStatus ++enc=latin1 ++ff=unix")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, 2, false), { "?? cafÃ©" })
  MiniTest.expect.equality(vim.bo.fileencoding, "latin1")
  MiniTest.expect.equality(vim.bo.fileformat, "unix")
  MiniTest.expect.equality(vim.b.gin_status_entries[1].path, filename)
  require("gin.action").call(vim.api.nvim_get_current_buf(), "stage", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), filename .. "\0")
  MiniTest.expect.equality(H.git(root, "show", ":" .. filename), "content\n")
end
T["invalid default arguments fail even when explicit arguments are supplied"] = function()
  local previous = vim.g.gin_status_default_args
  vim.g.gin_status_default_args = "--short"
  local buf = vim.api.nvim_get_current_buf()
  local ok, err = pcall(vim.cmd, "GinStatus --untracked-files=all")
  vim.g.gin_status_default_args = previous
  MiniTest.expect.equality(ok, false)
  MiniTest.expect.equality(tostring(err):find("g:gin_status_default_args", 1, true) ~= nil, true)
  MiniTest.expect.equality(vim.api.nvim_get_current_buf(), buf)
end
for _, case in ipairs({
  { name = "boolean", value = false },
  { name = "dictionary", value = vim.empty_dict() },
  { name = "non-string element", value = { 1 } },
}) do
  T["persistent arguments reject a " .. case.name] = function()
    local previous = vim.g.gin_status_persistent_args
    vim.g.gin_status_persistent_args = case.value
    local buf = vim.api.nvim_get_current_buf()
    local ok, err = pcall(vim.cmd, "GinStatus")
    vim.g.gin_status_persistent_args = previous
    MiniTest.expect.equality(ok, false)
    MiniTest.expect.equality(
      tostring(err):find("g:gin_status_persistent_args", 1, true) ~= nil,
      true
    )
    MiniTest.expect.equality(vim.api.nvim_get_current_buf(), buf)
  end
end
T["configured arguments preserve worktree selection and explicit precedence"] = function()
  vim.fn.writefile({ "content" }, root .. "/untracked")
  local defaults, persistent = vim.g.gin_status_default_args, vim.g.gin_status_persistent_args
  local configured = { "++worktree=" .. root }
  vim.g.gin_status_default_args = { "--untracked-files=no" }
  vim.g.gin_status_persistent_args = configured
  vim.cmd.cd(vim.fn.fnamemodify(root, ":h"))
  local ok, err = pcall(function()
    vim.cmd.GinStatus()
    MiniTest.expect.equality(vim.api.nvim_buf_line_count(0), 1)
    vim.cmd("GinStatus --untracked-files=all")
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "?? untracked" })
    MiniTest.expect.equality(vim.g.gin_status_default_args, { "--untracked-files=no" })
    MiniTest.expect.equality(vim.g.gin_status_persistent_args, configured)
  end)
  vim.g.gin_status_default_args, vim.g.gin_status_persistent_args = defaults, persistent
  assert(ok, err)
end
T["status refresh preserves cursor positions in every window showing the view"] = function()
  for _, name in ipairs({ "a", "b", "c" }) do
    vim.fn.writefile({ name }, root .. "/" .. name)
  end
  vim.cmd.GinStatus()
  local first = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(first, { 2, 1 })
  vim.cmd.split()
  local second = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(second, { 4, 2 })
  H.git(root, "add", "a")
  vim.api.nvim_exec_autocmds("User", { pattern = "GinCommandPost" })
  H.drain()
  MiniTest.expect.equality(vim.api.nvim_win_get_cursor(first), { 2, 1 })
  MiniTest.expect.equality(vim.api.nvim_win_get_cursor(second), { 4, 2 })
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, 2, false), { "A  a" })
  vim.cmd.close()
end
T["status quotes control bytes without changing the staged path"] = function()
  H.git(root, "config", "color.status", "always")
  local path = "escape" .. string.char(27) .. "[31mname"
  vim.fn.writefile({ "literal" }, root .. "/" .. path)
  vim.cmd.GinStatus()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, 2, false), {
    [[?? "escape\u001b[31mname"]],
  })
  require("gin.action").call(vim.api.nvim_get_current_buf(), "stage", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), path .. "\0")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/" .. path), { "literal" })
end
T["status actions preserve paths when Git forces status colors"] = function()
  H.git(root, "config", "color.status", "always")
  H.git(root, "config", "color.status.untracked", "blue bold")
  vim.fn.writefile({ "literal" }, root .. "/file")
  vim.cmd.GinStatus()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, 2, false), { "?? file" })
  local marks = vim.api.nvim_buf_get_extmarks(
    0,
    vim.api.nvim_create_namespace("gin_ansi"),
    { 1, 0 },
    { 1, -1 },
    { details = true }
  )
  MiniTest.expect.equality(marks[1][4].hl_group, "GinColorF4Bold")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "stage", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "show", ":file"), "literal\n")
  H.drain()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, 2, false), { "A  file" })
end
T["status enables display colors without changing repository configuration"] = function()
  H.git(root, "config", "color.status", "never")
  H.git(root, "config", "color.status.untracked", "magenta")
  vim.fn.writefile({ "text" }, root .. "/file")
  vim.cmd.GinStatus()
  for _ = 1, 2 do
    local marks = vim.api.nvim_buf_get_extmarks(
      0,
      vim.api.nvim_create_namespace("gin_ansi"),
      { 1, 0 },
      { 1, -1 },
      { details = true }
    )
    MiniTest.expect.equality(#marks, 1)
    MiniTest.expect.equality(marks[1][4].hl_group, "GinColorF5")
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, 2, false), { "?? file" })
    MiniTest.expect.equality(H.git(root, "config", "color.status"), "never\n")
    vim.cmd.edit()
  end
end
T["status URIs without visibility flags honor Git configuration"] = function()
  vim.fn.mkdir(root .. "/new", "p")
  vim.fn.writefile({ "content" }, root .. "/new/file")
  require("gin.buffer").open(require("gin.uri").format("ginstatus", root, {}), {})
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "?? new/" })
  H.git(root, "config", "status.showUntrackedFiles", "no")
  vim.cmd.edit()
  MiniTest.expect.equality(#vim.b.gin_status_entries, 0)
end
T["status command defaults to all untracked files with explicit overrides"] = function()
  vim.fn.mkdir(root .. "/new", "p")
  vim.fn.writefile({ "content" }, root .. "/new/file")
  vim.cmd.GinStatus()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "?? new/file" })
  H.git(root, "config", "status.showUntrackedFiles", "no")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "?? new/file" })
  vim.cmd("GinStatus --untracked-files=no")
  MiniTest.expect.equality(#vim.b.gin_status_entries, 0)
  vim.cmd("GinStatus --untracked-files=normal")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "?? new/" })
  vim.cmd("GinStatus --untracked-files=all")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "?? new/file" })
  require("gin.action").call(vim.api.nvim_get_current_buf(), "stage", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "show", ":new/file"), "content\n")
end
T["status preserves upstream flag grouping through URI reload"] = function()
  vim.fn.mkdir(root .. "/new", "p")
  vim.fn.writefile({ "nested" }, root .. "/new/file")
  for _, case in ipairs({
    { "-uno --untracked-files=all", {} },
    { "-unormal --untracked-files=no -uall", { "?? new/file" } },
    { "--untracked-files=all -uno --untracked-files=normal", {} },
    { "-uall --untracked-files=no -unormal", { "?? new/" } },
  }) do
    vim.cmd("GinStatus " .. case[1])
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), case[2])
    vim.cmd.edit()
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), case[2])
  end
  -- Git must see earlier repeated values too, including an invalid one.
  MiniTest.expect.error(function()
    vim.cmd("GinStatus --renames=invalid --renames")
  end, "takes no value")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/new/file"), { "nested" })
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), "")
end
T["status distinguishes flag prefixes from literal dash paths"] = function()
  for _, path in ipairs({ "-", "-!", "file" }) do
    vim.fn.writefile({ "content" }, root .. "/" .. path)
  end
  for _, case in ipairs({
    { "-", { "?? -" } },
    { "-!", { "?? -!" } },
    { "--untracked-files!ignored=no", { "?? -", "?? -!", "?? file" } },
    { "--untracked-files=all\nignored", { "?? -", "?? -!", "?? file" } },
  }) do
    require("gin.status").command({ fargs = { case[1] } })
    for _ = 1, 2 do
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), case[2])
      vim.cmd.edit()
    end
  end
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), "")
end
T["short untracked flags survive reload and stop at the path separator"] = function()
  vim.fn.mkdir(root .. "/new", "p")
  vim.fn.writefile({ "nested" }, root .. "/new/file")
  vim.fn.writefile({ "literal" }, root .. "/-uall")
  for _, case in ipairs({
    { "-uno", {} },
    { "-unormal", { "?? -uall", "?? new/" } },
    { "-uall", { "?? -uall", "?? new/file" } },
    { "-u", { "?? -uall", "?? new/file" } },
    { "-- -uall", { "?? -uall" } },
  }) do
    vim.cmd("GinStatus " .. case[1])
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), case[2])
    vim.cmd.edit()
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), case[2])
  end
  require("gin.action").call(vim.api.nvim_get_current_buf(), "stage", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), "-uall\0")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/new/file"), { "nested" })
end
return T
