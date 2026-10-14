local T = MiniTest.new_set()
local oracle =
  vim.json.decode(table.concat(vim.fn.readfile("tests/audit/iso-2022-jp-oracle.json", "b"), "\n"))
for _, kind in ipairs({ "rows", "escapes" }) do
  for first, row in ipairs(oracle[kind]) do
    T[string.format(
      "ISO-2022-JP %s %02x followed by every byte matches TextDecoder",
      kind,
      first - 1
    )] = function()
      for second, expected in ipairs(row) do
        local prefix = kind == "rows" and string.char(27, 36, 66) or string.char(27)
        local bytes = prefix .. string.char(first - 1, second - 1)
        local ok, text = pcall(require("gin.encoding").decode, bytes, "iso-2022-jp")
        assert(
          ok == (expected ~= false),
          string.format("acceptance mismatch at %02x %02x", first - 1, second - 1)
        )
        MiniTest.expect.equality(
          require("gin.encoding").decode(bytes, "iso-2022-jp", { fatal = false }),
          oracle["replacement_" .. kind][first][second]
        )
        if ok then
          MiniTest.expect.equality(text, expected)
        end
      end
    end
  end
end
T["adjacent escape sequences fail even when both are valid"] = function()
  local bytes = string.char(27, 40, 74, 27, 40, 66)
  local ok = pcall(require("gin.encoding").decode, bytes, "iso-2022-jp")
  MiniTest.expect.equality(ok, false)
end
T["decoder state does not survive success or failure"] = function()
  local decode = require("gin.encoding").decode
  MiniTest.expect.equality(decode(string.char(27, 40, 74, 92), "iso-2022-jp"), "¥")
  MiniTest.expect.equality(decode(string.char(92), "iso-2022-jp"), "\\")
  local ok = pcall(decode, string.char(27, 36, 66, 36), "iso-2022-jp")
  MiniTest.expect.equality(ok, false)
  MiniTest.expect.equality(decode("ASCII", "iso-2022-jp"), "ASCII")
end
T["candidate order determines whether escape bytes are interpreted"] = function()
  local bytes = string.char(27, 36, 66, 36, 34)
  local detect = require("gin.encoding").detect
  MiniTest.expect.equality({ detect(bytes, { "utf-8", "iso-2022-jp" }) }, { bytes, "utf-8", false })
  MiniTest.expect.equality(
    { detect(bytes, { "iso-2022-jp", "utf-8" }) },
    { "あ", "iso-2022-jp", false }
  )
end
T["incomplete escapes fail before falling back"] = function()
  local bytes = string.char(27, 40)
  local actual = { require("gin.encoding").detect(bytes, { "iso-2022-jp", "utf-8" }) }
  MiniTest.expect.equality(actual, { bytes, "utf-8", false })
end
return T
