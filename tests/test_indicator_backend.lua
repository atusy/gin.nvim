local H = require("tests.helpers")
local root, runtimepath
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root, runtimepath = H.repo(), vim.o.runtimepath
      vim.fn.mkdir(root .. "/autoload/gin/indicator", "p")
      vim.fn.writefile(
        vim.split(
          [[
function! gin#indicator#gin_test#open(id) abort
  call add(g:gin_test_indicator_events, ['open', a:id])
endfunction
function! gin#indicator#gin_test#write(id, lines) abort
  call add(g:gin_test_indicator_events, ['write', a:id, a:lines])
  if get(g:, 'gin_test_indicator_failure', '') ==# 'write'
    throw 'backend failure'
  endif
endfunction
function! gin#indicator#gin_test#close(id) abort
  call add(g:gin_test_indicator_events, ['close', a:id])
  if get(g:, 'gin_test_indicator_failure', '') ==# 'close'
    throw 'backend failure'
  endif
endfunction
]],
          "\n"
        ),
        root .. "/autoload/gin/indicator/gin_test.vim"
      )
      vim.opt.runtimepath:prepend(root)
      vim.cmd("let g:gin_test_indicator_events = []")
    end,
    post_case = function()
      vim.o.runtimepath = runtimepath
      vim.g.gin_test_indicator_events = nil
      vim.g.gin_test_indicator_failure = nil
      H.cleanup(root)
    end,
  },
})

