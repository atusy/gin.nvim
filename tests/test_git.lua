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
T["timed out commands report failure"] = function()
  local result = require("gin.git").run(
    { "hash-object", "--stdin" },
    { cwd = root, stdin = true, timeout = 20, check = false }
  )
  MiniTest.expect.equality(result.code, 124)
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
return T
