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
T["legacy diff URIs retain flags paths and cached jump targets"] = function()
  local name = "gindiff://"
    .. root
    .. ";cached=&U=5&U=0&diff-filter=M&diff-filter=A&src-prefix=old+path%2F&dst-prefix=new+path%2F"
    .. "#[%22sub/file%22]"
  local expected = H.git(
    root,
    "diff",
    "--no-color",
    "--cached",
    "-U5",
    "-U0",
    "--diff-filter=M",
    "--diff-filter=A",
    "--src-prefix=old path/",
    "--dst-prefix=new path/",
    "--",
    "sub/file"
  )
  require("gin.buffer").open(name, {})
  for _ = 1, 2 do
    MiniTest.expect.equality(
      table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n",
      expected
    )
    vim.cmd("normal! zM")
    MiniTest.expect.equality(vim.fn.foldtextresult(3), "[.] sub/file (+1 -1)")
    vim.cmd.edit()
  end
  vim.cmd("normal! zR")
  for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line == "+index" then
      vim.api.nvim_win_set_cursor(0, { row, 0 })
    end
  end
  require("gin.diffjump").jump("new")
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "index" })
  MiniTest.expect.equality(vim.b.gin_path, "sub/file")
end
T["legacy foldtext works in Gin views and ordinary diff buffers"] = function()
  for _, gin_view in ipairs({ true, false }) do
    if gin_view then
      vim.cmd("GinDiff -- sub/file")
    else
      vim.cmd.enew({ bang = true })
      local lines =
        vim.split(H.git(root, "diff", "--no-color", "--", "sub/file"), "\n", { trimempty = true })
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.wo.foldmethod = "manual"
      vim.api.nvim_cmd({ cmd = "fold", range = { 3, #lines } }, {})
    end
    vim.wo.foldtext = "gin#difffold#foldtext()"
    vim.cmd("normal! zM")
    MiniTest.expect.equality(vim.fn.foldtextresult(3), "[.] sub/file (+1 -1)")
  end
end
T["foldtext only extracts paths from matching diff headers"] = function()
  vim.cmd.enew({ bang = true })
  vim.wo.foldmethod = "manual"
  vim.wo.foldtext = "gin#difffold#foldtext()"
  for _, case in ipairs({
    { { "diff --git a/file b/file", "index 123..456", "-old", "+new" }, "[.]  (+1 -1)" },
    { { "not a header", "+++ b/file", "+new" }, "[/]  -> file (+1)" },
    { { "--- a/file", "not a header", "-old" }, "[/] file ->  (-1)" },
  }) do
    vim.cmd("normal! zE")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, case[1])
    vim.api.nvim_cmd({ cmd = "fold", range = { 1, #case[1] } }, {})
    vim.cmd("normal! zM")
    MiniTest.expect.equality(vim.fn.foldtextresult(1), case[2])
  end
end
T["GinDiff compares an explicit revision range"] = function()
  H.git(root, "commit", "-m", "second")
  vim.cmd("GinDiff HEAD^..HEAD -- sub/file")
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("-base\n+index", 1, true) ~= nil, true)
  MiniTest.expect.equality(content:find("working", 1, true), nil)
end
T["GinDiff retains repeated filters across reloads"] = function()
  vim.fn.writefile({ "added" }, root .. "/sub/added")
  H.git(root, "add", "sub/added")
  local expected =
    H.git(root, "diff", "--no-color", "--cached", "--diff-filter=M", "--diff-filter=A")
  MiniTest.expect.equality(expected:find("sub/file", 1, true) ~= nil, true)
  MiniTest.expect.equality(expected:find("sub/added", 1, true) ~= nil, true)
  vim.cmd("GinDiff --cached --diff-filter=M --diff-filter=A")
  for _ = 1, 2 do
    MiniTest.expect.equality(
      table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n",
      expected
    )
    vim.cmd.edit()
  end
end
T["GinDiff keeps short flag values in command order"] = function()
  vim.fn.writefile({ "before", "base", "after" }, root .. "/sub/file")
  H.git(root, "add", "sub/file")
  vim.fn.writefile({ "before", "working", "after" }, root .. "/sub/file")
  local expected = H.git(root, "diff", "--no-color", "-U5", "-U0", "--", "sub/file")
  MiniTest.expect.equality(expected:find("\n before\n", 1, true), nil)
  for _, flags in ipairs({ "-U5 -U0", "-U5 --U=0" }) do
    vim.cmd("GinDiff " .. flags .. " -- sub/file")
    for _ = 1, 2 do
      MiniTest.expect.equality(
        table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n",
        expected
      )
      vim.cmd.edit()
    end
  end
end
T["GinDiff preserves the first occurrence order of different flags"] = function()
  vim.fn.writefile({ "before", "base", "after" }, root .. "/sub/file")
  H.git(root, "add", "sub/file")
  vim.fn.writefile({ "before", "working", "after" }, root .. "/sub/file")
  for _, flags in ipairs({
    { "--unified=5", "-U0" },
    { "-U0", "--unified=5" },
  }) do
    local args = { "diff", "--no-color" }
    vim.list_extend(args, flags)
    vim.list_extend(args, { "--", "sub/file" })
    local expected = H.git(root, unpack(args))
    vim.cmd("GinDiff " .. table.concat(flags, " ") .. " -- sub/file")
    for _ = 1, 2 do
      MiniTest.expect.equality(
        table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n",
        expected
      )
      vim.cmd.edit()
    end
  end
end
T["file diff actions honor persistent flags and retain the selected path"] = function()
  vim.fn.writefile({ "base" }, root .. "/sub/%target")
  H.git(root, "add", "sub/%target")
  H.git(root, "commit", "-m", "target", "--", "sub/%target")
  vim.fn.writefile({ "index" }, root .. "/sub/%target")
  H.git(root, "add", "sub/%target")
  vim.fn.writefile({ "working" }, root .. "/sub/%target")
  vim.cmd("GinStatus -- sub/%target")
  local status = vim.api.nvim_get_current_buf()
  local previous = vim.g.gin_diff_persistent_args
  vim.g.gin_diff_persistent_args = { "--word-diff=plain", "++opener=tabedit" }
  local tabs = #vim.api.nvim_list_tabpages()
  local ok, err = pcall(function()
    MiniTest.expect.error(function()
      require("gin.action").call(status, "diff:local", { 2, 2 })
    end, "Duplicate Gin option: %+%+opener")
    vim.g.gin_diff_persistent_args = { "--word-diff=plain", "++worktree=" .. root }
    for _, source in ipairs({ "local", "cached", "HEAD", "smart" }) do
      require("gin.action").call(status, "diff:" .. source, { 2, 2 })
      local args = { "diff", "--word-diff=plain", "--no-color" }
      if source == "cached" or source == "smart" then
        args[#args + 1] = "--cached"
      elseif source == "HEAD" then
        args[#args + 1] = "HEAD"
      end
      vim.list_extend(args, { "--", "sub/%target" })
      for _ = 1, 2 do
        MiniTest.expect.equality(
          table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n",
          H.git(root, unpack(args))
        )
        vim.cmd.edit()
      end
      MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs)
    end
  end)
  vim.g.gin_diff_persistent_args = previous
  assert(ok, err)
end
T["status smart diff selects the cached changes when both sides differ"] = function()
  vim.cmd.GinStatus()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys("dd", "mx", false)
  MiniTest.expect.equality(vim.bo.filetype, "gin-diff")
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("-base\n+index", 1, true) ~= nil, true)
end
T["smart diff uses the working tree when the index is unchanged"] = function()
  H.git(root, "reset", "--quiet", "--", "sub/file")
  vim.cmd.GinStatus()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "diff:smart", { 2, 2 })
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("-base\n+working", 1, true) ~= nil, true)
end
local function jump(line, keys)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local row = assert(
    vim.tbl_contains(lines, line)
      and vim.fn.match(lines, "^" .. vim.fn.escape(line, "\\.*[]~$") .. "$") + 1
  )
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  vim.api.nvim_feedkeys(keys or "\r", "mx", false)
end
for _, mode in ipairs({
  { "Normal", "" },
  { "Visual", "v" },
  { "Select", "gh" },
  { "operator pending", "d" },
}) do
  for _, side in ipairs({ "old", "new", "smart" }) do
    T[side .. " diff Plug jumps from " .. mode[1] .. " mode"] = function()
      local status = H.git(root, "status", "--porcelain")
      vim.cmd("GinDiff -- sub/file")
      jump(
        "+working",
        vim.api.nvim_replace_termcodes(
          mode[2] .. "<Plug>(gin-diffjump-" .. side .. ")<Esc>",
          true,
          false,
          true
        )
      )
      MiniTest.expect.equality(
        vim.api.nvim_get_current_line(),
        side == "old" and "index" or "working"
      )
      MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0), { 1, 0 })
      MiniTest.expect.equality(vim.bo.modified, false)
      MiniTest.expect.equality(H.git(root, "status", "--porcelain"), status)
    end
  end
