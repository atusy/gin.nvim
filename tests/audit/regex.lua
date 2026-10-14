-- Optional dependency audit, intentionally outside tests/test_*.lua.
local T = MiniTest.new_set()
local cases =
  vim.json.decode(table.concat(vim.fn.readfile("tests/audit/regex-oracle.json", "b"), "\n"))
for _, case in ipairs(cases) do
  T[case.name] = function()
    local result = vim
      .system({
        vim.v.progpath,
        "--headless",
        "--clean",
        "-l",
        "tests/audit/jsregexp_probe.lua",
      }, {
        env = { GIN_REGEX_CASE = vim.json.encode(case), NVIM = "", NVIM_LISTEN_ADDRESS = "" },
        text = true,
        timeout = 5000,
      })
      :wait()
    MiniTest.expect.equality(
      { code = result.code, signal = result.signal },
      { code = 0, signal = 0 }
    )
    local ok, actual = pcall(vim.json.decode, result.stdout)
    if not ok then
      error("Invalid candidate output: " .. result.stdout .. "\n" .. result.stderr)
    end
    MiniTest.expect.equality(actual, case.expected)
  end
end
return T
