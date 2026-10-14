local H = require("tests.helpers")
local root, first, second
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.mkdir(root .. "/sub", "p")
      vim.fn.writefile({ "one", "two", "three" }, root .. "/sub/file.lua")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      first = vim.trim(H.git(root, "rev-parse", "HEAD"))
      vim.fn.writefile({ "one", "changed", "three" }, root .. "/sub/file.lua")
      H.git(root, "commit", "-am", "second")
      second = vim.trim(H.git(root, "rev-parse", "HEAD"))
      vim.cmd.cd(root .. "/sub")
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd("filetype plugin on")
      vim.g.gin_edit_default_args = nil
      vim.g.gin_edit_persistent_args = nil
      vim.cmd.tabonly({ bang = true })
      vim.cmd.only({ bang = true })
      vim.wo.winfixbuf = false
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
T["blame opens synchronized attribution and committed content from a subdirectory"] = function()
  vim.fn.writefile({ "dirty" }, root .. "/sub/file.lua")
  local tabs = #vim.api.nvim_list_tabpages()
  vim.cmd("GinBlame file.lua")
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 3)
  MiniTest.expect.equality(vim.bo.filetype, "gin-blame-nav")
  local nav = vim.api.nvim_get_current_buf()
  local file = vim.b.gin_blame_file_bufnr
  local lines = vim.api.nvim_buf_get_lines(file, 0, -1, false)
  MiniTest.expect.equality(lines, { "", "one", "", "changed", "", "three" })
  local map = vim.b[nav].gin_blame_line_map
  MiniTest.expect.equality(
    { map[2].commitSha, map[4].commitSha, map[6].commitSha },
    { first, second, first }
  )
  MiniTest.expect.equality(
    { map[2].originalLineNumber, map[4].lineNumber, map[6].originalLineNumber },
    { 1, 2, 3 }
  )
  MiniTest.expect.equality(vim.b[file].gin_blame_file_line_to_physical, { 2, 4, 6 })
  MiniTest.expect.equality(vim.bo[file].filetype, "lua.gin-blame")
  MiniTest.expect.equality(vim.bo[file].modifiable, false)
  for _, buf in ipairs({ nav, file }) do
    local win = vim.fn.bufwinid(buf)
    MiniTest.expect.equality(
      { vim.wo[win].scrollbind, vim.wo[win].cursorbind, vim.wo[win].wrap },
      { true, true, false }
    )
  end
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "dirty" })
end
T["blame maintains upstream buffer links through history and reload"] = function()
  vim.cmd("GinBlame file.lua")
  local nav = vim.api.nvim_get_current_buf()
  local file = vim.b[nav].gin_blame_file_bufnr
  local detail = vim.b[nav].gin_blame_detail_bufnr
  local function check_links()
    MiniTest.expect.equality(vim.b[nav].gin_blame_file_bufname, vim.api.nvim_buf_get_name(file))
    MiniTest.expect.equality(vim.b[file].gin_blame_nav_bufname, vim.api.nvim_buf_get_name(nav))
    for _, buf in ipairs({ file, nav }) do
      MiniTest.expect.equality(vim.b[buf].gin_blame_file_fragment, "sub/file.lua")
      MiniTest.expect.equality(
        vim.b[buf].gin_blame_detail_bufname,
        vim.api.nvim_buf_get_name(detail)
      )
    end
  end
  check_links()
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  require("gin.blame").switch_commit()
  check_links()
  require("gin.blame").navigate_history("older")
  check_links()
  vim.b[nav].gin_blame_file_bufnr = nil
  vim.cmd.edit()
  H.drain()
  check_links()
  MiniTest.expect.equality(vim.b[nav].gin_blame_file_bufnr, file)
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 3)
end
T["changing blame filetypes removes their mappings and window pinning"] = function()
  vim.cmd("GinBlame file.lua")
  local nav = vim.api.nvim_get_current_buf()
  local file = vim.b[nav].gin_blame_file_bufnr
  for _, buf in ipairs({ nav, file }) do
    vim.api.nvim_set_current_win(vim.fn.bufwinid(buf))
    MiniTest.expect.equality(vim.fn.maparg("<CR>", "n"), "<Plug>(gin-blame-switch-commit)")
    vim.cmd.edit()
    H.drain()
    local undo = vim.b[buf].undo_ftplugin
    vim.cmd.edit()
    H.drain()
    MiniTest.expect.equality(vim.b[buf].undo_ftplugin, undo)
    vim.api.nvim_set_current_win(vim.fn.bufwinid(buf))
    vim.bo[buf].filetype = "text"
    for _, key in ipairs({
      "<CR>",
      "<C-O>",
      "<C-I>",
      "<Plug>(gin-blame-switch-commit)",
      "<Plug>(gin-blame-navigate-older)",
      "<Plug>(gin-blame-navigate-newer)",
    }) do
      MiniTest.expect.equality(vim.fn.maparg(key, "n"), "")
    end
    MiniTest.expect.equality(vim.wo.winfixbuf, vim.go.winfixbuf)
  end