end
T["smart jump opens the working file for added lines"] = function()
  vim.cmd("GinDiff -- sub/file")
  jump("+working")
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/sub/file")
  MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0), { 1, 0 })
end
T["smart jump opens the index for removed working lines"] = function()
  vim.cmd("GinDiff -- sub/file")
  jump("-index")
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "index")
end
T["diff jumps retain internal edit defaults despite command persistent arguments"] = function()
  vim.fn.writefile({ "café" }, root .. "/sub/file")
  H.git(root, "add", "sub/file")
  vim.fn.writefile({ "working" }, root .. "/sub/file")
  vim.cmd("GinDiff -- sub/file")
  local diff = vim.api.nvim_get_current_buf()
  local tabs = #vim.api.nvim_list_tabpages()
  local previous = vim.g.gin_edit_persistent_args
  vim.g.gin_edit_persistent_args = { "++enc=latin1", "++opener=tabedit" }
  local ok, err = pcall(function()
    jump("-café")
    MiniTest.expect.equality(vim.api.nvim_get_current_line(), "café")
    MiniTest.expect.equality(vim.bo.buftype, "acwrite")
    MiniTest.expect.equality(vim.bo.fileencoding, "utf-8")
    MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs)
    vim.api.nvim_set_current_buf(diff)
    jump("+working")
    MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/sub/file")
    MiniTest.expect.equality(vim.api.nvim_get_current_line(), "working")
    MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs)
  end)
  vim.g.gin_edit_persistent_args = previous
  assert(ok, err)
