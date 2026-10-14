local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.mkdir(root .. "/sub", "p")
      vim.fn.writefile({ "committed" }, root .. "/sub/file.lua")
      H.git(root, "add", "sub/file.lua")
      H.git(root, "commit", "-m", "initial")
      vim.fn.writefile({ "index" }, root .. "/sub/file.lua")
      H.git(root, "add", "sub/file.lua")
      vim.fn.writefile({ "working" }, root .. "/sub/file.lua")
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
T["GinEdit reads an immutable revision using repository-relative paths"] = function()
  vim.cmd("GinEdit HEAD sub/file.lua")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "committed" })
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.bo.buftype, "nowrite")
  MiniTest.expect.equality(vim.bo.filetype, "lua")
end
T["GinEdit reads pinned upstream buffer names"] = function()
  local name = "ginedit://" .. root .. ";commitish=HEAD#sub/file.lua"
  require("gin.buffer").open(name, {})
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "committed" })
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.bo.filetype, "lua")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "committed" })
end
T["legacy index URIs preserve escaped roots and literal fragment characters"] = function()
  local original = root
  vim.cmd.cd(old_cwd)
  root = root .. " ;%#日本語"
  assert(vim.uv.fs_rename(original, root))
  local path = 'sub/space + # "日本語$'
  vim.fn.writefile({ "index" }, root .. "/" .. path)
  H.git(root, "add", "--", path)
  vim.fn.writefile({ "working" }, root .. "/" .. path)
  local name = "ginedit://" .. original .. " %3B%25%23日本語;#sub/space + # %22日本語$"
  require("gin.buffer").open(name, {})
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "index" })
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  MiniTest.expect.equality(require("gin.util").expand("%"), root .. "/" .. path)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "edited" })
  vim.cmd.write()
  MiniTest.expect.equality(H.git(root, "show", ":" .. path), "edited\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/" .. path), { "working" })
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "edited" })
end
T["writing GinEdit changes only the index from a subdirectory"] = function()
  vim.cmd("GinEdit sub/file.lua")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "index" })
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "edited index" })
  vim.cmd.write()
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "edited index\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "working" })
  MiniTest.expect.equality(vim.bo.modified, false)
end
for _, suppress in ipairs({ false, true }) do
  T["index write completion suppression=" .. tostring(suppress)] = function()
    vim.cmd("GinEdit sub/file.lua")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "edited index" })
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
      vim.o.eventignore = suppress and "all" or ""
      -- Call the handler directly: eventignore=all also suppresses BufWriteCmd.
      require("gin.edit").write(vim.api.nvim_get_current_buf(), vim.api.nvim_buf_get_name(0))
      vim.o.eventignore = ignored
      H.drain()
      MiniTest.expect.equality(events, suppress and 0 or 1)
      MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "edited index\n")
      MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "working" })
      MiniTest.expect.equality(vim.bo.modified, false)
    end)
    vim.o.eventignore = ignored
    vim.api.nvim_del_autocmd(autocmd)
    assert(ok, err)
  end
end
T["index writes preserve executable mode when the working file is missing"] = function()
  H.git(root, "update-index", "--chmod=+x", "sub/file.lua")
  vim.cmd("GinEdit sub/file.lua")
  vim.fn.delete(root .. "/sub/file.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "executable" })
  vim.cmd.write()
  MiniTest.expect.equality(H.git(root, "ls-files", "--stage", "sub/file.lua"):sub(1, 6), "100755")
  MiniTest.expect.equality(vim.uv.fs_stat(root .. "/sub/file.lua"), nil)
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "executable\n")
end
T["failed index writes keep edits marked modified and preserve both files"] = function()
  vim.cmd("GinEdit sub/file.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
  vim.fn.writefile({ "locked" }, root .. "/.git/index.lock")
  MiniTest.expect.error(function()
    vim.cmd.write()
  end, "git exited")
  MiniTest.expect.equality(vim.bo.modified, true)
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "index\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "working" })
end
T["successful index writes still notify when a post-write hook fails"] = function()
  vim.cmd("GinEdit sub/file.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "saved index" })
  H.drain()
  local events = 0
  local completion = vim.api.nvim_create_autocmd("User", {
    pattern = "GinCommandPost",
    callback = function()
      events = events + 1
    end,
  })
  local hook = vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = 0,
    command = "throw 'post-write hook failed'",
  })
  local ok, err = pcall(vim.cmd.write)
  vim.api.nvim_del_autocmd(hook)
  local drained, drain_error = pcall(H.drain)
  vim.api.nvim_del_autocmd(completion)
  assert(drained, drain_error)
  MiniTest.expect.equality(ok, false)
  MiniTest.expect.equality(tostring(err):find("post-write hook failed", 1, true) ~= nil, true)
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "saved index\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "working" })
  MiniTest.expect.equality(vim.bo.modified, false)
  MiniTest.expect.equality(events, 1)
