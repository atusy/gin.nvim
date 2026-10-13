local T = MiniTest.new_set()
T["upstream is locked to the requested revision"] = function()
  local result = vim
    .system({ "git", "-C", ".deps/vim-gin", "rev-parse", "HEAD" }, { text = true })
    :wait()
  MiniTest.expect.equality(result.code, 0)
  MiniTest.expect.equality(vim.trim(result.stdout), "24cce091cfa32c013bc53cf4ff8f721d6690cf24")
end
return T
