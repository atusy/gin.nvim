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
return T
