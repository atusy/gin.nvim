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
return T
