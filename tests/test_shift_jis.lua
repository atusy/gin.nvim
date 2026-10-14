local T = MiniTest.new_set()
local oracle =
  vim.json.decode(table.concat(vim.fn.readfile("tests/audit/shift-jis-oracle.json", "b"), "\n"))
for index, row in ipairs(oracle.rows) do
  T[string.format("Shift_JIS byte %02x followed by every byte matches TextDecoder", index - 1)] = function()
    for second, expected in ipairs(row) do
      local ok, text =
        pcall(require("gin.encoding").decode, string.char(index - 1, second - 1), "shift_jis")
      assert(
        ok == (expected ~= false),
        string.format("acceptance mismatch at %02x %02x", index - 1, second - 1)
      )
      if ok then
        MiniTest.expect.equality(text, expected)
      end
    end
  end
end
T["detection chooses Shift_JIS before a single-byte fallback"] = function()
  local data = string.char(147, 250, 150, 123)
  local actual = { require("gin.encoding").detect(data, { "utf-8", "sjis", "latin1" }) }
  MiniTest.expect.equality(actual, { "日本", "sjis", false })
end
T["truncated Shift_JIS is rejected before trying the next candidate"] = function()
  MiniTest.expect.equality(
    { require("gin.encoding").detect(string.char(130), { "sjis", "latin1" }) },
    { "‚", "latin1", false }
  )
end
return T
