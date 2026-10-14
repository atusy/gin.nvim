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
T["accepting an empty choice clears the previous repeat action"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  local calls = 0
  action.setup(buf)
  action.define(buf, "capture", function()
    calls = calls + 1
  end)
  vim.b.denops_action_previous = "capture"
  local input = vim.ui.input
  vim.ui.input = function(_, callback)
    callback("")
  end
  local ok, err = pcall(action.call, buf, "choice", { 1, 1 })
  vim.ui.input = input
  assert(ok, err)
  action.call(buf, "repeat", { 1, 1 })
  MiniTest.expect.equality(calls, 0)
  MiniTest.expect.equality(vim.b.denops_action_previous, "")
end
T["undefined action choices and repeats follow unmapped Plug behavior"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  action.setup(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "original", "unchanged" })
  local input = vim.ui.input
  vim.ui.input = function(_, callback)
    callback("not-defined")
  end
  local ok, err = pcall(action.call, buf, "choice", { 1, 2 })
  vim.ui.input = input
  assert(ok, err)
  MiniTest.expect.equality(vim.b.denops_action_previous, "not-defined")
  action.call(buf, "repeat", { 2, 2 })
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false),
    { "original", "unchanged" }
  )
  MiniTest.expect.equality(action.range(), { 1, 1 })
