local buf
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      buf = vim.api.nvim_create_buf(false, true)
    end,
    post_case = function()
      for _, kind in ipairs({ "log", "reflog", "tag", "stash" }) do
        vim.g["gin_" .. kind .. "_parse_pattern"] = nil
      end
      vim.api.nvim_buf_delete(buf, { force = true })
    end,
  },
})
local cases =
  vim.json.decode(table.concat(vim.fn.readfile("tests/audit/parser-oracle.json", "b"), "\n"))
for _, case in ipairs(cases) do
  T[case.kind .. ": " .. case.pattern] = function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, case.lines)
    vim.g["gin_" .. case.kind .. "_parse_pattern"] = case.pattern
    local ok, result = pcall(require("gin.candidate").custom, buf, { 1, #case.lines }, case.kind)
    local actual = ok and { status = "ok", entries = result } or { status = "error" }
    if ok then
      for _, entry in ipairs(result) do
        MiniTest.expect.equality(vim.islist(entry), false)
      end
    end
    -- JSON distinguishes an empty object from an empty array, as upstream echo does.
    MiniTest.expect.equality(vim.json.decode(vim.json.encode(actual)), case.expected)
  end
end
return T
