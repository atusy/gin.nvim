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
T["aliases dispatch the target and help shows user mappings"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  local actual
  action.setup(buf)
  action.define(buf, "capture:detail", function(_, range)
    actual = range
  end)
  action.alias(buf, "capture", "capture:detail")
  vim.keymap.set("n", "cc", "<Plug>(gin-action-capture)", { buffer = buf, remap = true })
  action.call(buf, "capture", { 3, 5 })
  MiniTest.expect.equality(actual, { 3, 5 })
  local help = action.help(buf, true)
  MiniTest.expect.equality(help:find("cc", 1, true) ~= nil, true)
  MiniTest.expect.equality(help:find("capture:detail", 1, true), nil)
  MiniTest.expect.equality(action.help(buf, false):find("capture:detail", 1, true) ~= nil, true)
end
return T