end
T["blame content refresh preserves remapped and removed navigation keys"] = function()
  vim.cmd("GinBlame file.lua")
  local nav = vim.api.nvim_get_current_buf()
  local file = vim.b[nav].gin_blame_file_bufnr
  for _, buf in ipairs({ nav, file }) do
    vim.api.nvim_set_current_win(vim.fn.bufwinid(buf))
    local filetype = vim.bo[buf].filetype
    vim.keymap.set("n", "<CR>", "user-blame-enter", { buffer = buf })
    vim.keymap.del("n", "<C-O>", { buffer = buf })
    vim.keymap.set("n", "<Plug>(gin-blame-switch-commit)", "user-blame-switch", { buffer = buf })
    if buf == nav then
      require("gin.blame").read_nav(buf)
    else
      require("gin.blame").read(buf, vim.api.nvim_buf_get_name(buf))
    end
    H.drain()
    vim.api.nvim_set_current_win(vim.fn.bufwinid(buf))
    MiniTest.expect.equality(vim.fn.maparg("<CR>", "n"), "user-blame-enter")
    MiniTest.expect.equality(vim.fn.maparg("<C-O>", "n"), "")
    MiniTest.expect.equality(
      vim.fn.maparg("<Plug>(gin-blame-switch-commit)", "n"),
      "user-blame-switch"
    )
    vim.bo[buf].filetype = "text"
    vim.bo[buf].filetype = filetype
    vim.cmd.edit()
    H.drain()
    vim.api.nvim_set_current_win(vim.fn.bufwinid(buf))
    MiniTest.expect.equality(vim.fn.maparg("<CR>", "n"), "<Plug>(gin-blame-switch-commit)")
    MiniTest.expect.equality(vim.fn.maparg("<C-O>", "n"), "<Plug>(gin-blame-navigate-older)")
  end
end
T["blame respects disabled filetype plugins when opening its panes"] = function()
  vim.cmd("filetype plugin off")
  vim.cmd("GinBlame file.lua")
  local nav = vim.api.nvim_get_current_buf()
  local file = vim.b[nav].gin_blame_file_bufnr
  for _, buf in ipairs({ nav, file }) do
    vim.api.nvim_set_current_win(vim.fn.bufwinid(buf))
    MiniTest.expect.equality(vim.wo.winfixbuf, false)
    MiniTest.expect.equality(vim.wo.scrollbind, true)
    for _, key in ipairs({
      "<CR>",
      "<C-O>",
      "<C-I>",
      "<Plug>(gin-blame-switch-commit)",
      "<Plug>(gin-blame-navigate-older)",
      "<Plug>(gin-blame-navigate-newer)",
    }) do
      MiniTest.expect.equality(vim.fn.maparg(key, "n"), "")
    end
  end
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(file, 0, -1, false),
    { "", "one", "", "changed", "", "three" }
  )
end
T["legacy blame paths survive reload and history navigation"] = function()
  local path = "sub/space + 日本語$.lua"
  H.git(root, "mv", "sub/file.lua", path)
  H.git(root, "commit", "-m", ":sparkles: rename")
  local revision = vim.trim(H.git(root, "rev-parse", "HEAD"))
  H.git(root, "checkout", "--detach", first)
  local name = "ginblame://"
    .. root
    .. ";commitish="
    .. revision
    .. "&emojify=#"
    .. path:gsub("/", "\\")
  local file = require("gin.buffer").open(name, { opener = "tabedit" })
  local nav, detail = vim.b[file].gin_blame_nav_bufnr, vim.b[file].gin_blame_detail_bufnr
  local windows = vim.api.nvim_tabpage_list_wins(0)
  MiniTest.expect.equality(#windows, 3)
  local function restored()
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(file, 0, -1, false),
      { "", "one", "", "changed", "", "three" }
    )
    MiniTest.expect.equality(vim.b[nav].gin_blame_line_map[4].commitSha, second)
    local lines = vim.api.nvim_buf_get_lines(detail, 0, -1, false)
    MiniTest.expect.equality(lines[1], "commit " .. revision)
    MiniTest.expect.equality(table.concat(lines, "\n"):find("✨ rename", 1, true) ~= nil, true)
    MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
  end
  restored()
  for _, target in ipairs({ file, nav }) do
    vim.api.nvim_set_current_win(vim.fn.bufwinid(target))
    vim.cmd.edit()
    H.drain()
    restored()
  end
  -- Start from the legacy file URI so its path is saved in the history entry.
  vim.api.nvim_set_current_win(vim.fn.bufwinid(file))
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  require("gin.blame").switch_commit()
  local parsed = require("gin.uri").parse(vim.api.nvim_buf_get_name(file))
  MiniTest.expect.equality({ parsed.params.commitish, parsed.fragment }, { second, "sub/file.lua" })
  require("gin.blame").navigate_history("older")
  parsed = require("gin.uri").parse(vim.api.nvim_buf_get_name(file))
  MiniTest.expect.equality({ parsed.params.commitish, parsed.fragment }, { revision, path })
  MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0)[1], 4)
  MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
  require("gin.blame").navigate_history("newer")
  MiniTest.expect.equality(
    require("gin.uri").parse(vim.api.nvim_buf_get_name(file)).params.commitish,
    second
  )
  MiniTest.expect.equality(vim.trim(H.git(root, "rev-parse", "HEAD")), first)
  MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
