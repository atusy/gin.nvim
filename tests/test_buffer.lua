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
T["GinBuffer opens Git output in an immutable scratch buffer"] = function()
  vim.fn.writefile({ "hello" }, root .. "/file")
  vim.cmd("GinBuffer status --short")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "?? file" })
  MiniTest.expect.equality(vim.bo.buftype, "nofile")
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.bo.filetype, "gin-buffer")
  MiniTest.expect.equality(require("gin.worktree").current(), vim.uv.fs_realpath(root))
end
T["legacy GinBuffer URIs preserve literal backslashes and trailing dollars"] = function()
  local path = "literal\\name$"
  vim.fn.writefile({ "committed" }, root .. "/" .. path)
  H.git(root, "add", "--", path)
  H.git(root, "commit", "-m", "fixture")
  local name = "gin://" .. root .. ";monochrome=&filetype=text#show HEAD:" .. path .. "$"
  require("gin.buffer").open(name, {})
  for _ = 1, 2 do
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "committed" })
    MiniTest.expect.equality(vim.bo.filetype, "text")
    MiniTest.expect.equality(vim.bo.modifiable, false)
    vim.cmd.edit()
  end
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
  vim.bo.filetype = "lua"
  vim.api.nvim_cmd({ cmd = "read", args = { name }, range = { 1 }, magic = { file = false } }, {})
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "before", "committed", "after" }
  )
  MiniTest.expect.equality(vim.bo.filetype, "lua")
  MiniTest.expect.equality(vim.bo.modifiable, true)
end
T["GinBuffer displays stderr before Git finishes without echoing stdout"] = function()
  H.git(
    root,
    "config",
    "alias.buffer-progress",
    [[!printf 'buffer-only\n'; printf '\033[31mwaiting\033[0m\n' >&2; i=0; while test ! -f .git/progress-seen; do i=$((i+1)); test "$i" -lt 100 || exit 9; sleep 0.01; done]]
  )
  local echo, output = vim.api.nvim_echo, {}
  local more, height = vim.o.more, vim.o.cmdheight
  vim.api.nvim_echo = function(chunks)
    output[#output + 1] = chunks[1][1]
    if chunks[1][1] == "waiting" then
      vim.fn.writefile({}, root .. "/.git/progress-seen")
    end
  end
  local ok, err = pcall(vim.cmd, "GinBuffer buffer-progress")
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(output, { "waiting" })
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "buffer-only" })
  MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { more, height })
end
T["GinBuffer reload preserves special arguments"] = function()
  vim.fn.writefile({ "hello" }, root .. "/space # name")
  vim.cmd([[GinBuffer ls-files --others -- space\ #\ name]])
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "space # name" })
  vim.cmd("edit")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "space # name" })
end
T["GinBuffer empty diffjump selects HEAD and its parent"] = function()
  vim.fn.writefile({ "before" }, root .. "/file")
  H.git(root, "add", ".")
  H.git(root, "commit", "-m", "before")
  vim.fn.writefile({ "after" }, root .. "/file")
  H.git(root, "commit", "-am", "after")
  for _, option in ipairs({ "++diffjump", "++diffjump=" }) do
    for _, case in ipairs({
      { "new", "+after", "after", "HEAD" },
      { "old", "-before", "before", "HEAD^" },
    }) do
      vim.cmd("GinBuffer " .. option .. " show HEAD")
      vim.cmd.edit()
      local parsed = require("gin.uri").parse(vim.api.nvim_buf_get_name(0))
      MiniTest.expect.equality(parsed.params.diffjump, "")
      local row
      for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        if line == case[2] then
          row = i
        end
      end
      assert(row)
      vim.api.nvim_win_set_cursor(0, { row, 0 })
      require("gin.diffjump").jump(case[1])
      MiniTest.expect.equality(vim.api.nvim_get_current_line(), case[3])
      MiniTest.expect.equality(vim.bo.modifiable, false)
      MiniTest.expect.equality(
        require("gin.uri").parse(vim.api.nvim_buf_get_name(0)).params.commitish,
        case[4]
      )
    end
  end
