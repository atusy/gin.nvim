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
T["GinBuffer respects a split modifier"] = function()
  local windows = #vim.api.nvim_tabpage_list_wins(0)
  vim.cmd("botright GinBuffer ++opener=vsplit status --short")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), windows + 1)
  vim.cmd.close()
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
          disabled and "" or ("<Plug>(gin-diffjump-" .. side .. ")")
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