end
T["blame and commit detail stream stderr without displaying porcelain data"] = function()
  local trace, echo = vim.env.GIT_TRACE, vim.api.nvim_echo
  local output = {}
  local more, height = vim.o.more, vim.o.cmdheight
  vim.env.GIT_TRACE = "1"
  vim.api.nvim_echo = function(chunks)
    output[#output + 1] = chunks[1][1]
  end
  local ok, err = pcall(function()
    vim.cmd("GinBlame file.lua")
    local progress = table.concat(output, "\n")
    MiniTest.expect.equality(progress:find("built-in: git blame", 1, true) ~= nil, true)
    MiniTest.expect.equality(progress:find("built-in: git show", 1, true) ~= nil, true)
    MiniTest.expect.equality(progress:find("author Gin Test", 1, true), nil)
    MiniTest.expect.equality(progress:find("Author:", 1, true), nil)
    output = {}
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
    progress = table.concat(output, "\n")
    MiniTest.expect.equality(progress:find("--format=fuller " .. first, 1, true) ~= nil, true)
    MiniTest.expect.equality(progress:find("Author:", 1, true), nil)
    local detail = vim.b.gin_blame_detail_bufnr
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(detail, 0, 1, false),
      { "commit " .. first }
    )
    MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 3)
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { more, height })
  end)
  vim.env.GIT_TRACE, vim.api.nvim_echo = trace, echo
  assert(ok, err)
end
T["moving across blame groups updates commit detail and dividers retain it"] = function()
  vim.cmd("GinBlame file.lua")
  local detail = vim.b.gin_blame_detail_bufnr
  local function displayed()
    return vim.api.nvim_buf_get_lines(detail, 0, 1, false)[1]
  end
  MiniTest.expect.equality(displayed(), "commit " .. second)
  for _, case in ipairs({ { 2, first }, { 3, first }, { 4, second }, { 6, first }, { 1, second } }) do
    vim.api.nvim_win_set_cursor(0, { case[1], 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
    MiniTest.expect.equality(displayed(), "commit " .. case[2])
  end
end
T["reloading either blame pane updates the existing three windows"] = function()
  vim.cmd("GinBlame file.lua")
  local nav, file, detail =
    vim.api.nvim_get_current_buf(), vim.b.gin_blame_file_bufnr, vim.b.gin_blame_detail_bufnr
  local windows = vim.api.nvim_tabpage_list_wins(0)
  for i, target in ipairs({ file, nav }) do
    vim.fn.writefile({ "version " .. i }, root .. "/sub/file.lua")
    H.git(root, "commit", "-am", "reload " .. i)
    local commit = vim.trim(H.git(root, "rev-parse", "HEAD"))
    vim.api.nvim_set_current_win(vim.fn.bufwinid(target))
    vim.cmd.edit()
    local settled = false
    vim.schedule(function()
      settled = true
    end)
    MiniTest.expect.equality(
      vim.wait(1000, function()
        return settled
      end, 10),
      true
    )
    MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(file, 0, -1, false),
      { "", "version " .. i }
    )
    MiniTest.expect.equality(vim.b[nav].gin_blame_line_map[2].commitSha, commit)
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(detail, 0, 1, false),
      { "commit " .. commit }
    )
  end
