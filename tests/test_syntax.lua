local enabled
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      enabled = vim.g.syntax_on ~= nil
      vim.cmd("syntax enable")
      vim.cmd.enew()
    end,
    post_case = function()
      vim.cmd.bwipeout({ bang = true })
      if not enabled then
        vim.cmd("syntax off")
      end
    end,
  },
})
for kind, spec in pairs({
  tag = {
    line = "abcdef012 release 2026-10-14 release notes",
    groups = { abcdef012 = "Hash", release = "Name", ["2026-10-14"] = "Date", notes = "Subject" },
  },
  stash = {
    line = "stash@{12}: WIP on topic: abcdef012 changes",
    groups = { ["stash@{12}"] = "Ref", WIP = "Type", topic = "Branch", abcdef012 = "Hash" },
  },
  reflog = {
    line = "abcdef012 (HEAD -> main) HEAD@{12}: commit: changes",
    groups = { abcdef012 = "Hash", main = "Deco", ["HEAD@{12}"] = "Selector", commit = "Action" },
  },
}) do
  T[kind .. " syntax identifies native list fields"] = function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { spec.line })
    vim.bo.syntax = "gin-" .. kind
    for text, suffix in pairs(spec.groups) do
      local column = assert(spec.line:find(text, 1, true))
      MiniTest.expect.equality(
        vim.fn.synIDattr(vim.fn.synID(1, column, 1), "name"),
        "Gin" .. kind:gsub("^%l", string.upper) .. suffix
      )
    end
    MiniTest.expect.equality(vim.b.current_syntax, "gin_" .. kind)
  end
end
return T
