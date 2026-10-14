local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local events
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.cmd.cd(root)
      events = 0
      vim.api.nvim_create_autocmd("User", {
        pattern = "GinCommandPost",
        group = vim.api.nvim_create_augroup("gin_test", { clear = true }),
        callback = function()
          events = events + 1
        end,
      })
      dofile(old_cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
      vim.api.nvim_del_augroup_by_name("gin_test")
    end,
  },
})
local function expect_command_error(command, pattern)
  local echo, message = vim.api.nvim_echo, nil
  vim.api.nvim_echo = function(chunks)
    if chunks[1][2] == "ErrorMsg" then
      message = chunks[1][1]
    end
  end
  local ok, err = pcall(vim.cmd, command)
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(type(message), "string")
  MiniTest.expect.equality(message:find(pattern) ~= nil, true)
end

T["successful command bursts publish one deferred completion event"] = function()
  local command = require("gin.command")
  for _ = 1, 3 do
    command.finish({ code = 0, stdout = "", stderr = "" }, {}, { silent = true })
  end
  MiniTest.expect.equality(events, 0)
  MiniTest.expect.equality(
    vim.wait(1000, function()
      return events == 1
    end, 10),
    true
  )
  command.finish({ code = 0, stdout = "", stderr = "" }, {}, { silent = true })
  MiniTest.expect.equality(events, 1)
  MiniTest.expect.equality(
    vim.wait(1000, function()
      return events == 2
    end, 10),
    true
  )
end
T["Gin wait executes a Git command and emits its completion event"] = function()
  vim.fn.writefile({ "literal" }, root .. "/space name")
  vim.cmd([[Gin ++wait add -- space\ name]])
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "space name\n")
  H.drain()
  MiniTest.expect.equality(events, 1)
end
T["Gin dispatches asynchronously unless wait is requested"] = function()
  vim.fn.writefile({ "async" }, root .. "/async")
  local process = require("gin.command").execute({ fargs = { "add", "--", "async" }, smods = {} })
  MiniTest.expect.equality(type(process.wait), "function")
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return events == 1
    end),
    true
  )
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "async\n")
end
T["Gin expands current file and respects silent"] = function()
  vim.fn.writefile({ "text" }, root .. "/file")
  vim.cmd.edit(vim.fn.fnameescape(root .. "/file"))
  vim.cmd("silent Gin ++wait add -- %:p")
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "file\n")
end
T["Gin recognizes separators produced by filename expansion"] = function()
  vim.fn.writefile({ "separator" }, root .. "/--")
  vim.fn.writefile({ "literal" }, root .. "/++unknown")
  vim.cmd.edit(root .. "/--")
  vim.cmd("Gin ++wait add %:t ++unknown")
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), "++unknown\0")
end
T["Gin treats plus-prefixed paths after the separator as literal arguments"] = function()
  local paths = { "++unknown", "++worktree=elsewhere" }
  for _, path in ipairs(paths) do
    vim.fn.writefile({ "literal" }, root .. "/" .. path)
  end
  vim.cmd("Gin ++wait add -- " .. table.concat(paths, " "))
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), table.concat(paths, "\0") .. "\0")
end
T["plus-prefixed paths outside the option grammar remain Git arguments"] = function()
  local paths = { "++", "++=file", "++_file", "++日本語" }
  for _, path in ipairs(paths) do
    vim.fn.writefile({ "literal" }, root .. "/" .. path)
  end
  vim.cmd("Gin ++wait add " .. table.concat(paths, " "))
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), table.concat(paths, "\0") .. "\0")
end
T["Gin consumes every bare wait token before parsing options"] = function()
  for _, args in ipairs({ "++wait ++wait", "++wait", "" }) do
    H.git(root, "read-tree", "--empty")
    vim.fn.writefile({ "literal" }, root .. "/file")
    vim.fn.writefile({ "literal" }, root .. "/++wait")
    vim.cmd("Gin " .. args .. " add -- file ++wait")
    MiniTest.expect.equality(H.git(root, "ls-files"), "file\n")
  end
end
T["bare worktree options use the current repository"] = function()
  vim.fn.writefile({ "content" }, root .. "/file")
  vim.cmd("Gin ++wait ++worktree add -- file")
  MiniTest.expect.equality(H.git(root, "show", ":file"), "content\n")