end
T["navigation reload restores a hidden paired file"] = function()
  vim.cmd("GinBlame file.lua")
  local nav = vim.api.nvim_get_current_buf()
  local navwin = vim.api.nvim_get_current_win()
  local file = vim.b[nav].gin_blame_file_bufnr
  local detail = vim.b[nav].gin_blame_detail_bufnr
  local name = vim.api.nvim_buf_get_name(file)
  vim.bo[file].bufhidden = "hide"
  vim.api.nvim_win_close(vim.fn.bufwinid(file), true)
  H.drain()
  MiniTest.expect.equality(vim.api.nvim_buf_is_loaded(file), true)
  MiniTest.expect.equality(vim.fn.bufwinid(file), -1)
  vim.fn.writefile({ "restored" }, root .. "/sub/file.lua")
  H.git(root, "commit", "-am", "restore hidden blame")
  local commit = vim.trim(H.git(root, "rev-parse", "HEAD"))
  vim.api.nvim_set_current_win(navwin)
  vim.cmd.edit()
  H.drain()
  MiniTest.expect.equality(vim.api.nvim_get_current_win(), navwin)
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 3)
  MiniTest.expect.equality(vim.b[nav].gin_blame_file_bufnr, file)
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(file), name)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(file, 0, -1, false), { "", "restored" })
  MiniTest.expect.equality(vim.b[nav].gin_blame_line_map[2].commitSha, commit)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(detail, 0, 1, false), { "commit " .. commit })
  for _, target in ipairs({ nav, file }) do
    MiniTest.expect.equality(vim.wo[vim.fn.bufwinid(target)].winfixbuf, true)
  end
end
T["legacy navigation reload resolves its paired file by name"] = function()
  local suffix = "://" .. root .. ";commitish=" .. first .. "#sub/file.lua"
  vim.cmd.tabnew()
  local file = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(file, "ginblame" .. suffix)
  local filewin = vim.api.nvim_get_current_win()
  vim.cmd("topleft new")
  local detail = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(detail, "ginblamedetail" .. suffix)
  vim.api.nvim_set_current_win(filewin)
  vim.cmd("leftabove vnew")
  local nav = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(nav, "ginblamenav" .. suffix)
  vim.b[nav].gin_blame_file_bufname = "ginblame" .. suffix
  vim.b[nav].gin_blame_file_fragment = "sub/file.lua"
  vim.wo.winfixbuf = true
  vim.wo[filewin].winfixbuf = true
  local windows = vim.api.nvim_tabpage_list_wins(0)
  vim.cmd.edit()
  H.drain()
  MiniTest.expect.equality(vim.api.nvim_get_current_buf(), nav)
  MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(file, 0, -1, false),
    { "", "one", "two", "three" }
  )
  MiniTest.expect.equality(vim.b[nav].gin_blame_line_map[3].commitSha, first)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(detail, 0, 1, false), { "commit " .. first })
  MiniTest.expect.equality({
    vim.b[nav].gin_blame_file_bufnr,
    vim.b[file].gin_blame_nav_bufnr,
    vim.b[file].gin_blame_detail_bufnr,
  }, { file, nav, detail })
  for _, buf in ipairs({ file, nav }) do
    MiniTest.expect.equality(vim.wo[vim.fn.bufwinid(buf)].winfixbuf, true)
  end
  vim.api.nvim_set_current_win(filewin)
  vim.cmd.edit()
  H.drain()
  MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
  MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
end
T["navigation reload uses its revision rather than the paired file URI"] = function()
  local file_name = "ginblame://" .. root .. ";commitish=" .. first .. "#sub/file.lua"
  local suffix = "://" .. root .. ";commitish=" .. second .. "#sub/file.lua"
  vim.cmd.tabnew()
  local file = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(file, file_name)
  local filewin = vim.api.nvim_get_current_win()
  vim.cmd("topleft new")
  local detail = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(detail, "ginblamedetail" .. suffix)
  vim.api.nvim_set_current_win(filewin)
  vim.cmd("leftabove vnew")
  local nav = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(nav, "ginblamenav" .. suffix)
  vim.b[nav].gin_blame_file_bufname = file_name
  vim.b[nav].gin_blame_file_fragment = "sub/file.lua"
  local windows = vim.api.nvim_tabpage_list_wins(0)
  vim.cmd.edit()
  H.drain()
  MiniTest.expect.equality(vim.api.nvim_get_current_buf(), nav)
  MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(file), file_name)
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(file, 0, -1, false),
    { "", "one", "", "changed", "", "three" }
  )
  MiniTest.expect.equality(vim.b[nav].gin_blame_line_map[4].commitSha, second)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(detail, 0, 1, false), { "commit " .. second })
end
T["navigation reload uses the stored file fragment"] = function()
  vim.cmd("GinBlame file.lua")
  local nav = vim.api.nvim_get_current_buf()
  local file = vim.b[nav].gin_blame_file_bufnr
  local name = vim.api.nvim_buf_get_name(nav)
  local parsed = require("gin.uri").parse(name)
  vim.api.nvim_buf_set_name(
    nav,
    require("gin.uri").format("ginblamenav", parsed.root, parsed.params, "missing.lua")
  )
  vim.cmd.edit()
  H.drain()
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(file, 0, -1, false),
    { "", "one", "", "changed", "", "three" }
  )
  local restored = vim.b[file].gin_blame_nav_bufnr
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(restored), name)
  MiniTest.expect.equality(vim.b[restored].gin_blame_file_fragment, "sub/file.lua")
  MiniTest.expect.equality(vim.b[restored].gin_blame_line_map[4].commitSha, second)
