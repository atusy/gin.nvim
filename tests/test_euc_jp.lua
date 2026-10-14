local T = MiniTest.new_set()
local oracle =
  vim.json.decode(table.concat(vim.fn.readfile("tests/audit/euc-jp-oracle.json", "b"), "\n"))
for _, kind in ipairs({ "rows", "triples" }) do
  for first, row in ipairs(oracle[kind]) do
    T[string.format("EUC-JP %s %02x followed by every byte matches TextDecoder", kind, first - 1)] = function()
      for second, expected in ipairs(row) do
        local bytes = string.char(first - 1, second - 1)
        if kind == "triples" then
          bytes = string.char(143) .. bytes
        end
        local ok, text = pcall(require("gin.encoding").decode, bytes, "euc-jp")
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
end
T["detection selects EUC-JP containing supplementary characters"] = function()
  local bytes = string.char(143, 162, 175, 142, 166)
  local actual = { require("gin.encoding").detect(bytes, { "utf-8", "euc-jp", "latin1" }) }
  MiniTest.expect.equality(actual, { "˘ｦ", "euc-jp", false })
end
T["incomplete supplementary character does not select EUC-JP"] = function()
  local bytes = string.char(143, 162)
  local actual = { require("gin.encoding").detect(bytes, { "euc-jp", "latin1" }) }
  MiniTest.expect.equality(actual, { vim.fn.nr2char(143) .. "¢", "latin1", false })
end
return T
