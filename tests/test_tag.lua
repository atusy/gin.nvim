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
T["tag echo exposes the selected annotated object"] = function()
  vim.cmd("GinTag --format=display-only")
  local echo, output = vim.api.nvim_echo, nil
  vim.api.nvim_echo = function(chunks)
    output = chunks[1][1]
  end
  local ok, err =
    pcall(require("gin.action").call, vim.api.nvim_get_current_buf(), "echo", { 2, 2 })
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(vim.json.decode(output), {
    { tag = "release", commit = vim.trim(H.git(root, "rev-parse", "refs/tags/release")) },
  })
end
T["tag groups repeated flags for display, insertion and deletion"] = function()
  for _, case in ipairs({
    { "--ignore-case --no-ignore-case --ignore-case", {} },
    { "--no-ignore-case --ignore-case --no-ignore-case", { "release" } },
  }) do
    vim.cmd("GinTag --format=%(refname:short) " .. case[1] .. " REL*")
    for _ = 1, 2 do
      MiniTest.expect.equality(
        vim.tbl_map(function(row)
          return row.tag
        end, vim.b.gin_tags),
        case[2]
      )
      vim.cmd.edit()
    end
  end
  local name = vim.api.nvim_buf_get_name(0)
  vim.cmd.enew()
  vim.bo.filetype = "lua"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
  vim.api.nvim_cmd({ cmd = "read", args = { name }, range = { 1 }, magic = { file = false } }, {})
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "before", "release", "after" }
  )
  MiniTest.expect.equality(vim.bo.filetype, "lua")
  require("gin.buffer").open(name, { bang = true })
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 1, 1 })
  H.drain()
  MiniTest.expect.equality(H.git(root, "tag", "--list"), "light\n")
  MiniTest.expect.equality(vim.b.gin_tags, {})
end
T["legacy tag URIs retain format and patterns for reads and deletion"] = function()
  local name = "gintag://" .. root .. ";format=%25%28refname%3Ashort%29#missing%2A rel%2A$"
  require("gin.buffer").open(name, {})
  for _ = 1, 2 do
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "release" })
    MiniTest.expect.equality(vim.b.gin_tags[1].tag, "release")
    vim.cmd.edit()
  end
  vim.cmd.enew()
  vim.bo.filetype = "lua"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
  vim.api.nvim_cmd({ cmd = "read", args = { name }, range = { 1 }, magic = { file = false } }, {})
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "before", "release", "after" }
  )
  MiniTest.expect.equality(vim.bo.filetype, "lua")
  require("gin.buffer").open(name, { bang = true })
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 1, 1 })
  H.drain()
  MiniTest.expect.equality(H.git(root, "tag", "--list"), "light\n")
  MiniTest.expect.equality(vim.b.gin_tags, {})
end
T["tag delete removes only selected refs"] = function()
  vim.cmd.GinTag()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "tag", "--list"), "release\n")
  H.drain()
  MiniTest.expect.equality(#vim.b.gin_tags, 1)
end
for _, locked in ipairs({ "light", "release" }) do
  T["partial tag deletion refreshes successfully removed refs when locked=" .. locked] = function()
    vim.cmd.GinTag()
    local retained = H.git(root, "rev-parse", "refs/tags/" .. locked)
    vim.fn.writefile({ "locked" }, root .. "/.git/refs/tags/" .. locked .. ".lock")
    MiniTest.expect.error(function()
      require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 1, 2 })
    end, "git exited")
    MiniTest.expect.equality(H.git(root, "tag", "--list"), locked .. "\n")
    MiniTest.expect.equality(H.git(root, "rev-parse", "refs/tags/" .. locked), retained)
    MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "base" })
    MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
    H.drain()
    MiniTest.expect.equality(
      vim.tbl_map(function(row)
        return row.tag
      end, vim.b.gin_tags),
      { locked }
    )
  end