end
T["index writes honor clean filters for the repository path"] = function()
  vim.fn.writefile({ "sub/file.lua filter=upper" }, root .. "/.gitattributes")
  H.git(root, "config", "filter.upper.clean", "tr a-z A-Z")
  vim.cmd("GinEdit sub/file.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "filtered" })
  vim.cmd.write()
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "FILTERED\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "working" })
end
T["BOM and CRLF survive an index write"] = function()
  local bytes = "\239\187\191first\r\nsecond\r\n"
  local file = assert(io.open(root .. "/sub/file.lua", "wb"))
  file:write(bytes)
  file:close()
  H.git(root, "add", "sub/file.lua")
  vim.cmd("GinEdit sub/file.lua")
  MiniTest.expect.equality(vim.bo.bomb, true)
  MiniTest.expect.equality(vim.bo.fileformat, "dos")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "first", "second" })
  vim.cmd.write()
  MiniTest.expect.equality(
    require("gin.git").run({ "show", ":sub/file.lua" }, { cwd = root }).stdout,
    bytes
  )
end
T["index writes display live filter progress without echoing blobs or hashes"] = function()
  vim.fn.writefile({ "sub/file.lua filter=progress" }, root .. "/.gitattributes")
  H.git(root, "config", "filter.progress.required", "true")
  H.git(
    root,
    "config",
    "filter.progress.clean",
    [[printf '\033[32mfilter waiting\033[m\n' >&2; i=0; while test ! -f .git/filter-seen; do i=$((i+1)); test "$i" -lt 100 || exit 9; sleep 0.01; done; tr a-z A-Z]]
  )
  vim.cmd("GinEdit sub/file.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "filtered" })
  local echo, output = vim.api.nvim_echo, {}
  local more, height = vim.o.more, vim.o.cmdheight
  vim.api.nvim_echo = function(chunks)
    output[#output + 1] = chunks[1][1]
    if chunks[1][1] == "filter waiting" then
      vim.fn.writefile({}, root .. "/.git/filter-seen")
    end
  end
  local ok, err = pcall(vim.cmd.write)
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(output, { "filter waiting" })
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "FILTERED\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "working" })
  MiniTest.expect.equality(vim.bo.modified, false)
  MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { more, height })
end
T["noeol content survives a write with fixendofline disabled"] = function()
  vim.fn.writefile({ "no newline" }, root .. "/sub/file.lua", "b")
  H.git(root, "add", "sub/file.lua")
  vim.cmd("GinEdit sub/file.lua")
  MiniTest.expect.equality(vim.bo.endofline, false)
  vim.bo.fixendofline = false
  vim.cmd.write()
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "no newline")
end
T["writing an empty index buffer keeps the blob empty"] = function()
  vim.fn.writefile({}, root .. "/sub/file.lua")
  H.git(root, "add", "sub/file.lua")
  vim.cmd("GinEdit sub/file.lua")
  vim.cmd.write()
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "")
end
T["read inserts a revision at the requested line"] = function()
  vim.cmd("GinEdit HEAD sub/file.lua")
  local name = vim.api.nvim_buf_get_name(0)
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "last" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_cmd({ cmd = "read", range = { 1 }, args = { vim.fn.fnameescape(name) } }, {})
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "first", "committed", "last" }
  )
  MiniTest.expect.equality(vim.bo.buftype, "")
