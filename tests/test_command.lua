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
return T