end
T["GinBuffer difffold rebuilds file folds after reloading Git output"] = function()
  vim.fn.writefile({ "before" }, root .. "/file")
  H.git(root, "add", "file")
  H.git(root, "commit", "-m", "initial")
  vim.fn.writefile({ "after" }, root .. "/file")
  local index = H.git(root, "show", ":file")
  vim.cmd("GinBuffer ++difffold diff -- file")
  MiniTest.expect.equality(vim.wo.foldmethod, "manual")
  MiniTest.expect.equality(vim.fn.foldlevel(3), 1)
  vim.cmd("normal! zM")
  MiniTest.expect.equality(vim.fn.foldtextresult(3), "[.] file (+1 -1)")
  MiniTest.expect.equality(H.git(root, "show", ":file"), index)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "after" })
  H.git(root, "checkout", "--", "file")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "" })
  MiniTest.expect.equality(vim.fn.foldlevel(1), 0)
end
T["GinBuffer respects a split modifier"] = function()
  local windows = #vim.api.nvim_tabpage_list_wins(0)
  vim.cmd("botright GinBuffer ++opener=vsplit status --short")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), windows + 1)
  vim.cmd.close()
end
T["GinBuffer preview keeps focus and applies decoding options"] = function()
  vim.fn.writefile({ "caf" .. string.char(233) .. "\r" }, root .. "/file")
  H.git(root, "add", "file")
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  local ok, err = pcall(function()
    vim.cmd("GinBuffer ++opener=pedit ++enc=latin1 ++ff=dos show :file")
    MiniTest.expect.equality(
      { vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf() },
      { win, buf }
    )
    local preview
    for _, candidate in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.wo[candidate].previewwindow then
        preview = vim.api.nvim_win_get_buf(candidate)
      end
    end
    MiniTest.expect.equality(type(preview), "number")
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(preview, 0, -1, false), { "café" })
    MiniTest.expect.equality(
      { vim.bo[preview].fileencoding, vim.bo[preview].fileformat, vim.bo[preview].modifiable },
      { "latin1", "dos", false }
    )
  end)
  vim.cmd.pclose({ bang = true })
  assert(ok, err)
end
T["reading a GinBuffer URI inserts at the address and preserves buffer options"] = function()
  vim.fn.writefile({ "hello" }, root .. "/file")
  vim.cmd("GinBuffer ls-files --others")
  local name = vim.api.nvim_buf_get_name(0)
  vim.cmd.enew()
  vim.bo.filetype = "lua"
  vim.bo.fileformat = "dos"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "last" })
  local events = 0
  local id = vim.api.nvim_create_autocmd("FileReadPost", {
    pattern = "gin://*",
    callback = function()
      events = events + 1
    end,
  })
  vim.api.nvim_cmd({ cmd = "read", range = { 1 }, args = { vim.fn.fnameescape(name) } }, {})
  vim.api.nvim_del_autocmd(id)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "first", "file", "last" })
  MiniTest.expect.equality(vim.api.nvim_buf_get_mark(0, "["), { 2, 0 })
  MiniTest.expect.equality(vim.api.nvim_buf_get_mark(0, "]"), { 2, 0 })
  MiniTest.expect.equality(
    { vim.bo.filetype, vim.bo.fileformat, vim.bo.buftype, vim.bo.modified },
    { "lua", "dos", "", true }
  )
  MiniTest.expect.equality(events, 1)