end
T["Gin option values stop at ECMAScript line terminators"] = function()
  for i, separator in ipairs({ "\n", "\r", "\226\128\168", "\226\128\169" }) do
    local content = "version " .. i .. "\n"
    vim.fn.writefile({ "version " .. i }, root .. "/file")
    require("gin.command").execute({
      fargs = { "++wait", "++worktree=" .. root .. separator .. "ignored", "add", "--", "file" },
      smods = {},
    })
    MiniTest.expect.equality(H.git(root, "show", ":file"), content)
  end
end
T["duplicate Gin options fail before executing Git"] = function()
  vim.fn.writefile({ "literal" }, root .. "/file")
  expect_command_error(
    "Gin ++wait ++worktree=. ++worktree=. add -- file",
    "Duplicate Gin option: %+%+worktree"
  )
  MiniTest.expect.equality(H.git(root, "ls-files"), "")
  MiniTest.expect.equality(events, 0)
end
T["failed Gin does not publish a success event"] = function()
  expect_command_error("Gin ++wait not-a-git-command", "not%-a%-git%-command")
  MiniTest.expect.equality(events, 0)
end
T["directory commands use buffer repository and honor local scope"] = function()
  vim.fn.mkdir(root .. "/sub", "p")
  vim.fn.writefile({ "text" }, root .. "/sub/file")
  vim.cmd.cd(old_cwd)
  vim.cmd.edit(vim.fn.fnameescape(root .. "/sub/file"))
  vim.cmd.GinLcd()
  MiniTest.expect.equality(vim.fn.getcwd(), vim.uv.fs_realpath(root))
  MiniTest.expect.equality(vim.fn.haslocaldir(), 1)
end
T["directory commands warn without changing scope outside a repository"] = function()
  vim.cmd.enew()
  vim.fn.delete(root .. "/.git", "rf")
  local directory, scope = vim.fn.getcwd(), vim.fn.haslocaldir()
  local echo, messages = vim.api.nvim_echo, {}
  vim.api.nvim_echo = function(chunks)
    messages[#messages + 1] = chunks
  end
  local ok, err = pcall(function()
    for _, command in ipairs({ "GinCd", "GinLcd", "GinTcd" }) do
      vim.cmd[command]()
      MiniTest.expect.equality({ vim.fn.getcwd(), vim.fn.haslocaldir() }, { directory, scope })
    end
  end)
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(messages, {
    { { "[gin] no git repository found", "WarningMsg" } },
    { { "[gin] no git repository found", "WarningMsg" } },
    { { "[gin] no git repository found", "WarningMsg" } },
  })
end
T["Gin wait returns processed output and rejects processor failures"] = function()
  vim.fn.writefile({ "text" }, root .. "/file")
  local result = require("gin.command").execute({
    fargs = { "++wait", "++processor=tr a-z A-Z", "status", "--short" },
    smods = { silent = true },
  })
  MiniTest.expect.equality(result.stdout, "?? FILE\n")
  H.drain()
  MiniTest.expect.equality(events, 1)
  expect_command_error("Gin ++wait ++processor=false status", "%[gin%]:")
  H.drain()
  MiniTest.expect.equality(events, 1)
end
T["asynchronous Gin waits for processor completion before publishing success"] = function()
  vim.fn.writefile({ "text" }, root .. "/file")
  local command = require("gin.command")
  local original, received = command.finish, nil
  command.finish = function(result, options, mods)
    received = result.stdout
    return original(result, options, mods)
  end
  local ok, err = pcall(function()
    command.execute({
      fargs = { "++processor=tr a-z A-Z", "status", "--short" },
      smods = { silent = true },
    })
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return events == 1
      end),
      true
    )
  end)
  command.finish = original
  assert(ok, err)
  MiniTest.expect.equality(received, "?? FILE\n")
end
T["asynchronous processor failures report errors without success events"] = function()
  local original, received = vim.notify, nil
  vim.notify = function(message)
    received = message
  end
  local ok, err = pcall(function()
    require("gin.command").execute({ fargs = { "++processor=false", "status" }, smods = {} })
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return received ~= nil
      end),
      true
    )
  end)
  vim.notify = original
  assert(ok, err)
  MiniTest.expect.equality(received:find("processor exited", 1, true) ~= nil, true)
  MiniTest.expect.equality(events, 0)