end
T["tag show opens annotated tag content"] = function()
  vim.cmd("GinTag rel*")
  vim.cmd.edit()
  vim.api.nvim_feedkeys("\r", "mx", false)
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("release notes", 1, true) ~= nil, true)
end
T["ordinary tag switch reports Git refusal without detaching HEAD"] = function()
  local head = H.git(root, "rev-parse", "HEAD")
  vim.cmd("GinTag release")
  MiniTest.expect.error(function()
    require("gin.action").call(vim.api.nvim_get_current_buf(), "switch", { 1, 1 })
  end, "git exited")
  MiniTest.expect.equality(H.git(root, "branch", "--show-current"), "main\n")
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), head)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "base" })
  MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
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
T["custom tag formats survive reload and retain selected refs"] = function()
  vim.cmd("GinTag --sort=-refname --format=%(refname:short):%(subject)")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
    "release:release notes",
    "light:initial",
  })
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "tag", "--list"), "light\n")
end
T["tag color flags preserve selected refs across reload"] = function()
  H.git(root, "config", "color.ui", "always")
  local format = "--format=%(color:blue)%(refname:short)%(color:reset)"
  local ns = vim.api.nvim_create_namespace("gin_ansi")
  vim.cmd("GinTag " .. format)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "light", "release" })
  MiniTest.expect.equality(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}), {})
  vim.cmd("GinTag --color=always --sort=-refname " .. format)
  for _ = 1, 2 do
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "release", "light" })
    local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
    MiniTest.expect.equality(#marks, 2)
    MiniTest.expect.equality(marks[1][4].hl_group, "GinColorF4")
    vim.cmd.edit()
  end
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "tag", "--list"), "light\n")
  vim.cmd("GinTag --no-color " .. format)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "light" })
  MiniTest.expect.equality(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}), {})
  MiniTest.expect.equality(H.git(root, "config", "color.ui"), "always\n")
end
T["default tag display matches the pinned upstream format"] = function()
  vim.cmd.GinTag()
  local expected = H.git(
    root,
    "tag",
    "--list",
    "--color=never",
    "--format=%(objectname:short) %(refname:short) %(creatordate:short) %(subject)"
  )
  MiniTest.expect.equality(
    table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n",
    expected
  )
end
T["multiline tag formats select each displayed ref once"] = function()
  vim.cmd("GinTag --format=%(refname:short)%0a%(subject)")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
    "light",
    "initial",
    "release",
    "release notes",
  })
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 3, 4 })
  MiniTest.expect.equality(H.git(root, "tag", "--list"), "light\n")
end
T["NUL bytes in tag formats cannot replace action metadata"] = function()
  vim.cmd("GinTag --format=%(refname:short)%00%0a%(subject)%00end")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
    "light\0",
    "initial\0end",
    "release\0",
    "release notes\0end",
  })
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 3, 4 })
  MiniTest.expect.equality(H.git(root, "tag", "--list"), "light\n")
end
T["reading tag URIs inserts decoded output without installing a tag view"] = function()
  H.git(root, "tag", "-a", "encoded", "-m", ":sparkles: caf" .. string.char(233))
  vim.cmd("GinTag ++emojify ++enc=latin1 --format=%(subject) encoded")
  local name = vim.api.nvim_buf_get_name(0)
  vim.cmd.enew()
  vim.bo.filetype, vim.bo.fileformat, vim.bo.fileencoding = "lua", "dos", "utf-8"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "last" })
  local events = 0
  local id = vim.api.nvim_create_autocmd("FileReadPost", {
    pattern = "gintag://*",
    callback = function()
      events = events + 1
    end,
  })
  local ok, err = pcall(vim.cmd, "1read ++enc=latin1 " .. vim.fn.fnameescape(name))
  vim.api.nvim_del_autocmd(id)
  assert(ok, err)
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "first", "✨ café", "last" }
  )
  MiniTest.expect.equality(vim.api.nvim_buf_get_mark(0, "["), { 2, 0 })
  MiniTest.expect.equality(vim.api.nvim_buf_get_mark(0, "]"), { 2, 0 })
  MiniTest.expect.equality(
    { vim.bo.filetype, vim.bo.fileformat, vim.bo.fileencoding, vim.bo.buftype, vim.bo.modified },
    { "lua", "dos", "utf-8", "", true }
  )
  MiniTest.expect.equality(vim.b.gin_tags, nil)
  MiniTest.expect.equality(events, 1)
end
for _, failing in ipairs({ false, true }) do
  T["tag reads preserve destination on " .. (failing and "failure" or "empty output")] = function()
    local name = require("gin.uri").format("gintag", vim.uv.fs_realpath(root), {
      args = vim.json.encode(failing and { "--invalid-gin-flag" } or {}),
    }, "absent-tag")
    vim.cmd.enew()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "keep" })
    local events = 0
    local id = vim.api.nvim_create_autocmd("FileReadPost", {
      pattern = "gintag://*",
      callback = function()
        events = events + 1
      end,
    })
    local ok = pcall(vim.cmd, "read " .. vim.fn.fnameescape(name))
    vim.api.nvim_del_autocmd(id)
    MiniTest.expect.equality(ok, not failing)
    MiniTest.expect.equality(events, failing and 0 or 1)
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "keep" })
  end
end
return T