end
T["cached jumps select HEAD and index respectively"] = function()
  vim.cmd("GinDiff --cached -- sub/file")
  local diff = vim.api.nvim_get_current_buf()
  jump("-base")
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "base")
  vim.api.nvim_set_current_buf(diff)
  jump("+index")
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "index")
end
T["revision jumps use the corresponding revision"] = function()
  H.git(root, "commit", "-m", "second")
  vim.cmd("GinDiff HEAD^..HEAD -- sub/file")
  jump("+index")
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "index")
end
T["jump offsets ignore removed lines and no-newline markers"] = function()
  local parse = require("gin.diffjump").parse
  local lines = {
    "--- a/file",
    "+++ b/file",
    "@@ -4,2 +4,2 @@",
    "-old",
    "\\ No newline at end of file",
    "+new",
    " context",
  }
  MiniTest.expect.equality(parse(lines, 7, "new"), { path = "file", lnum = 5 })
  MiniTest.expect.equality(parse(lines, 7, "old"), { path = "file", lnum = 5 })
  MiniTest.expect.equality(parse(lines, 3, "new"), nil)
end
T["jump decodes Git quoted paths"] = function()
  local path = "sub/tab\t日本語"
  vim.fn.writefile({ "old" }, root .. "/" .. path)
  H.git(root, "add", "--", path)
  vim.fn.writefile({ "new" }, root .. "/" .. path)
  require("gin.diff").open(vim.uv.fs_realpath(root), { paths = { path } })
  jump("+new")
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/" .. path)
end
T["three-dot old jump resolves the common ancestor"] = function()
  H.git(root, "commit", "-m", "second")
  vim.cmd("GinDiff HEAD^...HEAD -- sub/file")
  jump("-base")
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "base")
end
T["reverse diff swaps the working and index jump targets"] = function()
  vim.cmd("GinDiff -R -- sub/file")
  jump("-working")
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/sub/file")
end
T["diff folds summarize file changes and rebuild on reload"] = function()
  vim.wo.foldenable = false
  vim.cmd("GinDiff -- sub/file")
  MiniTest.expect.equality(vim.wo.foldmethod, "manual")
  MiniTest.expect.equality(vim.fn.foldlevel(3), 1)
  vim.cmd("normal! zM")
  MiniTest.expect.equality(vim.fn.foldtextresult(3), "[.] sub/file (+1 -1)")
  H.git(root, "checkout", "--", "sub/file")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.fn.foldlevel(1), 0)