end

T["Unicode command display removes only the leading byte order mark"] = function()
  local bom = "\239\187\191"
  local text = bom .. "first" .. bom .. "second\n"
  for _, encoding in ipairs({ "", "utf-8", "utf-16le", "utf-16be" }) do
    local data = text
    if encoding == "utf-16le" or encoding == "utf-16be" then
      local units = {}
      for _, code in ipairs(vim.fn.str2list(text, true)) do
        local low, high = code % 256, math.floor(code / 256)
        units[#units + 1] = encoding == "utf-16le" and string.char(low, high)
          or string.char(high, low)
      end
      data = table.concat(units)
    end
    local fd = assert(vim.uv.fs_open(root .. "/file", "w", 420))
    assert(vim.uv.fs_write(fd, data, 0))
    assert(vim.uv.fs_close(fd))
    H.git(root, "add", "file")
    local echo, displayed = vim.api.nvim_echo, nil
    vim.api.nvim_echo = function(chunks)
      displayed = chunks[1][1]
    end
    local args = { "++wait", "show", ":file" }
    if encoding ~= "" then
      table.insert(args, 1, "++enc=" .. encoding)
    end
    local ok, result = pcall(require("gin.command").execute, {
      fargs = args,
      smods = {},
    })
    vim.api.nvim_echo = echo
    assert(ok, result)
    MiniTest.expect.equality(displayed, "first" .. bom .. "second\n")
    MiniTest.expect.equality(result.stdout, data)
  end
end

for _, spec in ipairs({
  { option = "++ff=unix", expected = "first\r\nsecond\r\n" },
  { option = "++fileformat=unix", expected = "first\r\nsecond\r\n" },
  { option = "++ff=dos", expected = "first\nsecond\n" },
  { option = "++ff=mac", expected = "first\n\nsecond\n\n" },
  { option = "", expected = "first\nsecond\n" },
}) do
  for _, wait in ipairs({ false, true }) do
    T["command output decoding " .. spec.option .. " wait=" .. tostring(wait)] = function()
      vim.fn.writefile({ "first\r", "second\r" }, root .. "/file")
      H.git(root, "add", "file")
      local echo = vim.api.nvim_echo
      local output
      vim.api.nvim_echo = function(chunks)
        output = chunks[1][1]
      end
      local ok, err = pcall(function()
        local args = { "show", ":file" }
        if spec.option ~= "" then
          table.insert(args, 1, spec.option)
        end
        if wait then
          table.insert(args, 1, "++wait")
        end
        require("gin.command").execute({ fargs = args, smods = {} })
        MiniTest.expect.equality(
          vim.wait(5000, function()
            return events == 1
          end, 10),
          true
        )
        MiniTest.expect.equality(output, spec.expected)
      end)
      vim.api.nvim_echo = echo
      assert(ok, err)
    end
  end
end

for _, view in ipairs({ "GinDiff", "GinLog --oneline" }) do
  for _, absolute in ipairs({ false, true }) do
    T["filename expansion from " .. view .. " absolute=" .. tostring(absolute)] = function()
      vim.fn.writefile({ "base" }, root .. "/one space")
      vim.fn.writefile({ "base" }, root .. "/two")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      vim.fn.writefile({ "changed" }, root .. "/one space")
      vim.fn.writefile({ "changed" }, root .. "/two")
      local path = absolute and (root .. "/one space") or "one space"
      vim.cmd(view .. " -- " .. vim.fn.fnameescape(path) .. " two")
      vim.cmd("Gin ++wait add -- %")
      MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "one space\n")
      MiniTest.expect.equality(H.git(root, "show", ":one space"), "changed\n")
      MiniTest.expect.equality(H.git(root, "show", ":two"), "base\n")
    end
  end
end

