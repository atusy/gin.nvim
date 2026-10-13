local buf
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      buf = vim.api.nvim_create_buf(false, true)
    end,
    post_case = function()
      vim.api.nvim_buf_delete(buf, { force = true })
    end,
  },
})

T["log selects only the pinned default commit header grammar"] = function()
  local cases = {
    { "abc1234", "abc1234" },
    { "ABC1234 subject", "ABC1234" },
    { "a", "a" },
    { "ab subject", "ab" },
    { "abc subject", "abc" },
    { "| * /\\+-=<> abc1234", "abc1234" },
    { "| * commit abc1234", "abc1234" },
    { "commit + abc1234", "abc1234" },
    { "commit - abc1234", "abc1234" },
    { "commit = abc1234", "abc1234" },
    { "commit < abc1234", "abc1234" },
    { "commit > abc1234", "abc1234" },
    { "abc1234: subject", "abc1234" },
    { "abc1234é", "abc1234" },
    { "commit +abc1234" },
    { "commit  abc1234" },
    { "commit +  abc1234" },
    { "commit\tabc1234" },
    { "\tabc1234" },
    { "abc1234_suffix" },
    { "abc1234word" },
    { "% abc1234" },
    { "|/|\\" },
    { "" },
  }
  for _, case in ipairs(cases) do
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { case[1] })
    MiniTest.expect.equality(
      require("gin.log").candidates(buf, { 1, 1 }),
      case[2] and { { commit = case[2] } } or {}
    )
  end
end

return T