end
T["reading empty Git output inserts no blank line"] = function()
  local name = require("gin.uri").format("gin", vim.uv.fs_realpath(root), {}, "status --short")
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "keep" })
  vim.api.nvim_cmd({ cmd = "read", args = { vim.fn.fnameescape(name) } }, {})
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "keep" })
end
T["read streams both channels before inserting processed stdout"] = function()
  H.git(
    root,
    "config",
    "alias.read-progress",
    [[!printf 'out\n'; printf '\033[32mwarning\033[0m\n' >&2; i=0; while test ! -f .git/read-seen; do i=$((i+1)); test "$i" -lt 100 || exit 9; sleep 0.01; done; printf 'done\n']]
  )
  local name = require("gin.uri").format("gin", vim.uv.fs_realpath(root), {
    processor = "tr a-z A-Z",
  }, "read-progress")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "last" })
  local echo, observed = vim.api.nvim_echo, {}
  local more, height = vim.o.more, vim.o.cmdheight
  vim.api.nvim_echo = function(chunks)
    observed[chunks[1][1]] = true
    if observed.out and observed.warning then
      vim.fn.writefile({}, root .. "/.git/read-seen")
    end
  end
  local ok, err = pcall(vim.api.nvim_cmd, {
    cmd = "read",
    range = { 1 },
    args = { vim.fn.fnameescape(name) },
  }, {})
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(observed.out and observed.warning, true)
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "first", "OUT", "DONE", "last" }
  )
  MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { more, height })
end
T["read honors encoding without changing the destination encoding"] = function()
  vim.fn.writefile({ "caf" .. string.char(233) }, root .. "/latin1")
  H.git(root, "add", "latin1")
  local name = require("gin.uri").format("gin", vim.uv.fs_realpath(root), {}, "show :latin1")
  vim.cmd.enew()
  vim.bo.fileencoding = "utf-8"
  vim.cmd("read ++enc=latin1 " .. vim.fn.fnameescape(name))
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "café" })
  MiniTest.expect.equality(vim.bo.fileencoding, "utf-8")
end
T["failed reads preserve content and do not emit FileReadPost"] = function()
  local name = require("gin.uri").format("gin", vim.uv.fs_realpath(root), {}, "show :missing")
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "keep" })
  local events = 0
  local id = vim.api.nvim_create_autocmd("FileReadPost", {
    pattern = "gin://*",
    callback = function()
      events = events + 1
    end,
  })
  local ok = pcall(vim.cmd, "read " .. vim.fn.fnameescape(name))
  vim.api.nvim_del_autocmd(id)
  MiniTest.expect.equality(ok, false)
  MiniTest.expect.equality(events, 0)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "keep" })
end
T["GinBuffer decoding options survive reload"] = function()
  vim.fn.writefile({ "caf" .. string.char(233) .. "\r" }, root .. "/latin1")
  H.git(root, "add", "latin1")
  vim.cmd("GinBuffer ++enc=latin1 ++ff=dos show :latin1")
  for _ = 1, 2 do
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "café" })
    MiniTest.expect.equality(vim.bo.fileformat, "dos")
    MiniTest.expect.equality(vim.bo.fileencoding, "latin1")
    vim.cmd.edit()
  end