end
T["reading an empty index blob emits FileReadPost without changing text"] = function()
  vim.fn.writefile({}, root .. "/sub/empty")
  H.git(root, "add", "sub/empty")
  local name = require("gin.uri").format("ginedit", root, {}, "sub/empty")
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
  vim.bo.modified = false
  local events = {}
  local id = vim.api.nvim_create_autocmd("FileReadPost", {
    pattern = "ginedit://*",
    callback = function(event)
      events[#events + 1] = { event.match, vim.api.nvim_buf_get_lines(0, 0, -1, false) }
    end,
  })
  local ok, err = pcall(vim.cmd, "1read " .. vim.fn.fnameescape(name))
  local missing = require("gin.uri").format("ginedit", root, {}, "sub/missing")
  local failed = not pcall(vim.cmd, "1read " .. vim.fn.fnameescape(missing))
  vim.api.nvim_del_autocmd(id)
  assert(ok, err)
  MiniTest.expect.equality(failed, true)
  MiniTest.expect.equality(events, { { name, { "before", "after" } } })
  MiniTest.expect.equality(vim.bo.modified, false)
end
T["read into an empty buffer does not add a blank line"] = function()
  vim.cmd("GinEdit HEAD sub/file.lua")
  local name = vim.api.nvim_buf_get_name(0)
  vim.cmd.enew()
  vim.api.nvim_cmd({ cmd = "read", args = { vim.fn.fnameescape(name) } }, {})
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "committed" })
end
T["Gin filename expansion resolves the path of a revision buffer"] = function()
  vim.cmd("GinEdit HEAD sub/file.lua")
  vim.cmd("Gin ++wait add -- %:p")
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "working\n")
end
T["reading GinEdit honors explicit decoding without changing destination options"] = function()
  vim.fn.writefile({ "\27[31mcafé\27[m\r" }, root .. "/sub/encoded")
  H.git(root, "add", "sub/encoded")
  local name =
    require("gin.uri").format("ginedit", root, { enc = "latin1", ff = "dos" }, "sub/encoded")
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
  vim.bo.fileencoding, vim.bo.fileformat = "latin1", "dos"
  vim.cmd("1read ++encoding=utf-8 ++fileformat=unix " .. vim.fn.fnameescape(name))
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
    "before",
    "\27[31mcafé\27[m\r",
    "after",
  })
  MiniTest.expect.equality({ vim.bo.fileencoding, vim.bo.fileformat }, { "latin1", "dos" })
  MiniTest.expect.equality({ vim.fn.line("'["), vim.fn.line("']") }, { 2, 2 })
  MiniTest.expect.equality(vim.bo.modified, true)
end
for _, command in ipairs({ "edit", "read" }) do
  T[command .. " of Git blobs displays stderr without echoing file contents"] = function()
    local name = require("gin.uri").format("ginedit", root, { commitish = "HEAD" }, "sub/file.lua")
    local trace, echo = vim.env.GIT_TRACE, vim.api.nvim_echo
    local more, height = vim.o.more, vim.o.cmdheight
    local output = {}
    vim.env.GIT_TRACE = "1"
    vim.api.nvim_echo = function(chunks)
      output[#output + 1] = chunks[1][1]
    end
    local ok, err = pcall(vim.api.nvim_cmd, {
      cmd = command,
      args = { vim.fn.fnameescape(name) },
    }, {})
    vim.env.GIT_TRACE, vim.api.nvim_echo = trace, echo
    assert(ok, err)
    local progress = table.concat(output, "\n")
    MiniTest.expect.equality(
      progress:find("built-in: git show HEAD:sub/file.lua", 1, true) ~= nil,
      true
    )
    MiniTest.expect.equality(progress:find("committed", 1, true), nil)
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "committed" })
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { more, height })
  end
end
for _, format in ipairs({ "auto", "unix", "dos" }) do
  T["mixed line endings match native reads with " .. format .. " format"] = function()
    vim.fn.writefile({ "one\r", "two", "three\r", "" }, root .. "/mixed", "b")
    H.git(root, "add", "mixed")
    local option = format == "auto" and "" or "++ff=" .. format .. " "
    vim.cmd("edit " .. option .. vim.fn.fnameescape(root .. "/mixed"))
    local expected = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local expected_ff, expected_eol = vim.bo.fileformat, vim.bo.endofline
    vim.cmd("GinEdit " .. option .. "mixed")
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), expected)
    MiniTest.expect.equality(vim.bo.fileformat, expected_ff)
    MiniTest.expect.equality(vim.bo.endofline, expected_eol)
    vim.cmd.write()
    local separator = expected_ff == "dos" and "\r\n" or "\n"
    MiniTest.expect.equality(
      require("gin.git").run({ "show", ":mixed" }, { cwd = root }).stdout,
      table.concat(expected, separator) .. separator
    )
    MiniTest.expect.equality(
      vim.fn.readfile(root .. "/mixed", "b"),
      { "one\r", "two", "three\r", "" }
    )
  end