end
T["navigation reload rejects missing stored context"] = function()
  vim.cmd("GinBlame file.lua")
  local nav = vim.api.nvim_get_current_buf()
  local file = vim.b[nav].gin_blame_file_bufnr
  local lines = vim.api.nvim_buf_get_lines(file, 0, -1, false)
  local windows = vim.api.nvim_tabpage_list_wins(0)
  for _, case in ipairs({
    { "gin_blame_file_fragment", "file fragment not found" },
    { "gin_blame_file_bufname", "associated ginblame buffer not found" },
  }) do
    local original = vim.b[nav][case[1]]
    for _, value in ipairs({ vim.NIL, "" }) do
      vim.b[nav][case[1]] = value
      MiniTest.expect.error(function()
        require("gin.blame").read_nav(nav)
      end, "Cannot reload ginblamenav: " .. case[2])
      vim.b[nav][case[1]] = original
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(file, 0, -1, false), lines)
      MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
    end
  end
end
T["legacy navigation recreates a missing file buffer"] = function()
  local suffix = "://" .. root .. ";commitish=" .. first .. "#sub/file.lua"
  vim.cmd.tabnew()
  local file = vim.api.nvim_get_current_buf()
  local filewin = vim.api.nvim_get_current_win()
  vim.cmd("topleft new")
  local detail = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(detail, "ginblamedetail" .. suffix)
  vim.api.nvim_set_current_win(filewin)
  vim.cmd("leftabove vnew")
  local nav = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(nav, "ginblamenav" .. suffix)
  vim.b[nav].gin_blame_file_bufname = "ginblame" .. suffix
  vim.b[nav].gin_blame_file_fragment = "sub/file.lua"
  vim.wo.winfixbuf = true
  vim.wo[filewin].winfixbuf = true
  local windows = vim.api.nvim_tabpage_list_wins(0)
  MiniTest.expect.equality(vim.fn.bufnr("ginblame" .. suffix), -1)
  vim.cmd.edit()
  H.drain()
  file = vim.fn.bufnr("ginblame" .. suffix)
  MiniTest.expect.equality(file > 0, true)
  MiniTest.expect.equality(vim.api.nvim_get_current_buf(), nav)
  MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(file, 0, -1, false),
    { "", "one", "two", "three" }
  )
  MiniTest.expect.equality(vim.b[nav].gin_blame_line_map[3].commitSha, first)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(detail, 0, 1, false), { "commit " .. first })
  MiniTest.expect.equality({
    vim.b[nav].gin_blame_file_bufnr,
    vim.b[file].gin_blame_nav_bufnr,
    vim.b[file].gin_blame_detail_bufnr,
  }, { file, nav, detail })
  for _, buf in ipairs({ file, nav }) do
    MiniTest.expect.equality(vim.wo[vim.fn.bufwinid(buf)].winfixbuf, true)
  end
  vim.api.nvim_set_current_win(filewin)
  vim.cmd.edit()
  H.drain()
  MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
  MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
end
T["missing detail commits clear stale details without breaking navigation"] = function()
  vim.cmd("GinBlame file.lua")
  local nav, file, detail =
    vim.api.nvim_get_current_buf(), vim.b.gin_blame_file_bufnr, vim.b.gin_blame_detail_bufnr
  local content = vim.api.nvim_buf_get_lines(file, 0, -1, false)
  local object = root .. "/.git/objects/" .. first:sub(1, 2) .. "/" .. first:sub(3)
  local saved = root .. "/.git/missing-object"
  assert(vim.uv.fs_rename(object, saved))
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("gin.blame").update_detail(nav, 2)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(detail, 0, -1, false), { "" })
  MiniTest.expect.equality(vim.b[detail].gin_blame_detail_last_commit, first)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(file, 0, -1, false), content)
  assert(vim.uv.fs_rename(saved, object))
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  require("gin.blame").update_detail(nav, 4)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(detail, 0, 1, false), { "commit " .. second })
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 3)
end
T["unloading a blame pane removes its companions and preserves other buffers"] = function()
  vim.cmd.edit(root .. "/sub/file.lua")
  local unrelated = vim.api.nvim_get_current_buf()
  for _, role in ipairs({ "nav", "file", "detail" }) do
    vim.cmd("GinBlame file.lua")
    local panes = {
      nav = vim.b.gin_blame_nav_bufnr,
      file = vim.b.gin_blame_file_bufnr,
      detail = vim.b.gin_blame_detail_bufnr,
    }
    vim.api.nvim_set_current_win(vim.fn.bufwinid(panes[role]))
    vim.cmd.close()
    local removed = vim.wait(1000, function()
      for other, buf in pairs(panes) do
        if other ~= role and vim.api.nvim_buf_is_valid(buf) then
          return false
        end
      end
      return true
    end, 10)
    MiniTest.expect.equality(removed, true)
    MiniTest.expect.equality(vim.api.nvim_buf_is_loaded(unrelated), true)
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(unrelated, 0, -1, false),
      { "one", "changed", "three" }
    )
  end
