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
return T