for _, view in ipairs({ "GinDiff", "GinLog --oneline" }) do
  T[view .. " keeps repository-relative filters and alternate filename expansion"] = function()
    vim.fn.writefile({ "root base" }, root .. "/file")
    H.git(root, "add", "file")
    H.git(root, "commit", "-m", "root file")
    local first = vim.trim(H.git(root, "rev-parse", "HEAD"))
    vim.fn.mkdir(root .. "/sub", "p")
    vim.fn.writefile({ "sub base" }, root .. "/sub/file")
    H.git(root, "add", "sub/file")
    H.git(root, "commit", "-m", "sub file")
    vim.fn.writefile({ "root changed" }, root .. "/file")
    vim.fn.writefile({ "sub changed" }, root .. "/sub/file")
    vim.cmd.cd(root .. "/sub")
    vim.cmd(view .. " -- file")
    vim.cmd.edit()
    if view == "GinDiff" then
      local output = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
      MiniTest.expect.equality(output:find("+root changed", 1, true) ~= nil, true)
      MiniTest.expect.equality(output:find("sub changed", 1, true), nil)
    else
      local rows = require("gin.log").candidates(0, { 1, 99 })
      MiniTest.expect.equality(#rows, 1)
      MiniTest.expect.equality(rows[1].commit, first:sub(1, #rows[1].commit))
    end
    vim.cmd.enew()
    vim.cmd("Gin ++wait add -- #")
    MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "file\n")
    MiniTest.expect.equality(H.git(root, "show", ":file"), "root changed\n")
    MiniTest.expect.equality(H.git(root, "show", ":sub/file"), "sub base\n")
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), { "sub changed" })
  end
end
T["Gin wait displays progress while Git is still running"] = function()
  local echo, live = vim.api.nvim_echo, false
  local more, height = vim.o.more, vim.o.cmdheight
  vim.api.nvim_echo = function(chunks, history)
    if not history and chunks[1][1] == "waiting" then
      live = true
      vim.fn.writefile({}, root .. "/.git/release")
    end
  end
  local ok, result = pcall(require("gin.command").execute, {
    fargs = {
      "++wait",
      "-c",
      [[alias.progress=!printf 'waiting\n'; n=0; while test ! -f .git/release; do n=$((n+1)); test "$n" -lt 200 || exit 1; sleep 0.01; done; printf 'finished\n']],
      "progress",
    },
    smods = {},
  })
  vim.api.nvim_echo = echo
  MiniTest.expect.equality(ok, true)
  MiniTest.expect.equality(live, true)
  MiniTest.expect.equality(result.stdout, "waiting\nfinished\n")
  H.drain()
  MiniTest.expect.equality(events, 1)
  MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { more, height })
end
T["Gin displays progress before exit and retains final output"] = function()
  local echo, output = vim.api.nvim_echo, {}
  local more, height = vim.o.more, vim.o.cmdheight
  vim.api.nvim_echo = function(chunks, history)
    output[#output + 1] = { text = chunks[1][1], history = history }
  end
  local ok, err = pcall(function()
    local process = require("gin.command").execute({
      fargs = {
        "-c",
        [[alias.progress=!printf 'early\n'; printf 'warning\n' >&2; while test ! -f .git/release; do sleep 0.01; done; printf 'finished\n']],
        "progress",
      },
      smods = {},
    })
    local live = vim.wait(1000, function()
      for _, item in ipairs(output) do
        if not item.history and item.text:find("early", 1, true) then
          return true
        end
      end
      return false
    end, 10)
    local pending = not process:is_closing()
    vim.fn.writefile({}, root .. "/.git/release")
    local result = process:wait(5000)
    MiniTest.expect.equality(
      vim.wait(1000, function()
        return events == 1
      end, 10),
      true
    )
    MiniTest.expect.equality(live, true)
    MiniTest.expect.equality(pending, true)
    MiniTest.expect.equality(result.stdout, "early\nfinished\n")
    MiniTest.expect.equality(result.stderr, "warning\n")
    MiniTest.expect.equality(
      output[#output],
      { text = "early\nfinished\nwarning\n", history = false }
    )
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { more, height })
  end)
  vim.api.nvim_echo = echo
  assert(ok, err)
end
T["silent asynchronous commands do not display progress"] = function()
  local echo, calls = vim.api.nvim_echo, 0
  vim.api.nvim_echo = function()
    calls = calls + 1
  end
  local ok, err = pcall(function()
    local process = require("gin.command").execute({
      fargs = { "-c", "alias.progress=!printf 'quiet\\n'", "progress" },
      smods = { silent = true },
    })
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return events == 1
      end, 10),
      true
    )
    MiniTest.expect.equality(process:wait(1000).stdout, "quiet\n")
    MiniTest.expect.equality(calls, 0)
  end)
  vim.api.nvim_echo = echo
  assert(ok, err)
