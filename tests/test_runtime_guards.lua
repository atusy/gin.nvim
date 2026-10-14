local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      vim.cmd.enew()
    end,
    post_case = function()
      vim.cmd.bwipeout({ bang = true })
    end,
  },
})

T["buffer loaded markers use presence for syntax and ftplugins"] = function()
  for _, directory in ipairs({ "syntax", "ftplugin" }) do
    local marker = directory == "syntax" and "current_syntax" or "did_ftplugin"
    for _, path in ipairs(vim.fn.globpath(vim.fn.getcwd(), directory .. "/*.lua", false, true)) do
      vim.b[marker] = false
      vim.cmd("syntax match GinGuardSentinel /guard/")
      local function state()
        return {
          marker = vim.b[marker],
          syntax = vim.fn.execute("syntax list GinGuardSentinel"),
          maps = vim.api.nvim_buf_get_keymap(0, "n"),
          options = {
            vim.wo.list,
            vim.wo.spell,
            vim.wo.wrap,
            vim.wo.foldenable,
            vim.wo.cursorline,
            vim.bo.buflisted,
            vim.bo.modeline,
          },
        }
      end
      local before = state()
      dofile(path)
      MiniTest.expect.equality(state(), before)
      vim.b[marker] = nil
    end
  end
end

return T
