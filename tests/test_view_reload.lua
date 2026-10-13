local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      H.git(root, "commit", "--allow-empty", "-m", "before")
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})

local function drain()
  local done = false
  vim.schedule(function()
    done = true
  end)
  assert(vim.wait(1000, function()
    return done
  end, 10))
end

T["command events defer hidden log refresh until entry"] = function()
  vim.cmd("GinLog --oneline")
  local buf = vim.api.nvim_get_current_buf()
  local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.bo.bufhidden = "hide"
  vim.cmd.enew()
  H.git(root, "commit", "--allow-empty", "-m", "after")
  require("gin.command").post()
  drain()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false), before)
  vim.api.nvim_set_current_buf(buf)
  MiniTest.expect.equality(vim.api.nvim_buf_line_count(buf), 2)
  MiniTest.expect.equality(vim.api.nvim_get_current_line():find("after", 1, true) ~= nil, true)
end

return T