end
T["concurrent progress indicators restore options after the last close"] = function()
  local indicator = require("gin.indicator")
  local more, height = vim.o.more, vim.o.cmdheight
  vim.o.more, vim.o.cmdheight = true, 1
  local first, second = indicator.open(), indicator.open()
  local ok, err = pcall(function()
    first.write(nil, "one\ntwo\nthree\n")
    MiniTest.expect.equality(
      vim.wait(1000, function()
        return vim.o.cmdheight == 3
      end, 10),
      true
    )
    first.close()
    MiniTest.expect.equality(vim.o.more, false)
    MiniTest.expect.equality(
      vim.wait(1000, function()
        return vim.o.cmdheight == 1
      end, 10),
      true
    )
    second.close()
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { true, 1 })
    first.close()
    first.write(nil, "stale\nmessage\n")
    local drained = false
    vim.schedule(function()
      drained = true
    end)
    MiniTest.expect.equality(
      vim.wait(1000, function()
        return drained
      end, 10),
      true
    )
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { true, 1 })
  end)
  first.close()
  second.close()
  vim.o.more, vim.o.cmdheight = more, height
  assert(ok, err)
end
T["asynchronous commands retain eventignore all from dispatch"] = function()
  local previous = vim.o.eventignore
  vim.o.eventignore = "all"
  local result
  local ok, err = pcall(function()
    require("gin.command").execute({
      fargs = { "config", "gin.event-test", "written" },
      smods = { silent = true },
      on_exit = function(value)
        result = value
      end,
    })
  end)
  vim.o.eventignore = previous
  assert(ok, err)
  MiniTest.expect.equality(
    vim.wait(3000, function()
      return result ~= nil
    end, 10),
    true
  )
  MiniTest.expect.equality(result.code, 0)
  MiniTest.expect.equality(H.git(root, "config", "gin.event-test"), "written\n")
  MiniTest.expect.equality(events, 0)
end
for _, wait in ipairs({ true, false }) do
  T[(wait and "waiting" or "asynchronous") .. " command errors omit color codes"] = function()
    local notify, message = vim.notify, nil
    vim.notify = function(text)
      message = text
    end
    local ok, result = pcall(require("gin.command").execute, {
      fargs = vim.list_extend(wait and { "++wait" } or {}, {
        "-c",
        [[alias.fail=!printf '\033[2K\033[31mbroken\033[m\n' >&2; exit 7]],
        "fail",
      }),
      smods = { silent = true },
    })
    if not wait and ok then
      vim.wait(3000, function()
        return message ~= nil
      end, 10)
    end
    vim.notify = notify
    MiniTest.expect.equality(ok, not wait)
    MiniTest.expect.equality(wait and result or message, "git exited 7: broken")
    MiniTest.expect.equality(events, 0)
  end
end
T["Gin processors receive no implicit process deadline"] = function()
  local system, deadline = vim.system, nil
  vim.system = function(args, opts, callback)
    if args[1] == "cat" then
      deadline = opts.timeout or false
    end
    return system(args, opts, callback)
  end
  local ok, result = pcall(require("gin.command").execute, {
    fargs = { "++wait", "++processor=cat", "--version" },
    smods = { silent = true },
  })
  vim.system = system
  assert(ok, result)
  MiniTest.expect.equality(result.code, 0)
  MiniTest.expect.equality(deadline, false)
  H.drain()
  MiniTest.expect.equality(events, 1)
end
T["successful command output leaves message history unchanged"] = function()
  vim.api.nvim_echo({ { "prior message", "None" } }, true, {})
  local before = vim.api.nvim_exec2("messages", { output = true }).output
  require("gin.command").finish(
    { code = 0, stdout = "command result\n", stderr = "" },
    { eventignore_all = true },
    {}
  )
  MiniTest.expect.equality(vim.api.nvim_exec2("messages", { output = true }).output, before)
