-- Optional exhaustive four-byte audit, using a digest produced directly by Deno.
local T = MiniTest.new_set()
T["all GB18030 four-byte candidates match the Deno digest"] = function()
  local oracle =
    vim.json.decode(table.concat(vim.fn.readfile("tests/audit/gb18030-oracle.json", "b"), "\n"))
  local output = {}
  local decode = require("gin.encoding").decode
  for pointer = 0, oracle.quadruples - 1 do
    local n = pointer
    local d = n % 10 + 48
    n = math.floor(n / 10)
    local c = n % 126 + 129
    n = math.floor(n / 126)
    local bytes = string.char(math.floor(n / 10) + 129, n % 10 + 48, c, d)
    local ok, text = pcall(decode, bytes, "gb18030")
    output[#output + 1] = ok and tostring(vim.fn.char2nr(text)) or "-1"
  end
  MiniTest.expect.equality(
    vim.fn.sha256(table.concat(output, "\n") .. "\n"),
    oracle.quadruple_sha256
  )
end
return T
