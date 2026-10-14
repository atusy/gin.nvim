local T = MiniTest.new_set()
for _, encoding in ipairs({ "big5", "euc-kr" }) do
  local path = "tests/audit/" .. encoding .. "-oracle.json"
  local oracle = vim.json.decode(table.concat(vim.fn.readfile(path, "b"), "\n"))
  for first, row in ipairs(oracle.rows) do
    T[string.format("%s byte %02x followed by every byte matches TextDecoder", encoding, first - 1)] = function()
      for second, expected in ipairs(row) do
        local bytes = string.char(first - 1, second - 1)
        local ok, text = pcall(require("gin.encoding").decode, bytes, encoding)
        assert(
          ok == (expected ~= false),
          string.format("acceptance mismatch at %02x %02x", first - 1, second - 1)
        )
        if ok then
          MiniTest.expect.equality(text, expected)
        end
        local replacement = require("gin.encoding").decode(bytes, encoding, { fatal = false })
        MiniTest.expect.equality(replacement, oracle.replacement_rows[first][second])
      end
    end
  end
  T[encoding .. " rejects incomplete input before trying the next candidate"] = function()
    local actual = { require("gin.encoding").detect(string.char(129), { encoding, "latin1" }) }
    MiniTest.expect.equality(actual, { vim.fn.nr2char(129), "latin1", false })
  end
end
T["Big5 candidate preserves expanding characters"] = function()
  local bytes = string.char(136, 98, 136, 100, 136, 163, 136, 165)
  local actual = { require("gin.encoding").detect(bytes, { "utf-8", "big5", "latin1" }) }
  MiniTest.expect.equality(actual, { "Ê̄Ê̌ê̄ê̌", "big5", false })
end
T["EUC-KR candidate decodes Korean text"] = function()
  local bytes = string.char(199, 209, 177, 219)
  local actual = { require("gin.encoding").detect(bytes, { "utf-8", "euc-kr", "latin1" }) }
  MiniTest.expect.equality(actual, { "한글", "euc-kr", false })
end
return T