end
T["fold sections distinguish file headers from removed content"] = function()
  local sections = require("gin.difffold").sections({
    "diff --git a/one b/one",
    "--- a/one",
    "+++ b/one",
    "@@ -1 +1 @@",
    "--- removed",
    "+++ added",
    "diff --git a/two b/two",
    "--- a/two",
    "+++ /dev/null",
    "@@ -1 +0,0 @@",
    "-old",
  })
  MiniTest.expect.equality(sections, { { first = 2, last = 6 }, { first = 8, last = 11 } })
end
T["reading a diff URI inserts output without configuring the destination as a diff"] = function()
  vim.cmd("GinDiff --cached -- sub/file")
  local name = vim.api.nvim_buf_get_name(0)
  local expected = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  vim.cmd.enew()
  vim.bo.filetype = "text"
  vim.api.nvim_cmd({ cmd = "read", range = { 0 }, args = { vim.fn.fnameescape(name) } }, {})
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), expected)
  MiniTest.expect.equality(vim.bo.filetype, "text")
  MiniTest.expect.equality(vim.bo.modifiable, true)
end
T["GinDiff decodes requested encoding without forwarding it as a Git flag"] = function()
  vim.fn.writefile({ "caf" .. string.char(233) }, root .. "/sub/file")
  vim.cmd("GinDiff ++encoding=latin1 -- sub/file")
  for _ = 1, 2 do
    MiniTest.expect.equality(
      vim.tbl_contains(vim.api.nvim_buf_get_lines(0, 0, -1, false), "+café"),
      true
    )
    MiniTest.expect.equality(vim.bo.fileencoding, "latin1")
    vim.cmd.edit()
  end
end
T["GinDiff processes output on initial load and reload"] = function()
  vim.cmd([[GinDiff ++processor=tr\ a-z\ A-Z --no-color -- sub/file]])
  for _ = 1, 2 do
    MiniTest.expect.equality(
      vim.tbl_contains(vim.api.nvim_buf_get_lines(0, 0, -1, false), "+WORKING"),
      true
    )
    vim.cmd.edit()
  end
end
T["GinDiff renders added-line colors and retains no-color across reload"] = function()
  vim.cmd("GinDiff -- sub/file")
  local ns = vim.api.nvim_create_namespace("gin_ansi")
  local function added_color()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
      if lines[mark[2] + 1] == "+working" then
        return vim.api.nvim_get_hl(0, { name = mark[4].hl_group, link = false }).ctermfg
      end
    end
  end
  MiniTest.expect.equality(added_color(), 2)
  vim.cmd.edit()
  MiniTest.expect.equality(added_color(), 2)
  vim.cmd("GinDiff --no-color -- sub/file")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}), {})
end

for _, disabled in ipairs({ false, true }) do
  T["diff jump mappings use their own disable option " .. tostring(disabled)] = function()
    local buffer_option, diff_option =
      vim.g.gin_buffer_disable_default_mappings, vim.g.gin_diff_disable_default_mappings
    vim.g.gin_diff_disable_default_mappings = disabled and 1 or 0
    vim.g.gin_buffer_disable_default_mappings = disabled and 0 or 1
    local ok, err = pcall(function()
      vim.cmd("GinDiff -- sub/file")
      for key, side in pairs({ ["<CR>"] = "smart", ["g<CR>"] = "old", ["<C-g><CR>"] = "new" }) do
        MiniTest.expect.equality(
          vim.fn.maparg(key, "n"),
          disabled and "" or ("<Plug>(gin-diffjump-" .. side .. ")zv")
        )
        MiniTest.expect.equality(
          type(vim.fn.maparg("<Plug>(gin-diffjump-" .. side .. ")", "n", false, true).callback),
          "function"
        )
      end
    end)
    vim.g.gin_buffer_disable_default_mappings, vim.g.gin_diff_disable_default_mappings =
      buffer_option, diff_option
    assert(ok, err)
  end
end

T["jump preserves literal backslashes before octal digits and escape letters"] = function()
  local path = "sub/literal" .. string.char(92) .. "123" .. string.char(92) .. "n日本語"
  vim.fn.writefile({ "old" }, root .. "/" .. path)
  H.git(root, "add", "--", path)
  vim.fn.writefile({ "new" }, root .. "/" .. path)
  require("gin.diff").open(vim.uv.fs_realpath(root), { paths = { path } })
  jump("+new")
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/" .. path)
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "new")
end

