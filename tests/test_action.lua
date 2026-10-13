local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      vim.cmd.enew()
    end,
    post_case = function()
      vim.api.nvim_buf_delete(0, { force = true })
    end,
  },
})
T["choice captures the range and repeat uses the new selection"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  local calls = {}
  local input = vim.ui.input
  action.setup(buf)
  action.define(buf, "capture", function(_, range)
    calls[#calls + 1] = range
  end)
  vim.ui.input = function(_, callback)
    callback("capture")
  end
  local ok, err = pcall(action.call, buf, "choice", { 2, 4 })
  vim.ui.input = input
  assert(ok, err)
  action.call(buf, "repeat", { 6, 6 })
  MiniTest.expect.equality(calls, { { 2, 4 }, { 6, 6 } })
end
return T
