local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      vim.cmd("filetype plugin on")
      vim.cmd.enew()
      vim.wo.list, vim.wo.spell, vim.wo.wrap, vim.wo.foldenable = true, true, true, true
      vim.wo.cursorline = false
      vim.bo.modeline, vim.bo.buflisted = true, true
    end,
    post_case = function()
      if vim.b.undo_ftplugin then
        vim.cmd(vim.b.undo_ftplugin)
        vim.b.undo_ftplugin = nil
      end
      vim.cmd.bwipeout({ bang = true })
      vim.wo.winfixbuf = false
    end,
  },
})
for _, kind in ipairs({ "branch", "status", "log", "reflog", "tag", "stash" }) do
  T[kind .. " filetype applies and undoes list display options"] = function()
    vim.bo.filetype = "gin-" .. kind
    MiniTest.expect.equality(
      { vim.wo.list, vim.wo.spell, vim.wo.wrap, vim.wo.foldenable, vim.bo.modeline },
      { false, false, false, false, false }
    )
    MiniTest.expect.equality(vim.bo.buflisted, kind == "branch")
    MiniTest.expect.equality(vim.wo.cursorline, kind ~= "branch" and kind ~= "status")
    MiniTest.expect.equality(vim.b.did_ftplugin, 1)
    vim.cmd(vim.b.undo_ftplugin)
    vim.b.undo_ftplugin = nil
    for _, name in ipairs({ "list", "spell", "wrap", "foldenable", "modeline" }) do
      MiniTest.expect.equality(
        vim.api.nvim_get_option_value(name, { scope = "local" }),
        vim.api.nvim_get_option_value(name, { scope = "global" })
      )
    end
  end
end
T["diff filetype inherits and undoes the runtime diff settings"] = function()
  vim.bo.commentstring = "custom %s"
  vim.bo.filetype = "gin-diff"
  MiniTest.expect.equality(vim.bo.modeline, false)
  MiniTest.expect.equality(vim.bo.commentstring, "# %s")
  MiniTest.expect.equality(vim.b.did_ftplugin, 1)
  vim.cmd(vim.b.undo_ftplugin)
  vim.b.undo_ftplugin = nil
  MiniTest.expect.equality(vim.bo.modeline, vim.go.modeline)
  MiniTest.expect.equality(vim.bo.commentstring, vim.go.commentstring)
end
T["blame filetypes install and undo navigation without a blame read"] = function()
  for _, kind in ipairs({ "gin-blame", "gin-blame-nav" }) do
    vim.bo.filetype = kind
    MiniTest.expect.equality(vim.b.did_ftplugin, 1)
    MiniTest.expect.equality(vim.wo.winfixbuf, true)
    for key, action in pairs({
      ["<CR>"] = "switch-commit",
      ["<C-O>"] = "navigate-older",
      ["<C-I>"] = "navigate-newer",
    }) do
      local plug = "<Plug>(gin-blame-" .. action .. ")"
      MiniTest.expect.equality(vim.fn.maparg(key, "n"), plug)
      MiniTest.expect.equality(type(vim.fn.maparg(plug, "n", false, true).callback), "function")
    end
    vim.bo.filetype = "text"
    MiniTest.expect.equality(vim.wo.winfixbuf, vim.go.winfixbuf)
    for _, key in ipairs({
      "<CR>",
      "<C-O>",
      "<C-I>",
      "<Plug>(gin-blame-switch-commit)",
      "<Plug>(gin-blame-navigate-older)",
      "<Plug>(gin-blame-navigate-newer)",
    }) do
      MiniTest.expect.equality(vim.fn.maparg(key, "n"), "")
    end
  end
end

return T