T["Git progress routes both channels through named indicators without changing output"] = function()
  local result = require("gin.git").run(
    {
      "-c",
      [[alias.progress=!printf '\033[31mout\033[m\n'; printf 'err\n' >&2]],
      "progress",
    },
    { cwd = root, progress = "both", stdout_indicator = "gin_test", stderr_indicator = "gin_test" }
  )
  MiniTest.expect.equality({ result.stdout, result.stderr }, { "\27[31mout\27[m\n", "err\n" })
  local events = vim.g.gin_test_indicator_events
  MiniTest.expect.equality(#events, 6)
  MiniTest.expect.equality({ events[1][1], events[2][1] }, { "open", "open" })
  MiniTest.expect.equality(events[1][2] ~= events[2][2], true)
  local text = {}
  for i = 3, 4 do
    MiniTest.expect.equality(events[i][1], "write")
    text[events[i][2]] = table.concat(events[i][3], "\n")
  end
  MiniTest.expect.equality(text[events[1][2]], "out")
  MiniTest.expect.equality(text[events[2][2]], "err")
  MiniTest.expect.equality(events[5], { "close", events[1][2] })
  MiniTest.expect.equality(events[6], { "close", events[2][2] })
end

for _, failure in ipairs({ "write", "close" }) do
  T["backend " .. failure .. " failures close both channels and reach the caller"] = function()
    vim.g.gin_test_indicator_failure = failure
    MiniTest.expect.error(function()
      require("gin.git").run({ "-c", "alias.progress=!printf out; printf err >&2", "progress" }, {
        cwd = root,
        progress = "both",
        stdout_indicator = "gin_test",
        stderr_indicator = "gin_test",
      })
    end, "backend failure")
    local events = vim.g.gin_test_indicator_events
    MiniTest.expect.equality(events[#events - 1], { "close", events[1][2] })
    MiniTest.expect.equality(events[#events], { "close", events[2][2] })
  end
end

T["failure opening the second backend closes the first without starting Git"] = function()
  MiniTest.expect.error(function()
    require("gin.git").run({ "-c", "alias.progress=!touch started", "progress" }, {
      cwd = root,
      progress = "both",
      stdout_indicator = "gin_test",
      stderr_indicator = "gin_missing_test_backend",
    })
  end, "Unknown function")
  local events = vim.g.gin_test_indicator_events
  MiniTest.expect.equality(#events, 2)
  MiniTest.expect.equality(events[2], { "close", events[1][2] })
  MiniTest.expect.equality(vim.fn.filereadable(root .. "/started"), 0)
end

T["null suppresses one progress channel while retaining failed Git output"] = function()
  local result = require("gin.git").run(
    { "-c", "alias.progress=!printf out; printf err >&2; exit 7", "progress" },
    {
      cwd = root,
      progress = "both",
      stdout_indicator = "null",
      stderr_indicator = "gin_test",
      check = false,
    }
  )
  MiniTest.expect.equality({ result.code, result.stdout, result.stderr }, { 7, "out", "err" })
  local events = vim.g.gin_test_indicator_events
  MiniTest.expect.equality(#events, 3)
  MiniTest.expect.equality(events[2], { "write", events[1][2], { "err" } })
  MiniTest.expect.equality(events[3], { "close", events[1][2] })
end

for _, wait in ipairs({ false, true }) do
  T["command execution uses named progress with wait=" .. tostring(wait)] = function()
    local args =
      { "++worktree=" .. root, "-c", "alias.progress=!printf out; printf err >&2", "progress" }
    if wait then
      table.insert(args, 1, "++wait")
    end
    local completed
    local result = require("gin.command").execute({
      fargs = args,
      smods = {},
      stdout_indicator = "gin_test",
      stderr_indicator = "gin_test",
      on_exit = function(value)
        completed = value
      end,
    })
    MiniTest.expect.equality(
      vim.wait(2000, function()
        return completed ~= nil
      end, 10),
      true
    )
    MiniTest.expect.equality({ completed.stdout, completed.stderr }, { "out", "err" })
    if wait then
      MiniTest.expect.equality(result, completed)
    end
    local events = vim.g.gin_test_indicator_events
    MiniTest.expect.equality(#events, 6)
    MiniTest.expect.equality(events[5], { "close", events[1][2] })
    MiniTest.expect.equality(events[6], { "close", events[2][2] })
  end
end

for _, wait in ipairs({ false, true }) do
  T["command backend failure skips processing and post events with wait=" .. tostring(wait)] = function()
    vim.g.gin_test_indicator_failure = "write"
    local notify, notices = vim.notify, {}
    vim.notify = function(message)
      notices[#notices + 1] = message
    end
    local posts, completed = 0, nil
    local autocmd = vim.api.nvim_create_autocmd("User", {
      pattern = "GinCommandPost",
      callback = function()
        posts = posts + 1
      end,
    })
    local ok, err = pcall(function()
      local args = {
        "++worktree=" .. root,
        "++processor=touch processor-ran",
        "-c",
        "alias.progress=!printf out",
        "progress",
      }
      if wait then
        table.insert(args, 1, "++wait")
      end
      local success, result = pcall(require("gin.command").execute, {
        fargs = args,
        smods = {},
        stdout_indicator = "gin_test",
        stderr_indicator = "gin_test",
        on_exit = function(value)
          completed = value
        end,
      })
      if wait then
        MiniTest.expect.equality(success, false)
        MiniTest.expect.equality(tostring(result):find("backend failure", 1, true) ~= nil, true)
      else
        MiniTest.expect.equality(success, true)
        MiniTest.expect.equality(
          vim.wait(2000, function()
            return completed ~= nil
          end, 10),
          true
        )
        MiniTest.expect.equality(#notices, 1)
        MiniTest.expect.equality(notices[1]:find("backend failure", 1, true) ~= nil, true)
      end
      MiniTest.expect.equality(completed.code, 0)
      H.drain()
      MiniTest.expect.equality(posts, 0)
      MiniTest.expect.equality(vim.fn.filereadable(root .. "/processor-ran"), 0)
      local events = vim.g.gin_test_indicator_events
      MiniTest.expect.equality(events[#events - 1], { "close", events[1][2] })
      MiniTest.expect.equality(events[#events], { "close", events[2][2] })
    end)
    vim.notify = notify
    vim.api.nvim_del_autocmd(autocmd)
    assert(ok, err)
  end
end

T["silent command execution does not open configured indicators"] = function()
  local result = require("gin.command").execute({
    fargs = {
      "++wait",
      "++worktree=" .. root,
      "-c",
      "alias.progress=!printf out; printf err >&2",
      "progress",
    },
    smods = { silent = true },
    stdout_indicator = "gin_missing_test_backend",
    stderr_indicator = "gin_missing_test_backend",
  })
  MiniTest.expect.equality({ result.stdout, result.stderr }, { "out", "err" })
  MiniTest.expect.equality(vim.g.gin_test_indicator_events, {})
end

return T