end
T["repeat distinguishes empty saved values from invalid action names"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  action.setup(buf)
  local calls = 0
  for _, name in ipairs({ "0", "1" }) do
    action.define(buf, name, function()
      calls = calls + 1
    end)
  end
  local echo, output = vim.api.nvim_echo, {}
  vim.api.nvim_echo = function(chunks)
    output[#output + 1] = chunks[1][1]
  end
  local ok, err = pcall(function()
    for i, value in ipairs({ false, 0, vim.NIL, "" }) do
      vim.b.denops_action_previous = value
      action.call(buf, "repeat", { 1, 1 })
      MiniTest.expect.equality(#output, i)
      MiniTest.expect.equality(output[i], "[gin] Nothing to repeat")
    end
    MiniTest.expect.equality(#output, 4)
    for _, value in ipairs({ 1, true, {}, { "0" } }) do
      vim.b.denops_action_previous = value
      MiniTest.expect.error(function()
        action.call(buf, "repeat", { 1, 1 })
      end, "b:denops_action_previous must be a string")
    end
    MiniTest.expect.equality(calls, 0)
    vim.b.denops_action_previous = "0"
    action.call(buf, "repeat", { 1, 1 })
    MiniTest.expect.equality(calls, 1)
  end)
  vim.api.nvim_echo = echo
  assert(ok, err)
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
T["echo formats nested JSON without changing escaped string content"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  local value = 'quote" slash\\ comma, colon: brackets[] braces{}\nnext'
  action.setup(buf, function()
    return { { value = { value, false, vim.NIL, vim.empty_dict() } } }
  end)
  local echo, output = vim.api.nvim_echo, nil
  vim.api.nvim_echo = function(chunks)
    output = chunks[1][1]
  end
  local ok, err = pcall(action.call, buf, "echo", { 1, 1 })
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(
    output,
    '[\n  {\n    "value": [\n      '
      .. vim.json.encode(value)
      .. ",\n      false,\n      null,\n      {}\n    ]\n  }\n]"
  )
  MiniTest.expect.equality(
    vim.json.decode(output),
    { { value = { value, false, vim.NIL, vim.empty_dict() } } }
  )
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
for _, case in ipairs({
  { "Visual", "x", "ggVj", { 1, 2 } },
  { "Select", "s", "ggVj<C-g>", { 1, 2 } },
  { "operator pending", "o", "ggd", { 1, 1 }, "normal" },
}) do
  T["nested actions follow native dispatch in " .. case[1] .. " mode"] = function()
    local action = require("gin.action")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })
    action.setup(buf)
    local captured
    action.define(buf, "capture", function()
      captured = { "normal", action.range() }
    end)
    vim.keymap.set(case[2], "<Plug>(gin-action-capture)", function()
      captured = { case[1], action.range() }
    end, { buffer = buf })
    action.define(buf, "invoke", function(target, range)
      action.call(target, "capture", range)
    end)
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes(case[3] .. "<Plug>(gin-action-invoke)", true, false, true),
      "mx",
      false
    )
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
    MiniTest.expect.equality(captured, { case[5] or case[1], case[4] })
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(buf, 0, -1, false),
      { "one", "two", "three" }
    )
  end
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
T["reduced help includes explicitly mapped detailed actions"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  action.setup(buf)
  action.define(buf, "capture:detail", function() end)
  vim.keymap.set("x", "gc", "<Plug>(gin-action-capture:detail)", { buffer = buf, remap = true })
  local help = action.help(buf, true)
  MiniTest.expect.equality(
    help:find("gc%s+capture:detail%s+<Plug>%(gin%-action%-capture:detail%)") ~= nil,
    true
  )
end
T["help respects local shadows of global shortcuts"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  action.setup(buf)
  action.define(buf, "capture:global", function() end)
  action.define(buf, "capture:local", function() end)
  vim.keymap.set("n", "zX", "<Plug>(gin-action-capture:global)", { remap = true })
  vim.keymap.set("n", "zX", "<Plug>(gin-action-capture:local)", { buffer = buf, remap = true })
  local ok, help = pcall(action.help, buf, true)
  vim.keymap.del("n", "zX", { buffer = buf })
  local global_ok, global_help = pcall(action.help, buf, true)
  vim.keymap.del("n", "zX")
  assert(ok, help)
  assert(global_ok, global_help)
  MiniTest.expect.equality(help:find("zX%s+capture:local%s+") ~= nil, true)
  MiniTest.expect.equality(help:find("capture:global", 1, true), nil)
  MiniTest.expect.equality(global_help:find("zX%s+capture:global%s+") ~= nil, true)
end
T["help lists aliases without presenting their Plug names as user keys"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  action.setup(buf)
  action.define(buf, "capture:detail", function() end)
  action.alias(buf, "capture", "capture:detail")
  local help = action.help(buf, false)
  MiniTest.expect.equality(
    help:find("\n%s+capture:detail%s+<Plug>%(gin%-action%-capture:detail%)") ~= nil,
    true
  )
  local reduced = vim.split(action.help(buf, true), "\n", { plain = true })
  MiniTest.expect.equality(reduced[1]:match("^~+$") ~= nil, true)
  MiniTest.expect.equality(reduced[1], reduced[3])
end
for _, case in ipairs({
  { "Select", "ggVj<C-g>", { 1, 2 } },
  { "operator pending", "ggd", { 1, 1 } },
}) do
  T["action aliases dispatch in " .. case[1] .. " mode"] = function()
    local action = require("gin.action")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })
    local ranges = {}
    action.setup(buf)
    action.define(buf, "capture", function(_, range)
      ranges[#ranges + 1] = range
    end)
    action.alias(buf, "selected", "capture")
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes(
        case[2] .. "<Plug>(gin-action-selected)<Esc>",
        true,
        false,
        true
      ),
      "mx",
      false
    )
    MiniTest.expect.equality(ranges, { case[3] })
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(buf, 0, -1, false),
      { "one", "two", "three" }
    )
  end
end
T["Plug dispatch reports action errors without changing strict calls"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  action.setup(buf)
  action.define(buf, "failure", function()
    error("action failed", 0)
  end)
  local echo, messages = vim.api.nvim_echo, {}
  vim.api.nvim_echo = function(chunks, history)
    messages[#messages + 1] = { chunks, history }
  end
  local dispatch = vim.fn.maparg("<Plug>(gin-action-failure)", "n", false, true).callback
  local ok, err = pcall(dispatch)
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(messages, { { { { "[gin]: action failed", "ErrorMsg" } }, false } })
  MiniTest.expect.error(function()
    action.call(buf, "failure", { 2, 3 })
  end, "action failed")
  MiniTest.expect.equality(action.range(), { 1, 1 })
end
T["deferred choice failures stay inside the mapping boundary"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  action.setup(buf)
  local ranges, completed = {}, nil
  action.define(buf, "failure", function(_, range)
    ranges[#ranges + 1] = range
    error("chosen action failed", 0)
  end)
  local input = vim.ui.input
  vim.ui.input = function(_, callback)
    completed = callback
  end
  local echo, messages = vim.api.nvim_echo, {}
  vim.api.nvim_echo = function(chunks, history)
    messages[#messages + 1] = { chunks, history }
  end
  local ok, err = pcall(function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.fn.maparg("<Plug>(gin-action-choice)", "n", false, true).callback()
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    completed("failure")
    vim.fn.maparg("<Plug>(gin-action-repeat)", "n", false, true).callback()
  end)
  vim.ui.input, vim.api.nvim_echo = input, echo
  assert(ok, err)
  MiniTest.expect.equality(ranges, { { 2, 2 }, { 3, 3 } })
  MiniTest.expect.equality(messages, {
    { { { "[gin]: chosen action failed", "ErrorMsg" } }, false },
    { { { "[gin]: chosen action failed", "ErrorMsg" } }, false },
  })
  MiniTest.expect.equality(vim.b.denops_action_previous, "failure")
  MiniTest.expect.equality(action.range(), { 3, 3 })
end
T["direct choice completion retains strict errors"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  action.setup(buf)
  action.define(buf, "failure", function()
    error("direct choice failed", 0)
  end)
  local input, completed = vim.ui.input, nil
  vim.ui.input = function(_, callback)
    completed = callback
  end
  local ok, err = pcall(action.call, buf, "choice", { 2, 3 })
  vim.ui.input = input
  assert(ok, err)
  MiniTest.expect.error(function()
    completed("failure")
  end, "direct choice failed")
  MiniTest.expect.equality(action.range(), { 1, 1 })
end
T["native Plug aliases report failures without leaking editor errors"] = function()
  local action = require("gin.action")
  local buf = vim.api.nvim_get_current_buf()
  action.setup(buf)
  action.define(buf, "failure", function()
    error("mapped failure", 0)
  end)
  action.alias(buf, "selected", "failure")
  vim.v.errmsg = ""
  vim.cmd("messages clear")
  local echo, messages = vim.api.nvim_echo, {}
  vim.api.nvim_echo = function(chunks, history)
    messages[#messages + 1] = { chunks, history }
  end
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Plug>(gin-action-selected)", true, false, true),
    "mx",
    false
  )
  vim.api.nvim_echo = echo
  MiniTest.expect.equality(messages, { { { { "[gin]: mapped failure", "ErrorMsg" } }, false } })
  MiniTest.expect.equality(vim.v.errmsg, "")
  MiniTest.expect.equality(vim.api.nvim_exec2("messages", { output = true }).output, "")
end
return T
