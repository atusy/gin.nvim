local H = require("tests.helpers")
local root
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
    end,
    post_case = function()
      vim.fn.delete(root, "rf")
    end,
  },
})
T["runs argv literally without expanding pathspec magic"] = function()
  vim.fn.writefile({ "literal" }, root .. "/[file].txt")
  vim.fn.writefile({ "other" }, root .. "/f.txt")
  require("gin.git").run({ "add", "--", "[file].txt" }, { cwd = root })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "[file].txt\n")
end
return T
