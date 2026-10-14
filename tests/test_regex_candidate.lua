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
return T
