local T = MiniTest.new_set()
local oracle =
  vim.json.decode(table.concat(vim.fn.readfile("tests/audit/gb18030-oracle.json", "b"), "\n"))
for _, encoding in ipairs({ "gbk", "gb18030" }) do
  for first, row in ipairs(oracle.rows) do
    T[string.format("%s byte %02x followed by every byte matches TextDecoder", encoding, first - 1)] = function()
      for second, expected in ipairs(row) do
        local ok, text =
          pcall(require("gin.encoding").decode, string.char(first - 1, second - 1), encoding)
        assert(
          ok == (expected ~= false),
          string.format("acceptance mismatch at %02x %02x", first - 1, second - 1)
        )
        if ok then
          MiniTest.expect.equality(text, expected)
        end
      end
    end
  end
  T[encoding .. " matches single bytes, quadruple boundaries and mixed input"] = function()
    for index, case in ipairs(oracle.cases) do
      local ok, text =
        pcall(require("gin.encoding").decode, string.char(unpack(case.bytes)), encoding)
      assert(ok == not case.error, "acceptance mismatch at case " .. index)
      if ok then
        MiniTest.expect.equality(text, case.text)
      end
    end
  end
  T[encoding .. " accepts all labels with ASCII whitespace and case"] = function()
    assert(#oracle.aliases[encoding] > 0)
    for _, label in ipairs(oracle.aliases[encoding]) do
      MiniTest.expect.equality(
        require("gin.encoding").decode(string.char(128), " \t" .. label:upper() .. "\r"),
        "€"
      )
    end
  end
end
T["GBK is selected for valid four-byte input"] = function()
  local bytes = string.char(129, 48, 129, 48)
  local actual = { require("gin.encoding").detect(bytes, { "utf-8", "gbk", "latin1" }) }
  MiniTest.expect.equality(actual, { vim.fn.nr2char(128), "gbk", false })
end
T["truncated GB18030 skips both Chinese candidates"] = function()
  local bytes = string.char(129, 48, 129)
  local actual = { require("gin.encoding").detect(bytes, { "gbk", "gb18030", "latin1" }) }
  MiniTest.expect.equality(
    actual,
    { vim.fn.nr2char(129) .. "0" .. vim.fn.nr2char(129), "latin1", false }
  )
end
return T