end
T["command display preserves the final newline"] = function()
  local echo, displayed = vim.api.nvim_echo, nil
  vim.api.nvim_echo = function(chunks)
    displayed = chunks[1][1]
  end
  local ok, err = pcall(
    require("gin.command").finish,
    { code = 0, stdout = "output\n", stderr = "" },
    { eventignore_all = true },
    {}
  )
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(displayed, "output\n")
end
T["command display replaces malformed Shift_JIS and retains ASCII"] = function()
  local echo, displayed = vim.api.nvim_echo, nil
  vim.api.nvim_echo = function(chunks)
    displayed = chunks[1][1]
  end
  local ok, err = pcall(
    require("gin.command").finish,
    { code = 0, stdout = string.char(130, 34), stderr = "" },
    { enc = "sjis", eventignore_all = true },
    {}
  )
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(displayed, '�"')
end
for _, case in ipairs({
  { "default malformed UTF-8", nil, { 255, 65 }, "�A" },
  { "UTF-16 alias", "utf-16", { 65, 0 }, "A" },
  { "UTF-16 partial unit", "utf-16le", { 65 }, "�" },
  { "Latin-1 alias", "latin1", { 128 }, "€" },
  { "Big5 ASCII recovery", "big5", { 129, 34 }, '�"' },
  { "EUC-JP triple recovery", "euc-jp", { 143, 162, 32 }, "� " },
  { "ISO-2022-JP escape recovery", "iso-2022-jp", { 27, 36, 32 }, "�$ " },
  { "GB18030 suffix recovery", "gb18030", { 129, 48, 129, 32 }, "�0� " },
}) do
  T["command display " .. case[1]] = function()
    local echo, displayed = vim.api.nvim_echo, nil
    vim.api.nvim_echo = function(chunks)
      displayed = chunks[1][1]
    end
    local bytes = string.char(unpack(case[3]))
    local result = { code = 0, stdout = bytes, stderr = "" }
    local ok, returned = pcall(
      require("gin.command").finish,
      result,
      { encoding = case[2], eventignore_all = true },
      {}
    )
    vim.api.nvim_echo = echo
    assert(ok, returned)
    MiniTest.expect.equality(displayed, case[4])
    MiniTest.expect.equality(returned, result)
    MiniTest.expect.equality(result.stdout, bytes)
  end
end
T["command decodes concatenated stdout and stderr as one sequence"] = function()
  local echo, displayed = vim.api.nvim_echo, nil
  vim.api.nvim_echo = function(chunks)
    displayed = chunks[1][1]
  end
  local ok, err = pcall(
    require("gin.command").finish,
    { code = 0, stdout = string.char(226), stderr = string.char(130, 172) },
    { eventignore_all = true },
    {}
  )
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(displayed, "€")
end
for _, encoding in ipairs({ "", "ucs-2le", "made-up" }) do
  T["unsupported command encoding does not publish success: " .. encoding] = function()
    local command = require("gin.command")
    MiniTest.expect.error(function()
      command.finish({ code = 0, stdout = "A", stderr = "" }, { enc = encoding }, { silent = true })
    end, "Unsupported encoding")
    MiniTest.expect.equality(command.post_pending(), false)
    MiniTest.expect.equality(events, 0)
  end
end
for _, wait in ipairs({ false, true }) do
  T["unsupported command encoding reports failure without events, wait=" .. tostring(wait)] = function()
    local notify, message = vim.notify, nil
    vim.notify = function(value)
      message = value
    end
    local args = { "++enc=ucs-2le", "status", "--short" }
    if wait then
      table.insert(args, 1, "++wait")
    end
    local ok, err = pcall(require("gin.command").execute, { fargs = args, smods = {} })
    if not wait then
      local completed = vim.wait(5000, function()
        return message ~= nil
      end, 10)
      vim.notify = notify
      MiniTest.expect.equality(completed, true)
      MiniTest.expect.equality(ok, true)
    else
      vim.notify = notify
      MiniTest.expect.equality(ok, false)
      message = tostring(err)
    end
    MiniTest.expect.equality(message:find("Unsupported encoding: ucs-2le", 1, true) ~= nil, true)
    MiniTest.expect.equality(require("gin.command").post_pending(), false)
    MiniTest.expect.equality(events, 0)
  end