end
T["selecting attribution follows a renamed file to its source commit"] = function()
  H.git(root, "mv", "sub/file.lua", "sub/renamed.lua")
  H.git(root, "commit", "-m", "rename")
  vim.cmd("GinBlame renamed.lua")
  local nav, file = vim.api.nvim_get_current_buf(), vim.b.gin_blame_file_bufnr
  local windows = vim.api.nvim_tabpage_list_wins(0)
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  require("gin.blame").switch_commit()
  local parsed = require("gin.uri").parse(vim.api.nvim_buf_get_name(nav))
  MiniTest.expect.equality({ parsed.params.commitish, parsed.fragment }, { second, "sub/file.lua" })
  MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
  MiniTest.expect.equality(vim.api.nvim_get_current_buf(), nav)
  MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0)[1], 4)
  vim.api.nvim_set_current_win(vim.fn.bufwinid(file))
  require("gin.blame").switch_commit()
  parsed = require("gin.uri").parse(vim.api.nvim_buf_get_name(file))
  MiniTest.expect.equality(parsed.params.commitish, second .. "^")
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(file, 0, -1, false),
    { "", "one", "two", "three" }
  )
  MiniTest.expect.equality(vim.api.nvim_get_current_buf(), file)
  MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0)[1], 3)
end
T["commit selection decodes quoted historical filenames"] = function()
  local path = 'sub/日本語\t"file\\name.lua' .. string.char(92) .. "123"
  H.git(root, "mv", "sub/file.lua", path)
  H.git(root, "commit", "-m", "quoted name")
  vim.fn.writefile({ "new line", "changed", "three" }, root .. "/" .. path)
  H.git(root, "commit", "-am", "quoted content")
  local commit = vim.trim(H.git(root, "rev-parse", "HEAD"))
  H.git(root, "mv", path, "sub/renamed.lua")
  H.git(root, "commit", "-m", "rename again")
  vim.cmd("GinBlame renamed.lua")
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("gin.blame").switch_commit()
  local parsed = require("gin.uri").parse(vim.api.nvim_buf_get_name(0))
  MiniTest.expect.equality({ parsed.params.commitish, parsed.fragment }, { commit, path })
  local file = vim.b.gin_blame_file_bufnr
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(file, 0, -1, false)[2], "new line")
  require("gin.blame").navigate_history("older")
  MiniTest.expect.equality(
    require("gin.uri").parse(vim.api.nvim_buf_get_name(0)).fragment,
    "sub/renamed.lua"
  )
  require("gin.blame").navigate_history("newer")
  MiniTest.expect.equality(require("gin.uri").parse(vim.api.nvim_buf_get_name(0)).fragment, path)
end
T["divider selection and an unavailable parent preserve the blame view"] = function()
  vim.cmd("GinBlame " .. first .. " file.lua")
  local file = vim.b.gin_blame_file_bufnr
  local name = vim.api.nvim_buf_get_name(file)
  local windows = vim.api.nvim_tabpage_list_wins(0)
  require("gin.blame").switch_commit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(file), name)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  MiniTest.expect.error(function()
    require("gin.blame").switch_commit()
  end, "git exited")
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(file), name)
  MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(file, 0, -1, false),
    { "", "one", "two", "three" }
  )
end
T["blame history restores filenames and positions in both directions"] = function()
  H.git(root, "mv", "sub/file.lua", "sub/renamed.lua")
  H.git(root, "commit", "-m", "rename")
  vim.cmd("GinBlame renamed.lua")
  local nav, file = vim.api.nvim_get_current_buf(), vim.b.gin_blame_file_bufnr
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  require("gin.blame").switch_commit()
  require("gin.blame").switch_commit()
  for _, case in ipairs({
    { "older", second, "sub/file.lua", 4 },
    { "older", "HEAD", "sub/renamed.lua", 4 },
    { "newer", second, "sub/file.lua", 4 },
    { "newer", second .. "^", "sub/file.lua", 3 },
  }) do
    vim.api.nvim_set_current_win(vim.fn.bufwinid(file))
    require("gin.blame").navigate_history(case[1])
    local parsed = require("gin.uri").parse(vim.api.nvim_buf_get_name(file))
    MiniTest.expect.equality({ parsed.params.commitish, parsed.fragment }, { case[2], case[3] })
    MiniTest.expect.equality(vim.api.nvim_get_current_buf(), file)
    for _, buf in ipairs({ file, nav }) do
      MiniTest.expect.equality(vim.api.nvim_win_get_cursor(vim.fn.bufwinid(buf))[1], case[4])
    end
  end