end
T["Mac format preserves embedded LF through native-compatible index reads and writes"] = function()
  local bytes = "one\ninside\rtwo\r"
  vim.fn.writefile(vim.split(bytes, "\n", { plain = true }), root .. "/mac", "b")
  H.git(root, "add", "mac")
  vim.cmd("edit ++ff=mac " .. vim.fn.fnameescape(root .. "/mac"))
  local expected = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  vim.cmd("write " .. vim.fn.fnameescape(root .. "/native-copy"))
  local native_bytes = table.concat(vim.fn.readfile(root .. "/native-copy", "b"), "\n")
  vim.cmd("GinEdit ++ff=mac mac")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), expected)
  MiniTest.expect.equality(vim.bo.fileformat, "mac")
  vim.cmd.write()
  MiniTest.expect.equality(
    require("gin.git").run({ "show", ":mac" }, { cwd = root }).stdout,
    native_bytes
  )
  MiniTest.expect.equality(native_bytes, bytes)
  MiniTest.expect.equality(table.concat(vim.fn.readfile(root .. "/mac", "b"), "\n"), bytes)
end
for _, directory in ipairs({ "$GIN_EDIT_LITERAL", "~" }) do
  T["index paths preserve literal " .. directory .. " directories"] = function()
    local previous = vim.env.GIN_EDIT_LITERAL
    vim.env.GIN_EDIT_LITERAL = "decoy"
    local ok, err = pcall(function()
      assert(vim.uv.fs_mkdir(root .. "/" .. directory, 448))
      assert(vim.uv.fs_mkdir(root .. "/decoy", 448))
      local path = directory .. "/file"
      vim.fn.writefile({ "literal" }, root .. "/" .. path)
      vim.fn.writefile({ "decoy" }, root .. "/decoy/file")
      H.git(root, "add", ".")
      require("gin.edit").command({ fargs = { path }, smods = {} })
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "literal" })
      MiniTest.expect.equality(vim.b.gin_path, path)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "changed index" })
      vim.cmd.write()
      MiniTest.expect.equality(H.git(root, "show", ":" .. path), "changed index\n")
      MiniTest.expect.equality(H.git(root, "show", ":decoy/file"), "decoy\n")
      MiniTest.expect.equality(vim.fn.readfile(root .. "/" .. path), { "literal" })
    end)
    vim.env.GIN_EDIT_LITERAL = previous
    assert(ok, err)
  end
end
T["index writes preserve symlink mode and leave the working link and target untouched"] = function()
  vim.fn.writefile({ "target content" }, root .. "/target")
  assert(vim.uv.fs_symlink("target", root .. "/link"))
  vim.fn.writefile({ "link filter=uppercase" }, root .. "/.git/info/attributes")
  H.git(root, "config", "filter.uppercase.clean", "tr a-z A-Z")
  H.git(root, "config", "filter.uppercase.required", "true")
  H.git(root, "add", "target", "link")
  require("gin.edit").command({ fargs = { "link" }, smods = {} })
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "target" })
  MiniTest.expect.equality(vim.bo.endofline, false)
  vim.bo.fixendofline = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "other-target" })
  vim.cmd.write()
  MiniTest.expect.equality(
    H.git(root, "ls-files", "--stage", "--", "link"):match("^(%d+)"),
    "120000"
  )
  MiniTest.expect.equality(
    require("gin.git").run({ "show", ":link" }, { cwd = root }).stdout,
    "other-target"
  )
  MiniTest.expect.equality(vim.uv.fs_readlink(root .. "/link"), "target")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/target"), { "target content" })
