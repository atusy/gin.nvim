local T = MiniTest.new_set()
T["generated JavaScript comparisons"] = function()
  local path =
    assert(vim.env.GIN_REGEX_DIFFERENTIAL_FILE, "Generate the differential fixture first")
  local fixture = vim.json.decode(table.concat(vim.fn.readfile(path, "b"), "\n"))
  assert(#fixture.cases > 0, "Empty differential corpus")
  local backend = require("gin.regex")
  local failures = {}
  for _, case in ipairs(fixture.cases) do
    local compiled, regex = pcall(backend.compile, case.pattern)
    local actual
    if not compiled then
      actual = { status = "compile-error" }
    else
      local matched, captures = pcall(regex.match, regex, case.input)
      if not matched then
        actual = { status = "runtime-error", error = tostring(captures) }
      else
        actual = captures and { status = "match", captures = captures } or { status = "no-match" }
      end
    end
    if not vim.deep_equal(actual, case.expected) then
      failures[#failures + 1] = {
        pattern = case.pattern,
        input = case.input,
        expected = case.expected,
        actual = actual,
      }
    end
  end
  assert(vim.fn.writefile({
    vim.json.encode({ compared = #fixture.cases, failures = failures }),
  }, path .. ".result.json", "b") == 0, "Could not write differential result")
  if #failures > 0 then
    error(
      ("%d/%d mismatches; full report: %s.result.json\n%s"):format(
        #failures,
        #fixture.cases,
        path,
        vim.inspect(vim.list_slice(failures, 1, math.min(10, #failures)))
      )
    )
  end
end
return T
