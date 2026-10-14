local enabled
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      enabled = vim.g.syntax_on ~= nil
      vim.cmd("syntax enable")
      vim.cmd.enew()
    end,
    post_case = function()
      vim.cmd.bwipeout({ bang = true })
      if not enabled then
        vim.cmd("syntax off")
      end
    end,
  },
})
T["default syntax highlight attributes match the pinned definitions"] = function()
  local root = vim.fn.getcwd()
  local files, groups = {}, {}
  for _, path in ipairs(vim.fn.glob(root .. "/.deps/vim-gin/syntax/*.vim", false, true)) do
    files[#files + 1] = vim.fn.fnamemodify(path, ":t:r")
    for _, line in ipairs(vim.fn.readfile(path)) do
      local name = line:match("^highlight%s+default%s+link%s+(Gin%S+)")
        or line:match("^highlight%s+link%s+(Gin%S+)")
        or line:match("^highlight%s+(Gin%S+)")
      if name then
        groups[#groups + 1] = name
      end
    end
  end
  MiniTest.expect.equality(#files, 4)
  MiniTest.expect.equality(#groups, 16)
  local function inspect(directory, extension)
    local script = ([=[
      local ok, err = pcall(function()
        vim.opt.runtimepath:prepend(%q)
        local data = vim.json.decode(%q)
        for _, name in ipairs(data.files) do
          vim.cmd.enew({bang=true})
          vim.cmd.source(data.directory .. '/syntax/' .. name .. data.extension)
        end
        local result = {}
        for _, name in ipairs(data.groups) do
          local attrs = vim.api.nvim_get_hl(0, {name=name})
          -- Default-only installation deliberately preserves user overrides in Lua.
          attrs.default = nil
          if type(attrs.cterm) == 'table' and next(attrs.cterm) == nil then attrs.cterm = nil end
          result[name] = attrs
        end
        io.stdout:write(vim.json.encode(result))
      end)
      if not ok then io.stderr:write(tostring(err)); vim.cmd('cquit 1') end
    ]=]):format(
      root,
      vim.json.encode({
        files = files,
        groups = groups,
        directory = directory,
        extension = extension,
      })
    )
    local result = vim
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
    assert(result.code == 0, result.stderr)
    return vim.json.decode(result.stdout)
  end
  MiniTest.expect.equality(inspect(root, ".lua"), inspect(root .. "/.deps/vim-gin", ".vim"))
end
for kind, spec in pairs({
  tag = {
    line = "abcdef012 release 2026-10-14 release notes",
    groups = { abcdef012 = "Hash", release = "Name", ["2026-10-14"] = "Date", notes = "Subject" },
  },
  stash = {
    line = "stash@{12}: WIP on topic: abcdef012 changes",
    groups = { ["stash@{12}"] = "Ref", WIP = "Type", topic = "Branch", abcdef012 = "Hash" },
  },
  reflog = {
    line = "abcdef012 (HEAD -> main) HEAD@{12}: commit: changes",
    groups = { abcdef012 = "Hash", main = "Deco", ["HEAD@{12}"] = "Selector", commit = "Action" },
  },
}) do
  T[kind .. " syntax identifies native list fields"] = function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { spec.line })
    vim.bo.syntax = "gin-" .. kind
    vim.cmd("redraw!")
    for text, suffix in pairs(spec.groups) do
      local column = assert(spec.line:find(text, 1, true))
      MiniTest.expect.equality(
        vim.fn.synIDattr(vim.fn.synID(1, column, 1), "name"),
        "Gin" .. kind:gsub("^%l", string.upper) .. suffix
      )
    end
    MiniTest.expect.equality(vim.b.current_syntax, "gin_" .. kind)
  end
end
T["blame navigation highlights line time author and summary"] = function()
  local times = { "just now", "2 days ago", "in 3 months" }
  local lines = {}
  for _, time in ipairs(times) do
    lines[#lines + 1] = " 12 " .. time .. "\tGin Test\tcommit summary"
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.syntax = "gin-blame-nav"
  vim.cmd("redraw!")
  for row, line in ipairs(lines) do
    for text, suffix in pairs({
      ["12"] = "LineNumber",
      [times[row]] = "Time",
      ["Gin Test"] = "Author",
      ["commit summary"] = "Summary",
    }) do
      MiniTest.expect.equality(
        vim.fn.synIDattr(vim.fn.synID(row, assert(line:find(text, 1, true)), 1), "name"),
        "GinBlame" .. suffix
      )
    end
  end
  MiniTest.expect.equality(vim.b.current_syntax, "gin_blame_nav")
  MiniTest.expect.equality(vim.api.nvim_get_hl(0, { name = "GinBlameTime" }).fg, 0x87afaf)
  local author = vim.api.nvim_get_hl(0, { name = "GinBlameAuthor" })
  MiniTest.expect.equality({ author.fg, author.bold, author.ctermfg }, { 0xffaf5f, true, 215 })
end
T["list syntax retains user highlights across syntax reloads"] = function()
  local previous = vim.api.nvim_get_hl(0, { name = "GinTagName" })
  vim.api.nvim_set_hl(0, "GinTagName", { fg = 0x123456, bold = true })
  local ok, err = pcall(function()
    for _ = 1, 2 do
      vim.bo.syntax = "gin-tag"
      local attrs = vim.api.nvim_get_hl(0, { name = "GinTagName", link = false })
      MiniTest.expect.equality({ attrs.fg, attrs.bold }, { 0x123456, true })
      vim.bo.syntax = "OFF"
    end
  end)
  vim.api.nvim_set_hl(0, "GinTagName", previous)
  assert(ok, err)
end
T["default syntax links survive a colorscheme reload"] = function()
  vim.bo.syntax = "gin-tag"
  vim.cmd("colorscheme default")
  for group, target in pairs({
    GinTagHash = "Constant",
    GinTagName = "Special",
    GinTagDate = "Title",
    GinTagSubject = "Comment",
  }) do
    MiniTest.expect.equality(vim.api.nvim_get_hl(0, { name = group }).link, target)
  end
end
T["blame navigation colors survive a colorscheme reload"] = function()
  dofile(vim.fn.getcwd() .. "/plugin/gin.lua")
  vim.bo.syntax = "gin-blame-nav"
  vim.cmd("colorscheme default")
  MiniTest.expect.equality(vim.api.nvim_get_hl(0, { name = "GinBlameTime" }).fg, 0x87afaf)
  local author = vim.api.nvim_get_hl(0, { name = "GinBlameAuthor" })
  MiniTest.expect.equality({ author.fg, author.bold }, { 0xffaf5f, true })
  vim.api.nvim_set_hl(0, "GinBlameAuthor", { fg = 0x123456 })
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "custom-theme" })
    MiniTest.expect.equality(vim.api.nvim_get_hl(0, { name = "GinBlameAuthor" }).fg, 0x123456)
  end)
  vim.api.nvim_set_hl(0, "GinBlameAuthor", author)
  assert(ok, err)
end
return T
