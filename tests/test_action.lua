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
T["echo serializes selected candidates as JSON including escaped paths"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  local selected = { { path = "line\nbreak", commit = "abcdef" } }
  local observed_range
  action.setup(buf, function(target, range)
    MiniTest.expect.equality(target, buf)
    observed_range = range
    return selected
  end)
  local original, output = vim.api.nvim_echo, nil
  vim.api.nvim_echo = function(chunks)
    output = chunks[1][1]
  end
  local ok, err = pcall(action.call, buf, "echo", { 2, 3 })
  vim.api.nvim_echo = original
  assert(ok, err)
  MiniTest.expect.equality(vim.json.decode(output), selected)
  MiniTest.expect.equality(observed_range, { 2, 3 })
end
T["user action aliases appear in choice and preserve explicit ranges"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  local captured
  action.setup(buf)
  action.define(buf, "capture", function(_, range)
    captured = range
  end)
  vim.keymap.set("n", "<Plug>(gin-action-custom)", "<Plug>(gin-action-capture)", {
    buffer = buf,
    remap = true,
  })
  MiniTest.expect.equality(vim.tbl_contains(action.list(buf), "custom"), true)
  action.call(buf, "custom", { 2, 4 })
  MiniTest.expect.equality(captured, { 2, 4 })
end
T["user callback overrides replace registered actions and restore ranges after errors"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  action.setup(buf)
  action.define(buf, "capture", function()
    error("original callback must not run")
  end)
  local captured
  vim.keymap.set("n", "<Plug>(gin-action-capture)", function()
    captured = action.range()
    error("user failure")
  end, { buffer = buf })
  local ok, err = pcall(action.call, buf, "capture", { 3, 5 })
  MiniTest.expect.equality(ok, false)
  MiniTest.expect.equality(tostring(err):find("user failure", 1, true) ~= nil, true)
  MiniTest.expect.equality(captured, { 3, 5 })
  MiniTest.expect.equality(action.range(), { 1, 1 })
end
T["custom command mappings receive captured action ranges"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  local captured
  action.setup(buf)
  action.define(buf, "capture", function(_, range)
    captured = range
  end)
  vim.keymap.set(
    "n",
    "<Plug>(gin-action-custom)",
    "<Cmd>lua require('gin.action').call("
      .. buf
      .. ", 'capture', require('gin.action').range())<CR>",
    { buffer = buf }
  )
  action.call(buf, "custom", { 2, 3 })
  MiniTest.expect.equality(captured, { 2, 3 })
end
T["expression action mappings execute their returned keys"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  local captured
  action.setup(buf)
  action.define(buf, "capture", function(_, range)
    captured = range
  end)
  vim.keymap.set("n", "<Plug>(gin-action-custom)", function()
    return "<Plug>(gin-action-capture)"
  end, { buffer = buf, expr = true })
  action.call(buf, "custom", { 2, 4 })
  MiniTest.expect.equality(captured, { 2, 4 })
end
return T