end
T["new blame selections truncate forward history and failures preserve it"] = function()
  vim.cmd("GinBlame file.lua")
  local nav = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  require("gin.blame").switch_commit()
  require("gin.blame").switch_commit()
  require("gin.blame").navigate_history("older")
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("gin.blame").switch_commit()
  local history = vim.b.gin_blame_history
  MiniTest.expect.equality(#history, 3)
  MiniTest.expect.equality(history[3].commitish, first)
  require("gin.blame").navigate_history("newer")
  MiniTest.expect.equality(
    require("gin.uri").parse(vim.api.nvim_buf_get_name(nav)).params.commitish,
    first
  )
  MiniTest.expect.error(function()
    require("gin.blame").switch_commit()
  end, "git exited")
  MiniTest.expect.equality(vim.b.gin_blame_history, history)
  MiniTest.expect.equality(vim.b.gin_blame_history_index, 3)
  require("gin.blame").navigate_history("older")
  MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0)[1], 2)
end
T["blame marks commit dividers and refreshes them after navigation"] = function()
  vim.cmd("GinBlame file.lua")
  local file, nav = vim.b.gin_blame_file_bufnr, vim.api.nvim_get_current_buf()
  local function dividers(buf)
    local rows = {}
    for _, sign in ipairs(vim.fn.sign_getplaced(buf, { group = "gin_blame" })[1].signs) do
      rows[#rows + 1] = sign.lnum
      MiniTest.expect.equality(sign.name, "GinBlameDividerSign")
    end
    table.sort(rows)
    return rows
  end
  for _, buf in ipairs({ file, nav }) do
    MiniTest.expect.equality(dividers(buf), { 1, 3, 5 })
  end
  vim.fn.sign_define("GinTestUnrelated", { text = "!" })
  vim.fn.sign_place(1, "gin_test_other", "GinTestUnrelated", file, { lnum = 2 })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("gin.blame").switch_commit()
  for _, buf in ipairs({ file, nav }) do
    MiniTest.expect.equality(dividers(buf), { 1 })
  end
  MiniTest.expect.equality(#vim.fn.sign_getplaced(file, { group = "gin_test_other" })[1].signs, 1)
  MiniTest.expect.equality(
    vim.fn.sign_getdefined("GinBlameDividerSign")[1].linehl,
    "GinBlameDivider"
  )
  MiniTest.expect.equality(
    vim.api.nvim_get_hl(0, { name = "GinBlameDivider", link = false }).strikethrough,
    true
  )
end
T["blame retains encoding and fileformat options through reload and history"] = function()
  vim.fn.writefile({ "caf" .. string.char(233) .. "\r", "second\r" }, root .. "/sub/file.lua")
  H.git(root, "commit", "--author=José <jose@example.invalid>", "-am", "latin1 content")
  vim.cmd("GinBlame ++enc=latin1 ++ff=dos file.lua")
  local file = vim.b.gin_blame_file_bufnr
  local function check()
    MiniTest.expect.equality(vim.b[file].gin_blame_line_map[2].metadata.author, "José")
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(file, 0, -1, false),
      { "", "café", "second" }
    )
    MiniTest.expect.equality(
      { vim.bo[file].fileencoding, vim.bo[file].fileformat },
      { "latin1", "dos" }
    )
  end
  check()
  vim.cmd.edit()
  check()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("gin.blame").switch_commit()
  check()
  require("gin.blame").navigate_history("older")
  check()
end

T["blame emojifies metadata while preserving literal source through history"] = function()
  vim.fn.writefile({ ":sparkles: source" }, root .. "/sub/file.lua")
  H.git(root, "commit", "-am", ":sparkles: message")
  local head = vim.trim(H.git(root, "rev-parse", "HEAD"))
  vim.cmd("GinBlame ++emojify file.lua")
  local function check()
    local file = vim.b.gin_blame_file_bufnr
    local detail = vim.b.gin_blame_detail_bufnr
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(file, 0, -1, false),
      { "", ":sparkles: source" }
    )
    MiniTest.expect.equality(
      table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("✨ message", 1, true)
        ~= nil,
      true
    )
    MiniTest.expect.equality(
      table
        .concat(vim.api.nvim_buf_get_lines(detail, 0, -1, false), "\n")
        :find("✨ message", 1, true) ~= nil,
      true
    )
  end
  check()
  vim.cmd.edit()
  check()
  require("gin.blame").update_detail(vim.api.nvim_get_current_buf(), 2)
  check()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("gin.blame").switch_commit()
  MiniTest.expect.equality(
    require("gin.uri").parse(vim.api.nvim_buf_get_name(0)).params.commitish,
    head
  )
  check()
  require("gin.blame").navigate_history("older")
  check()
