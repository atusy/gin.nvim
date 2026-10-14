local T = MiniTest.new_set()
local cases =
  vim.json.decode(table.concat(vim.fn.readfile("tests/audit/regex-oracle.json", "b"), "\n"))
for _, case in ipairs(cases) do
  T[case.name] = function()
    local backend = require("tests.audit.lua_regex")
    local ok, regex = pcall(backend.compile, case.pattern)
    local actual
    if not ok then
      actual = { status = "compile-error" }
    else
      local captures = regex:match(case.input)
      actual = captures and { status = "match", captures = captures } or { status = "no-match" }
    end
    MiniTest.expect.equality(actual, case.expected)
  end
end
local long_cases = {
  { "greedy repetition", "^(a+)$", { 65536 } },
  { "greedy backtracking", "^(a+)(a)$", { 65535, 1 } },
  { "lazy repetition", "^(a+?)(a)$", { 65535, 1 } },
  { "repeated capture", "^(a)+$", { 1 } },
  { "repeated alternatives", "^((?:a|b)+)$", { 65536 } },
  { "lookbehind repetition", "^(a+)(?<=a+)$", { 65536 } },
}
for _, case in ipairs(long_cases) do
  T["long input: " .. case[1]] = function()
    local text = string.rep("a", 65536)
    local regex = require("tests.audit.lua_regex").compile(case[2])
    -- Avoid depending on JIT trace history to conceal call-stack exhaustion.
    local enabled = jit.status()
    jit.off()
    local ok, result = pcall(regex.match, regex, text)
    if enabled then
      jit.on()
    end
    assert(ok, result)
    local function repeated(length)
      local units = {}
      for index = 1, length do
        units[index] = 97
      end
      return units
    end
    local expected = { repeated(#text) }
    for _, length in ipairs(case[3]) do
      expected[#expected + 1] = repeated(length)
    end
    MiniTest.expect.equality(result, expected)
  end
end
T["string captures preserve Unicode, NUL and unmatched groups"] = function()
  local regex = require("tests.audit.lua_regex").compile("^(a)?(.+)(b*)$")
  MiniTest.expect.equality(regex:match_strings("β😀\0"), { "β😀\0", vim.NIL, "β😀\0", "" })
end
T["string conversion rejects selected lone surrogates"] = function()
  local regex = require("tests.audit.lua_regex").compile("^(.)(.)$")
  MiniTest.expect.error(function()
    regex:match_strings("😀")
  end, "unpaired surrogate")
  MiniTest.expect.error(function()
    regex:match_strings("😀", { 3 })
  end, "unpaired surrogate")
end
T["string conversion can select only fields consumed by the parser"] = function()
  local regex = require("tests.audit.lua_regex").compile("^(.)()")
  MiniTest.expect.equality(regex:match_strings("😀", { 3, 4 }), { "", vim.NIL })
end
T["string conversion preserves UTF-8 encoding boundaries"] = function()
  local parts = { "\0" }
  for _, cp in ipairs({ 0x7F, 0x80, 0x7FF, 0x800, 0xFFFF, 0x10000, 0x10FFFF }) do
    parts[#parts + 1] = vim.fn.nr2char(cp)
  end
  local text = table.concat(parts)
  MiniTest.expect.equality(
    require("tests.audit.lua_regex").compile("^([\\s\\S]*)$"):match_strings(text),
    { text, text }
  )
end
T["string conversion preserves no-match and empty matches"] = function()
  local regex = require("tests.audit.lua_regex").compile("^(a)?$")
  MiniTest.expect.equality(regex:match_strings("b"), nil)
  MiniTest.expect.equality(regex:match_strings(""), { "", vim.NIL })
  MiniTest.expect.equality(regex:match_strings("a"), { "a", "a" })
end
return T