end
T["GinBuffer processor survives reload and addressed reads"] = function()
  vim.fn.writefile({ "hello" }, root .. "/file")
  vim.cmd([[GinBuffer ++monochrome ++processor=tr\ a-z\ A-Z status --short]])
  local name = vim.api.nvim_buf_get_name(0)
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "?? FILE" })
  vim.cmd.enew()
  vim.cmd("read " .. vim.fn.fnameescape(name))
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "?? FILE" })
end
for _, operation in ipairs({ "reload", "read" }) do
  for _, failure in ipairs({ "processor", "Git" }) do
    T["failed " .. failure .. " " .. operation .. " preserves previously displayed content"] = function()
      vim.fn.writefile({ "valid output" }, root .. "/file")
      H.git(root, "add", "file")
      local script = root .. "/processor.sh"
      vim.fn.writefile({ "cat" }, script)
      local uri = require("gin.uri")
      local name = uri.format("gin", vim.uv.fs_realpath(root), {
        processor = uri.join({ "sh", script }),
      }, "show :file")
      require("gin.buffer").open(name, {})
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "valid output" })
      if operation == "read" then
        vim.cmd.enew()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
        vim.bo.filetype = "lua"
      end
      local before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local events = 0
      local id = vim.api.nvim_create_autocmd("FileReadPost", {
        pattern = "gin://*",
        callback = function()
          events = events + 1
        end,
      })
      local message = "processor exited 7"
      if failure == "processor" then
        vim.fn.writefile({ "cat >/dev/null", "printf 'partial output\\n'", "exit 7" }, script)
      else
        H.git(root, "rm", "--cached", "file")
        message = "file"
      end
      local ok, err = pcall(function()
        if operation == "reload" then
          vim.cmd.edit()
        else
          vim.cmd("1read " .. vim.fn.fnameescape(name))
        end
      end)
      vim.api.nvim_del_autocmd(id)
      MiniTest.expect.equality(ok, false)
      MiniTest.expect.equality(tostring(err):find(message, 1, true) ~= nil, true)
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), before)
      MiniTest.expect.equality(vim.bo.filetype, operation == "read" and "lua" or "gin-buffer")
      MiniTest.expect.equality(vim.bo.modifiable, operation == "read")
      MiniTest.expect.equality(events, 0)
    end
  end
end
T["failed reload restores the latest output and its decorations"] = function()
  H.git(root, "config", "alias.snapshot", "!printf 'old\\n'")
  vim.cmd("GinBuffer ++filetype=text snapshot")
  H.git(root, "config", "alias.snapshot", "!printf '\\033[31mnew\\033[0m\\r\\n'")
  vim.cmd.edit()
  local namespace = vim.api.nvim_get_namespaces().gin_ansi
  local before = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })
  MiniTest.expect.equality(#before > 0, true)
  MiniTest.expect.equality(vim.bo.fileformat, "dos")
  H.git(root, "config", "alias.snapshot", "!exit 7")
  MiniTest.expect.equality(pcall(vim.cmd.edit), false)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "new" })
  MiniTest.expect.equality(vim.bo.filetype, "text")
  MiniTest.expect.equality(vim.bo.fileformat, "dos")
  MiniTest.expect.equality(vim.bo.modified, false)
  local after = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })
  -- Extmark IDs are allocated again when the cached decoration is restored.
  for _, marks in ipairs({ before, after }) do
    for _, mark in ipairs(marks) do
      mark[1] = 0
    end
  end
  MiniTest.expect.equality(after, before)
end
T["failed output decoding preserves the display and allows a later reload"] = function()
  local function output(bytes)
    local file = assert(io.open(root .. "/file", "wb"))
    file:write(bytes)
    file:close()
  end
  H.git(root, "config", "alias.binary-output", "!cat file")
  output("o\0l\0d\0\n\0")
  vim.cmd("GinBuffer ++enc=utf-16le binary-output")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "old" })
  for _, expected in ipairs({ "old", "new" }) do
    output("x")
    local ok, err = pcall(vim.cmd, "edit ++enc=ucs-2le")
    MiniTest.expect.equality(ok, false)
    MiniTest.expect.equality(
      tostring(err):find("Unsupported encoding: ucs-2le", 1, true) ~= nil,
      true
    )
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { expected })
    MiniTest.expect.equality(vim.bo.fileencoding, "utf-16le")
    MiniTest.expect.equality(vim.bo.modifiable, false)
    MiniTest.expect.equality(vim.bo.modified, false)
    output("n\0e\0w\0\n\0")
    vim.cmd("edit ++enc=utf-16le")
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "new" })
  end
