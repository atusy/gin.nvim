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
T["Gin wait executes a Git command and emits its completion event"] = function()
  vim.fn.writefile({ "literal" }, root .. "/space name")
  vim.cmd([[Gin ++wait add -- space\ name]])
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "space name\n")
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
T["failed Gin does not publish a success event"] = function()
  MiniTest.expect.error(function()
    vim.cmd("Gin ++wait not-a-git-command")
  end, "git exited")
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
T["Gin wait returns processed output and rejects processor failures"] = function()
  vim.fn.writefile({ "text" }, root .. "/file")
  local result = require("gin.command").execute({
    fargs = { "++wait", "++processor=tr a-z A-Z", "status", "--short" },
    smods = { silent = true },
  })
  MiniTest.expect.equality(result.stdout, "?? FILE\n")
  MiniTest.expect.equality(events, 1)
  MiniTest.expect.error(function()
    vim.cmd("Gin ++wait ++processor=false status")
  end, "processor exited")
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

for _, spec in ipairs({
  { option = "++ff=unix", expected = "first\r\nsecond\r" },
  { option = "++fileformat=unix", expected = "first\r\nsecond\r" },
  { option = "++ff=dos", expected = "first\nsecond" },
  { option = "++ff=mac", expected = "first\n\nsecond\n" },
  { option = "", expected = "first\nsecond" },
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
    MiniTest.expect.equality(output[#output], { text = "early\nfinished\nwarning", history = true })
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
        [[alias.fail=!printf '\033[31mbroken\033[m\n' >&2; exit 7]],
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
return T
