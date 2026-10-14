local H = require("tests.helpers")
local root
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
    end,
    post_case = function()
      H.cleanup(root)
    end,
  },
})
T["runs argv literally without expanding pathspec magic"] = function()
  vim.fn.writefile({ "literal" }, root .. "/[file].txt")
  vim.fn.writefile({ "other" }, root .. "/f.txt")
  require("gin.git").run({ "add", "--", "[file].txt" }, { cwd = root })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "[file].txt\n")
end
for _, source in ipairs({ "git", "processor" }) do
  for _, progress in ipairs({ false, true }) do
    T[source .. " errors retain stderr whitespace with progress=" .. tostring(progress)] = function()
      local git = require("gin.git")
      local script = [[printf '\033[31m  failure \033[m\n\n' >&2; exit 7]]
      local args = source == "git" and { "-c", "alias.fail=!" .. script, "fail" } or { "--version" }
      local opts = {
        cwd = root,
        progress = progress,
        processor = source == "processor" and { "sh", "-c", script } or nil,
      }
      local result = git.run(args, vim.tbl_extend("force", opts, { check = false }))
      MiniTest.expect.equality(result.code, 7)
      MiniTest.expect.equality(result.stderr, "\27[31m  failure \27[m\n\n")
      local ok, err = pcall(git.run, args, opts)
      MiniTest.expect.equality(ok, false)
      MiniTest.expect.equality(err, source .. " exited 7:   failure \n\n")
    end
  end
end
T["failed commands retain status and stderr"] = function()
  local git = require("gin.git")
  local result = git.run({ "not-a-git-command" }, { cwd = root, check = false })
  MiniTest.expect.equality(result.code ~= 0, true)
  MiniTest.expect.equality(result.stderr:find("not%-a%-git%-command") ~= nil, true)
  MiniTest.expect.error(function()
    git.run({ "not-a-git-command" }, { cwd = root })
  end, "git exited")
end
T["binary output retains NUL separators"] = function()
  vim.fn.writefile({ "hello" }, root .. "/space name.txt")
  local result = require("gin.git").run({ "status", "--porcelain", "-z" }, { cwd = root })
  MiniTest.expect.equality(result.stdout, "?? space name.txt\0")
end
for _, source in ipairs({ "git", "processor" }) do
  T[source .. " errors strip color codes while unchecked results retain raw stderr"] = function()
    local script = [[printf '\033[2K\033[31mbroken\033[m\n' >&2; exit 7]]
    local args = source == "git" and { "-c", "alias.fail=!" .. script, "fail" } or { "status" }
    local opts = { cwd = root }
    if source == "processor" then
      opts.processor = { "sh", "-c", script }
    end
    local ok, err = pcall(require("gin.git").run, args, opts)
    MiniTest.expect.equality(ok, false)
    MiniTest.expect.equality(err, source .. " exited 7: broken\n")
    opts.check = false
    local result = require("gin.git").run(args, opts)
    MiniTest.expect.equality(result.code, 7)
    MiniTest.expect.equality(result.stderr, "\27[2K\27[31mbroken\27[m\n")
  end
end
T["timed out commands report failure"] = function()
  local result = require("gin.git").run(
    { "hash-object", "--stdin" },
    { cwd = root, stdin = true, timeout = 20, check = false }
  )
  MiniTest.expect.equality(result.code, 124)
end
T["Git and processors receive no implicit process deadline"] = function()
  local system, deadlines = vim.system, {}
  vim.system = function(args, opts, callback)
    deadlines[#deadlines + 1] = opts.timeout or false
    return system(args, opts, callback)
  end
  local ok, result = pcall(require("gin.git").run, { "--version" }, {
    cwd = root,
    processor = { "cat" },
    progress = true,
  })
  vim.system = system
  assert(ok, result)
  MiniTest.expect.equality(result.code, 0)
  MiniTest.expect.equality(result.stdout:find("git version", 1, true) ~= nil, true)
  MiniTest.expect.equality(deadlines, { false, false })
end
T["processors receive Git stdout in the repository directory"] = function()
  vim.fn.writefile({ "hello" }, root .. "/file")
  local result = require("gin.git").run(
    { "status", "--short" },
    { cwd = root, processor = { "tr", "a-z", "A-Z" } }
  )
  MiniTest.expect.equality(result.stdout, "?? FILE\n")
  result = require("gin.git").run({ "status", "--short" }, { cwd = root, processor = { "pwd" } })
  MiniTest.expect.equality(vim.trim(result.stdout), vim.uv.fs_realpath(root))
end
T["progress restores editor options when Git fails or times out"] = function()
  local more, height = vim.o.more, vim.o.cmdheight
  local echo = vim.api.nvim_echo
  vim.api.nvim_echo = function() end
  local ok, err = pcall(function()
    MiniTest.expect.error(function()
      require("gin.git").run({ "not-a-git-command" }, { cwd = root, progress = true })
    end, "git exited")
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { more, height })
    local result = require("gin.git").run({ "hash-object", "--stdin" }, {
      cwd = root,
      stdin = true,
      timeout = 20,
      check = false,
      progress = true,
    })
    MiniTest.expect.equality(result.code, 124)
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { more, height })
  end)
  vim.api.nvim_echo = echo
  assert(ok, err)
end
T["processor errors propagate and failed Git commands skip processors"] = function()
  MiniTest.expect.error(function()
    require("gin.git").run(
      { "status" },
      { cwd = root, processor = { "sh", "-c", "echo processor-failed >&2; exit 7" } }
    )
  end, "processor exited 7: processor%-failed")
  local result = require("gin.git").run(
    { "not-a-git-command" },
    { cwd = root, processor = { "does-not-exist" }, check = false }
  )
  MiniTest.expect.equality(result.stderr:find("not%-a%-git%-command") ~= nil, true)
end
T["stream listeners observe output before exit without losing captured bytes"] = function()
  local stdout, stderr = {}, {}
  local process = require("gin.git").start({
    "-c",
    [[alias.progress=!printf 'early\000data\n'; read answer; printf '%s\n' "$answer"; printf 'warning\n' >&2]],
    "progress",
  }, {
    cwd = root,
    stdin = true,
    on_stdout = function(_, data)
      if data then
        stdout[#stdout + 1] = data
      end
    end,
    on_stderr = function(_, data)
      if data then
        stderr[#stderr + 1] = data
      end
    end,
  })
  local observed = vim.wait(1000, function()
    return table.concat(stdout):find("early\0data\n", 1, true) ~= nil
  end, 10)
  process:write("finished\n")
  process:write(nil)
  local result = process:wait(5000)
  MiniTest.expect.equality(observed, true)
  MiniTest.expect.equality(result.code, 0)
  MiniTest.expect.equality(result.stdout, "early\0data\nfinished\n")
  MiniTest.expect.equality(result.stderr, "warning\n")
  MiniTest.expect.equality(table.concat(stdout), result.stdout)
  MiniTest.expect.equality(table.concat(stderr), result.stderr)
end
return T
