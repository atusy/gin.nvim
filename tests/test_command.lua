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
return T