end
T["unloaded output survives a failed reopen but is discarded on wipeout"] = function()
  H.git(root, "config", "alias.lifecycle", "!printf 'saved\\n'")
  vim.cmd("GinBuffer lifecycle")
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  vim.cmd.enew()
  MiniTest.expect.equality(vim.api.nvim_buf_is_valid(buf), true)
  MiniTest.expect.equality(vim.api.nvim_buf_is_loaded(buf), false)
  H.git(root, "config", "alias.lifecycle", "!exit 7")
  MiniTest.expect.equality(pcall(vim.cmd.buffer, buf), false)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "saved" })
  MiniTest.expect.equality(vim.bo[buf].modifiable, false)
  H.git(root, "config", "alias.lifecycle", "!printf 'fresh\\n'")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "fresh" })
  vim.cmd.bwipeout({ bang = true })
  MiniTest.expect.equality(vim.api.nvim_buf_is_valid(buf), false)
  H.git(root, "config", "alias.lifecycle", "!exit 7")
  MiniTest.expect.equality(pcall(vim.cmd, "edit " .. vim.fn.fnameescape(name)), false)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "" })
  MiniTest.expect.equality(vim.b.gin_buffer_snapshot, nil)
end
T["GinBuffer renders Git colors as highlights and monochrome omits them"] = function()
  vim.fn.writefile({ "hello" }, root .. "/file")
  vim.cmd("GinBuffer status --short")
  local ns = vim.api.nvim_create_namespace("gin_ansi")
  local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
  MiniTest.expect.equality(#marks > 0, true)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "?? file" })
  local highlight = vim.api.nvim_get_hl(0, { name = marks[1][4].hl_group, link = false })
  MiniTest.expect.equality(highlight.ctermfg, 1)
  vim.cmd("GinBuffer ++monochrome status --short")
  MiniTest.expect.equality(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}), {})
end

T["GinBuffer emojify preserves color positions across reload and read"] = function()
  H.git(root, "commit", "--allow-empty", "-m", "initial")
  vim.cmd("GinBuffer ++emojify log -1 --color=always --format=%C(red):sparkles:%C(reset)tail")
  local name = vim.api.nvim_buf_get_name(0)
  for _ = 1, 2 do
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "✨tail" })
    local marks = vim.api.nvim_buf_get_extmarks(
      0,
      vim.api.nvim_create_namespace("gin_ansi"),
      0,
      -1,
      { details = true }
    )
    MiniTest.expect.equality(#marks, 1)
    MiniTest.expect.equality(marks[1][3], 0)
    MiniTest.expect.equality(marks[1][4].end_col, #"✨")
    vim.cmd.edit()
  end
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
  vim.cmd("1read " .. vim.fn.fnameescape(name))
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "before", "✨tail", "after" }
  )
end

for _, disabled in ipairs({ false, true }) do
  T["command buffer jump mappings use their own disable option " .. tostring(disabled)] = function()
    H.git(root, "commit", "--allow-empty", "-m", "initial")
    local buffer_option, diff_option =
      vim.g.gin_buffer_disable_default_mappings, vim.g.gin_diff_disable_default_mappings
    vim.g.gin_buffer_disable_default_mappings = disabled and 1 or 0
    vim.g.gin_diff_disable_default_mappings = disabled and 0 or 1
    local ok, err = pcall(function()
      vim.cmd("GinBuffer ++diffjump=HEAD show HEAD")
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
T["edit decoding overrides URI defaults for the current read"] = function()
  vim.fn.writefile({ "café\r" }, root .. "/encoded")
  H.git(root, "add", "encoded")
  for _, command in ipairs({
    "GinBuffer ++enc=latin1 ++ff=dos show :encoded",
    "GinEdit ++enc=latin1 ++ff=dos encoded",
  }) do
    vim.cmd(command)
    local name = vim.api.nvim_buf_get_name(0)
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "cafÃ©" })
    vim.cmd("edit ++encoding=utf-8 ++fileformat=unix")
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "café\r" })
    MiniTest.expect.equality({ vim.bo.fileencoding, vim.bo.fileformat }, { "utf-8", "unix" })
    MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), name)
    vim.cmd.edit()
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "cafÃ©" })
    MiniTest.expect.equality({ vim.bo.fileencoding, vim.bo.fileformat }, { "latin1", "dos" })
  end
end
return T