for _, flags in ipairs({
  "--no-prefix --default-prefix",
  "--default-prefix --no-prefix",
  "--src-prefix=old.+/ --dst-prefix=new.+/ --default-prefix",
  "--default-prefix --src-prefix=old.+/ --dst-prefix=new.+/",
  "-R --no-prefix --default-prefix",
  "--no-prefix",
  "--no-prefix --src-prefix=old.+/ --dst-prefix=new.+/",
  "--src-prefix=old.+/ --dst-prefix=new.+/ --no-prefix",
  "--src-prefix=old.+/ --no-prefix --dst-prefix=new.+/",
  "--dst-prefix=new.+/ --no-prefix --src-prefix=old.+/",
  "-R --no-prefix --src-prefix=old.+/ --dst-prefix=new.+/",
  "--src-prefix=old.+/ --dst-prefix=new.+/",
  "--src-prefix=ignored/ --src-prefix=old.+/ --dst-prefix=ignored/ --dst-prefix=new.+/",
  "-R --no-prefix",
  "-R --src-prefix=old.+/ --dst-prefix=new.+/",
}) do
  T["diff prefixes preserve real paths for folds and jumps " .. flags] = function()
    vim.fn.mkdir(root .. "/a", "p")
    vim.fn.writefile({ "old" }, root .. "/a/file")
    H.git(root, "add", "a/file")
    vim.fn.writefile({ "new" }, root .. "/a/file")
    vim.cmd("GinDiff " .. flags .. " -- a/file")
    local header
    for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if line:match("^%-%-%- ") then
        header = i
      end
    end
    assert(header)
    vim.cmd("normal! zM")
    MiniTest.expect.equality(vim.fn.foldtextresult(header), "[.] a/file (+1 -1)")
    vim.cmd("normal! zR")
    jump(flags:find("-R", 1, true) and "-new" or "+new")
    MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/a/file")
    MiniTest.expect.equality(vim.api.nvim_get_current_line(), "new")
  end
end

