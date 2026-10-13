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
      vim.cmd.tabonly({ bang = true })
      vim.cmd.only({ bang = true })
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
return T