end
for _, encoding in ipairs({
  "utf-8",
  "latin1",
  "utf-16le",
  "utf-16",
  "ucs-2le",
  "ucs-2",
  "ucs-4le",
  "ucs-4",
}) do
  T["bomb writes match native behavior for " .. encoding] = function()
    local content = encoding == "latin1" and "content" or "content 日本語"
    if encoding:find("utf-16", 1, true) or encoding:find("ucs-4", 1, true) then
      content = content .. "😀"
    end
    vim.fn.writefile({ content }, root .. "/bom-input")
    H.git(root, "add", "bom-input")
    vim.cmd.edit(root .. "/bom-input")
    vim.bo.fileencoding, vim.bo.bomb = encoding, true
    vim.cmd("write " .. vim.fn.fnameescape(root .. "/native-bom"))
    local native = assert(io.open(root .. "/native-bom", "rb"))
    local expected = native:read("*a")
    native:close()
    vim.cmd("GinEdit bom-input")
    vim.bo.fileencoding, vim.bo.bomb = encoding, true
    vim.cmd.write()
    MiniTest.expect.equality(
      require("gin.git").run({ "show", ":bom-input" }, { cwd = root }).stdout,
      expected
    )
    MiniTest.expect.equality(vim.fn.readfile(root .. "/bom-input", "b"), { content, "" })
    vim.cmd("GinEdit ++enc=" .. encoding .. " bom-input")
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { content })
    MiniTest.expect.equality(vim.bo.bomb, encoding ~= "latin1")
  end
end
T["UTF-16 index buffers preserve embedded NUL"] = function()
  local bytes = "\255\254a\0\0\0b\0\n\0"
  local file = assert(io.open(root .. "/nul-utf16", "wb"))
  file:write(bytes)
  file:close()
  H.git(root, "add", "nul-utf16")
  vim.cmd("GinEdit ++enc=utf-16le nul-utf16")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "a\0b" })
  vim.cmd.write()
  MiniTest.expect.equality(
    require("gin.git").run({ "show", ":nul-utf16" }, { cwd = root }).stdout,
    bytes
  )
end
T["unrepresentable UCS-2 writes preserve the index and unsaved edits"] = function()
  vim.cmd("GinEdit sub/file.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "😀" })
  vim.bo.fileencoding = "ucs-2"
  MiniTest.expect.error(function()
    vim.cmd.write()
  end, "Character cannot be encoded as UCS%-2")
  MiniTest.expect.equality(vim.bo.modified, true)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "😀" })
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "index\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "working" })
end
for _, format in ipairs({ "dos", "mac" }) do
  T["binary index writes ignore " .. format .. " format and BOM but retain encoding"] = function()
    vim.fn.writefile({ "café\rinside", "tail" }, root .. "/binary-input", "b")
    H.git(root, "add", "binary-input")
    local function binary_options()
      vim.bo.fileencoding, vim.bo.fileformat = "utf-16le", format
      vim.bo.bomb, vim.bo.binary, vim.bo.endofline = true, true, false
    end
    vim.cmd.edit(root .. "/binary-input")
    binary_options()
    vim.cmd("write " .. vim.fn.fnameescape(root .. "/native-binary"))
    local file = assert(io.open(root .. "/native-binary", "rb"))
    local expected = file:read("*a")
    file:close()
    vim.cmd("GinEdit binary-input")
    binary_options()
    vim.cmd.write()
    MiniTest.expect.equality(
      { require("gin.git").run({ "show", ":binary-input" }, { cwd = root }).stdout:byte(1, -1) },
      { expected:byte(1, -1) }
    )
    MiniTest.expect.equality(
      vim.fn.readfile(root .. "/binary-input", "b"),
      { "café\rinside", "tail" }
    )
  end
end
T["failed clean conversion retains the index working file and unsaved buffer"] = function()
  vim.cmd("GinEdit sub/file.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved conversion" })
  local before = H.git(root, "ls-files", "--stage")
  vim.fn.writefile({ "sub/file.lua filter=reject" }, root .. "/.git/info/attributes")
  H.git(root, "config", "filter.reject.clean", "false")
  H.git(root, "config", "filter.reject.required", "true")
  MiniTest.expect.error(function()
    vim.cmd.write()
  end, "git exited")
  MiniTest.expect.equality(vim.bo.modified, true)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "unsaved conversion" })
  MiniTest.expect.equality(H.git(root, "ls-files", "--stage"), before)
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "index\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "working" })
end
return T
