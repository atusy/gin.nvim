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

return T