end
T["blame detail emojifies only the summary and preserves author and body"] = function()
  vim.fn.writefile({ "latest" }, root .. "/sub/file.lua")
  H.git(
    root,
    "commit",
    "-am",
    ":sparkles: summary\n\nLiteral :smile: body\n:sparkles: another line",
    "--author=Literal :smile: Author <literal@example.invalid>"
  )
  local raw =
    require("gin.buffer").lines(H.git(root, "show", "--no-patch", "--format=fuller", "HEAD", "--"))
  local expected = vim.deepcopy(raw)
  for i, line in ipairs(expected) do
    if line == "    :sparkles: summary" then
      expected[i] = "    ✨ summary"
    end
  end
  vim.cmd("GinBlame ++emojify file.lua")
  local nav, detail = vim.api.nvim_get_current_buf(), vim.b.gin_blame_detail_bufnr
  local function check()
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(detail, 0, -1, false), expected)
  end
  check()
  require("gin.blame").update_detail(nav, 2)
  check()
  vim.cmd.edit()
  check()
end
T["blame uses edit argument settings with explicit arguments replacing defaults"] = function()
  local defaults = { first, "file.lua" }
  local persistent = { "++opener=split", "++enc=utf-8" }
  vim.g.gin_edit_default_args = defaults
  vim.g.gin_edit_persistent_args = persistent
  local tabs = #vim.api.nvim_list_tabpages()
  for _, case in ipairs({
    { "GinBlame", first, "two" },
    { "GinBlame HEAD file.lua", "HEAD", "changed" },
  }) do
    vim.cmd(case[1])
    local file = vim.b.gin_blame_file_bufnr
    local parsed = require("gin.uri").parse(vim.api.nvim_buf_get_name(file))
    MiniTest.expect.equality(parsed.params.commitish, case[2])
    MiniTest.expect.equality(parsed.params.enc, "utf-8")
    MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs)
    MiniTest.expect.equality(
      vim.tbl_contains(vim.api.nvim_buf_get_lines(file, 0, -1, false), case[3]),
      true
    )
  end
  MiniTest.expect.equality(vim.g.gin_edit_default_args, defaults)
  MiniTest.expect.equality(vim.g.gin_edit_persistent_args, persistent)
end
T["blame panes reject unrelated buffers across reload and history navigation"] = function()
  vim.fn.writefile({ "unrelated" }, root .. "/other")
  vim.cmd("GinBlame file.lua")
  local nav, file = vim.api.nvim_get_current_buf(), vim.b.gin_blame_file_bufnr
  local function check()
    for _, buf in ipairs({ nav, file }) do
      local win = vim.fn.bufwinid(buf)
      vim.api.nvim_win_call(win, function()
        MiniTest.expect.error(function()
          vim.cmd.edit(root .. "/other")
        end, "winfixbuf")
        MiniTest.expect.equality(vim.api.nvim_get_current_buf(), buf)
      end)
    end
  end
  check()
  vim.cmd.edit()
  check()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("gin.blame").switch_commit()
  check()
  require("gin.blame").navigate_history("older")
  check()
end
T["blame reload decoding overrides work from either synchronized pane"] = function()
  vim.fn.writefile({ "café\r" }, root .. "/sub/file.lua")
  H.git(root, "commit", "--author=José <jose@example.invalid>", "-am", "UTF-8 source")
  vim.cmd("GinBlame ++enc=latin1 ++ff=dos file.lua")
  local file, nav = vim.b.gin_blame_file_bufnr, vim.b.gin_blame_nav_bufnr
  local file_name, nav_name = vim.api.nvim_buf_get_name(file), vim.api.nvim_buf_get_name(nav)
  for _, target in ipairs({ file, nav }) do
    vim.api.nvim_set_current_win(vim.fn.bufwinid(target))
    vim.cmd("edit ++encoding=utf-8 ++fileformat=unix")
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(file, 0, -1, false), { "", "café\r" })
    for _, buf in ipairs({ file, nav }) do
      MiniTest.expect.equality(
        { vim.bo[buf].fileencoding, vim.bo[buf].fileformat },
        { "utf-8", "unix" }
      )
      MiniTest.expect.equality(vim.b[buf].gin_blame_line_map[2].metadata.author, "José")
    end
    MiniTest.expect.equality(vim.api.nvim_buf_get_name(file), file_name)
    MiniTest.expect.equality(vim.api.nvim_buf_get_name(nav), nav_name)
    vim.cmd.edit()
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(file, 0, -1, false), { "", "cafÃ©" })
    MiniTest.expect.equality(
      { vim.bo[file].fileencoding, vim.bo[file].fileformat },
      { "latin1", "dos" }
    )
  end
end
return T
