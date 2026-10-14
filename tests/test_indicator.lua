local T = MiniTest.new_set()

local function capture(write)
  local echo, output = vim.api.nvim_echo, {}
  vim.api.nvim_echo = function(chunks)
    output[#output + 1] = chunks[1][1]
  end
  local indicator = require("gin.indicator").open()
  local ok, err = pcall(write, indicator)
  local drained = false
  vim.schedule(function()
    drained = true
  end)
  local completed = vim.wait(1000, function()
    return drained
  end, 10)
  indicator.close()
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(completed, true)
  return output
end

T["progress trims ECMAScript whitespace only at chunk boundaries"] = function()
  local spaces =
    { 9, 10, 11, 12, 13, 32, 0xA0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF }
  for cp = 0x2000, 0x200A do
    spaces[#spaces + 1] = cp
  end
  for _, cp in ipairs(spaces) do
    local space = vim.fn.nr2char(cp)
    local output = capture(function(indicator)
      indicator.write(nil, space .. "first" .. space .. "last" .. space)
    end)
    MiniTest.expect.equality(output, { "first" .. space .. "last" })
  end
  for _, cp in ipairs({ 0x85, 0x180E, 0x200B }) do
    local text = vim.fn.nr2char(cp) .. "text" .. vim.fn.nr2char(cp)
    MiniTest.expect.equality(
      capture(function(indicator)
        indicator.write(nil, text)
      end),
      { text }
    )
  end
end
T["progress preserves UTF-8 and ANSI sequences split across chunks"] = function()
  local output = capture(function(indicator)
    indicator.write(nil, "\27[3")
    indicator.write(nil, "1m" .. string.char(0xe3, 0x81))
    indicator.write(nil, string.char(0x82) .. "ready\27[0m\n")
  end)
  MiniTest.expect.equality(output, { "あready" })
end
T["progress decodes every byte boundary of multibyte characters"] = function()
  local text = "éあ😀"
  for split = 1, #text - 1 do
    local output = capture(function(indicator)
      indicator.write(nil, text:sub(1, split))
      indicator.write(nil, text:sub(split + 1))
      indicator.write(nil, nil)
    end)
    MiniTest.expect.equality(table.concat(output), text)
  end
end
T["progress replaces malformed UTF-8 without losing following text"] = function()
  local cases = {
    { { 0x80, 0xff, 0xc0, 0xaf }, "����" },
    { { 0xe3, 0x81, 0x41 }, "�A" },
    { { 0xe0, 0x80, 0x80 }, "���" },
    { { 0xed, 0xa0, 0x80 }, "���" },
    { { 0xf4, 0x90, 0x80, 0x80 }, "����" },
    { { 0xf0, 0x90, 0x80 }, "�" },
    { { 0xc2, 0xc2, 0xa2 }, "�¢" },
  }
  for _, case in ipairs(cases) do
    local bytes = string.char(unpack(case[1]))
    for split = 0, #bytes do
      local output = capture(function(indicator)
        indicator.write(nil, bytes:sub(1, split))
        indicator.write(nil, bytes:sub(split + 1))
        indicator.write(nil, nil)
      end)
      MiniTest.expect.equality(table.concat(output), case[2])
    end
  end
end
T["stdout and stderr keep independent partial sequences"] = function()
  local output = capture(function(indicator)
    indicator.write(nil, "\27[31mOK\27[0")
    indicator.write_stderr(nil, string.char(0xf0, 0x9f))
    indicator.write(nil, "m")
    indicator.write_stderr(nil, string.char(0x98, 0x80))
  end)
  MiniTest.expect.equality(output, { "OK", "😀" })
end
T["EOF replaces incomplete UTF-8 and discards incomplete ANSI"] = function()
  local output = capture(function(indicator)
    indicator.write(nil, string.char(0xe3))
    indicator.write_stderr(nil, "\27[3")
    indicator.write(nil, nil)
    indicator.write_stderr(nil, nil)
    indicator.write(nil, nil)
  end)
  MiniTest.expect.equality(output, { "�" })
end
T["progress removes general CSI across every byte boundary"] = function()
  local text = "before\27[2K\27[?25l\27[1;2H\27[!pafter"
  for split = 1, #text - 1 do
    local output = capture(function(indicator)
      indicator.write(nil, text:sub(1, split))
      indicator.write(nil, text:sub(split + 1))
      indicator.write(nil, nil)
    end)
    MiniTest.expect.equality(table.concat(output), "beforeafter")
  end
end
T["legacy echo displays line arrays synchronously and restores shared options"] = function()
  local echo, output = vim.api.nvim_echo, {}
  local more, height = vim.o.more, vim.o.cmdheight
  vim.o.more, vim.o.cmdheight = true, 1
  vim.api.nvim_echo = function(chunks)
    output[#output + 1] = chunks[1][1]
  end
  local ok, err = pcall(function()
    vim.fn["gin#indicator#echo#write"]("unopened", { "ignored" })
    vim.fn["gin#indicator#echo#open"]("stdout")
    vim.fn["gin#indicator#echo#open"]("stderr")
    MiniTest.expect.equality(vim.o.more, true)
    vim.fn["gin#indicator#echo#write"]("stdout", { "  first", "", "last  " })
    MiniTest.expect.equality(output, { "  first\n\nlast  " })
    MiniTest.expect.equality(vim.o.cmdheight, 3)
    vim.fn["gin#indicator#echo#close"]("stdout")
    MiniTest.expect.equality(vim.o.cmdheight, 3)
    vim.fn["gin#indicator#echo#write"]("stderr", {})
    MiniTest.expect.equality(#output, 1)
    vim.fn["gin#indicator#echo#close"]("stderr")
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { true, 1 })
    vim.fn["gin#indicator#echo#write"]("closed", { "ignored" })
    vim.fn["gin#indicator#echo#close"]("closed")
    MiniTest.expect.equality(#output, 1)
  end)
  pcall(vim.fn["gin#indicator#echo#close"], "cleanup")
  pcall(vim.fn["gin#indicator#echo#close"], "cleanup")
  vim.api.nvim_echo = echo
  vim.o.more, vim.o.cmdheight = more, height
  assert(ok, err)
end
T["legacy and native indicators share the original display settings"] = function()
  local more, height, echo = vim.o.more, vim.o.cmdheight, vim.api.nvim_echo
  vim.o.more, vim.o.cmdheight = true, 1
  vim.api.nvim_echo = function() end
  local native
  local ok, err = pcall(function()
    vim.fn["gin#indicator#echo#open"]("legacy")
    native = require("gin.indicator").open()
    vim.fn["gin#indicator#echo#write"]("legacy", { "first", "second", "third" })
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { false, 3 })
    native.close()
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { false, 3 })
    vim.fn["gin#indicator#echo#close"]("legacy")
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { true, 1 })
  end)
  if native then
    native.close()
  end
  vim.fn["gin#indicator#echo#close"]("cleanup")
  vim.api.nvim_echo = echo
  vim.o.more, vim.o.cmdheight = more, height
  assert(ok, err)
end
T["progress displays NUL-containing lines using Vim Blob notation"] = function()
  local output = capture(function(indicator)
    indicator.write_lines({ "A\0", "plain", "\0�A\0" })
  end)
  MiniTest.expect.equality(output, { "0z4100\nplain\n0z00EFBFBD.4100" })
end
return T
