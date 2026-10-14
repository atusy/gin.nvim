local T = MiniTest.new_set()
for _, encoding in ipairs({ "utf-16le", "utf-16be" }) do
  local path = "tests/audit/" .. encoding .. "-oracle.json"
  local oracle = vim.json.decode(table.concat(vim.fn.readfile(path, "b"), "\n"))
  for first, row in ipairs(oracle.rows) do
    T[string.format(
      "%s byte %02x with every trailing byte matches replacement decoding",
      encoding,
      first - 1
    )] = function()
      for second, expected in ipairs(row) do
        local actual = require("gin.encoding").decode(
          string.char(first - 1, second - 1),
          encoding,
          { fatal = false }
        )
        MiniTest.expect.equality(actual, expected)
      end
    end
  end
  T[encoding .. " strict mode still rejects unpaired surrogates"] = function()
    local data = encoding == "utf-16le" and string.char(0, 216) or string.char(216, 0)
    MiniTest.expect.equality(
      require("gin.encoding").decode(data, encoding, { fatal = false }),
      "�"
    )
    local ok = pcall(require("gin.encoding").decode, data, encoding)
    MiniTest.expect.equality(ok, false)
  end
end
return T