T["custom slash prefixes preserve deleted-file markers"] = function()
  vim.fn.delete(root .. "/sub/file")
  vim.cmd("GinDiff --src-prefix=/ --dst-prefix=/ -- sub/file")
  local header
  for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line:match("^%-%-%- ") then
      header = i
    end
  end
  assert(header)
  vim.cmd("normal! zM")
  MiniTest.expect.equality(vim.fn.foldtextresult(header), "[-] sub/file (-1)")
  vim.cmd("normal! zR")
  jump("-index")
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "index")
end
T["custom fold prefixes match pinned output for all file statuses"] = function()
  H.git(root, "reset", "--hard", "HEAD")
  local original = {}
  for i = 1, 10 do
    original[i] = "line " .. i
  end
  vim.fn.writefile(original, root .. "/sub/old")
  vim.fn.writefile({ "deleted" }, root .. "/sub/deleted")
  H.git(root, "add", "sub")
  H.git(root, "commit", "-m", "fold fixtures")
  H.git(root, "mv", "sub/old", "sub/new")
  original[1] = "renamed and modified"
  vim.fn.writefile(original, root .. "/sub/new")
  H.git(root, "rm", "sub/deleted")
  vim.fn.writefile({ "added one", "added two" }, root .. "/sub/added")
  H.git(root, "add", "sub/added")
  vim.fn.writefile({ "modified" }, root .. "/sub/file")
  vim.cmd("GinDiff HEAD --find-renames -- sub")
  vim.cmd("normal! zM")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local ranges = {}
  for line, text in ipairs(lines) do
    if text:match("^%-%-%- ") then
      ranges[#ranges + 1] = { line, vim.fn.foldclosedend(line) }
    end
  end
  MiniTest.expect.equality(#ranges, 4)
  local previous = vim.g.gin_difffold_prefixes
  local ok, err = pcall(function()
    for _, prefixes in ipairs({
      { added = "ADD", renamed = "REN" },
      require("gin.difffold").presets.nerdfont,
      { added = "", deleted = 0, modified = "M", renamed = "R" },
    }) do
      vim.g.gin_difffold_prefixes = prefixes
      local payload = vim.json.encode({ lines = lines, ranges = ranges, prefixes = prefixes })
      local script = ([=[
        local ok, err = pcall(function()
          local data = vim.json.decode(%q)
          vim.cmd.source(%q)
          vim.g.gin_difffold_prefixes = data.prefixes
          vim.api.nvim_buf_set_lines(0, 0, -1, false, data.lines)
          vim.wo.foldmethod = 'manual'
          vim.wo.foldtext = 'gin#difffold#foldtext()'
          local result = {}
          for _, range in ipairs(data.ranges) do
            vim.api.nvim_cmd({cmd = 'fold', range = range}, {})
            result[#result + 1] = vim.fn.foldtextresult(range[1])
          end
          io.stdout:write(vim.json.encode(result))
        end)
        if not ok then io.stderr:write(tostring(err)); vim.cmd('cquit 1') end
      ]=]):format(payload, old_cwd .. "/.deps/vim-gin/autoload/gin/difffold.vim")
      local reference = vim
        .system({
          vim.v.progpath,
          "--headless",
          "--clean",
          "-u",
          "NONE",
          "-i",
          "NONE",
          "-c",
          "lua " .. script,
          "-c",
          "qa!",
        }, { text = true })
        :wait(10000)
      assert(reference.code == 0, reference.stderr)
      local actual = {}
      for _, range in ipairs(ranges) do
        actual[#actual + 1] = vim.fn.foldtextresult(range[1])
      end
      MiniTest.expect.equality(actual, vim.json.decode(reference.stdout))
      MiniTest.expect.equality(actual, {
        (prefixes.added or "[+]") .. " sub/added (+2)",
        (prefixes.deleted or "[-]") .. " sub/deleted (-1)",
        (prefixes.modified or "[.]") .. " sub/file (+1 -1)",
        (prefixes.renamed or "[/]") .. " sub/old -> sub/new (+1 -1)",
      })
      MiniTest.expect.equality(vim.g.gin_difffold_prefixes, prefixes)
    end
  end)
  vim.g.gin_difffold_prefixes = previous
  assert(ok, err)
end
for name, expected in pairs({
  ascii = { added = "[+]", deleted = "[-]", modified = "[.]", renamed = "[/]" },
  nerdfont = { added = " ", deleted = " ", modified = " ", renamed = " " },
}) do
  T["published fold prefix preset " .. name] = function()
    local preset = vim.g["gin#difffold#prefixes_" .. name]
    MiniTest.expect.equality(preset, expected)
    local previous = vim.g.gin_difffold_prefixes
    local ok, err = pcall(function()
      vim.g.gin_difffold_prefixes = preset
      vim.cmd("GinDiff -- sub/file")
      vim.cmd("normal! zM")
      MiniTest.expect.equality(vim.fn.foldtextresult(3), expected.modified .. " sub/file (+1 -1)")
    end)
    vim.g.gin_difffold_prefixes = previous
    assert(ok, err)
  end
end
for _, side in ipairs({ "old", "new" }) do
  T["context jumps after an earlier hunk use the selected side " .. side] = function()
    local original = {}
    for i = 1, 30 do
      original[i] = "line " .. i
    end
    vim.fn.writefile(original, root .. "/sub/file")
    H.git(root, "add", "sub/file")
    local working = vim.deepcopy(original)
    table.insert(working, 3, "inserted")
    working[26] = "replacement"
    vim.fn.writefile(working, root .. "/sub/file")
    local before = H.git(root, "ls-files", "--stage")
    vim.cmd("GinDiff -- sub/file")
    vim.cmd("normal! zR")
    local hunks, target = 0, nil
    for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if line:match("^@@ ") then
        hunks = hunks + 1
      elseif line == " line 26" then
        target = row
      end
    end
    MiniTest.expect.equality(hunks, 2)
    assert(target)
    vim.api.nvim_win_set_cursor(0, { target, 4 })
    require("gin.diffjump").jump(side)
    MiniTest.expect.equality(vim.api.nvim_get_current_line(), "line 26")
    MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0), { side == "old" and 26 or 27, 4 })
    if side == "old" then
      MiniTest.expect.equality(vim.bo.buftype, "acwrite")
      MiniTest.expect.equality(vim.b.gin_path, "sub/file")
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), original)
    else
      MiniTest.expect.equality(
        vim.api.nvim_buf_get_name(0),
        vim.uv.fs_realpath(root) .. "/sub/file"
      )
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), working)
    end
    MiniTest.expect.equality(vim.bo.modified, false)
    MiniTest.expect.equality(H.git(root, "ls-files", "--stage"), before)
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), working)
  end
end
return T