end
T["final command display formats NUL and trailing newline as a Blob"] = function()
  local echo, displayed = vim.api.nvim_echo, nil
  vim.api.nvim_echo = function(chunks)
    displayed = chunks[1][1]
  end
  local ok, err = pcall(
    require("gin.command").finish,
    { code = 0, stdout = "A\0\nB\n", stderr = "" },
    { eventignore_all = true },
    {}
  )
  vim.api.nvim_echo = echo
  assert(ok, err)
  assert(displayed == "0z41000A42.0A", "Unexpected final display: " .. vim.inspect(displayed))
end
for _, case in ipairs({
  { "single NUL", "\0", nil, "0z00" },
  { "ANSI", "\27[31mA\0B\27[0m\n", nil, "0z4100420A" },
  { "DOS", "A\0\r\nB\r\n", "dos", "0z41000A42.0A" },
  { "Mac", "A\0\rB\r", "mac", "0z41000A42.0A" },
  { "Unix", "A\0\r\nB\r\n", "unix", "0z41000D0A.420D0A" },
  { "BOM", "\239\187\191A\0B\n", nil, "0z4100420A" },
  { "Japanese", "日\0本\n", nil, "0zE697A500.E69CAC0A" },
}) do
  T["final NUL display normalizes " .. case[1] .. " before Blob conversion"] = function()
    local echo, displayed = vim.api.nvim_echo, nil
    vim.api.nvim_echo = function(chunks)
      displayed = chunks[1][1]
    end
    local result = { code = 0, stdout = case[2], stderr = "" }
    local ok, returned = pcall(
      require("gin.command").finish,
      result,
      { ff = case[3], eventignore_all = true },
      {}
    )
    vim.api.nvim_echo = echo
    assert(ok, returned)
    assert(displayed == case[4], "Unexpected final display: " .. vim.inspect(displayed))
    assert(returned == result and returned.stdout == case[2], "Raw result was changed")
  end
end
T["Gin wait reports failure without throwing from the user command"] = function()
  local echo, messages = vim.api.nvim_echo, {}
  vim.api.nvim_echo = function(chunks)
    messages[#messages + 1] = chunks[1][1]
  end
  local ok = pcall(vim.cmd, "Gin ++wait not-a-git-command")
  vim.api.nvim_echo = echo
  MiniTest.expect.equality(ok, true)
  MiniTest.expect.equality(events, 0)
  MiniTest.expect.equality(messages[#messages]:find("[gin]:", 1, true) ~= nil, true)
end
for _, modifier in ipairs({ "", "silent ", "silent! " }) do
  for _, wait in ipairs({ false, true }) do
    for _, fail in ipairs({ false, true }) do
      T["Gin modifier " .. modifier .. " wait=" .. tostring(wait) .. " failure=" .. tostring(fail)] = function()
        H.git(
          root,
          "config",
          "alias.probe",
          "!printf 'progress\\n' >&2; exit " .. (fail and "7" or "0")
        )
        local command = require("gin.command")
        local execute, echo = command.execute, vim.api.nvim_echo
        local finished, progress, final, errors = false, 0, 0, 0
        command.execute = function(opts)
          opts.on_exit = function()
            finished = true
          end
          return execute(opts)
        end
        vim.api.nvim_echo = function(chunks, history)
          if chunks[1][2] == "ErrorMsg" then
            errors = errors + 1
            assert(chunks[1][1]:find("[gin]: progress", 1, true))
          elseif chunks[1][1] == "progress\n" then
            MiniTest.expect.equality(history, false)
            final = final + 1
          else
            progress = progress + 1
          end
        end
        local ok, err = pcall(function()
          vim.cmd(modifier .. "Gin " .. (wait and "++wait " or "") .. "probe")
          assert(
            vim.wait(5000, function()
              return finished
            end, 10),
            "Command did not finish"
          )
          if not fail then
            H.drain()
          end
          MiniTest.expect.equality(progress > 0, true)
          MiniTest.expect.equality(final, not fail and modifier == "" and 1 or 0)
          MiniTest.expect.equality(errors, fail and modifier ~= "silent! " and 1 or 0)
          MiniTest.expect.equality(events, fail and 0 or 1)
          MiniTest.expect.equality(command.post_pending(), false)
        end)
        command.execute, vim.api.nvim_echo = execute, echo
        assert(ok, err)
      end
    end
  end
end
return T
