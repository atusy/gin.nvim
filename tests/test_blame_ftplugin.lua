local runtime, fixture
local project = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      runtime = vim.o.runtimepath
      fixture = vim.fn.tempname()
      vim.fn.mkdir(fixture .. "/ftplugin", "p")
      vim.fn.mkdir(fixture .. "/after/ftplugin", "p")
      vim.fn.writefile({
        "let b:did_ftplugin = 1",
        "let &l:commentstring = 'host %s'",
        "let b:undo_ftplugin = 'setlocal commentstring<'",
      }, fixture .. "/ftplugin/ginhost.vim")
      vim.fn.writefile(
        { "nnoremap <buffer> <C-O> host-older" },
        fixture .. "/after/ftplugin/ginhost.vim"
      )
      vim.opt.rtp:prepend(fixture)
      vim.opt.rtp:append(fixture .. "/after")
      vim.opt.rtp:append(project .. "/after")
      vim.cmd("filetype plugin on")
      vim.cmd.enew()
    end,
    post_case = function()
      vim.cmd.bwipeout({ bang = true })
      vim.g.gin_blame_disable_default_mappings = nil
      vim.o.runtimepath = runtime
      vim.fn.delete(fixture, "rf")
    end,
  },
})
T["compound blame filetypes install navigation after the host ftplugin"] = function()
  vim.bo.filetype = "ginhost.gin-blame"
  MiniTest.expect.equality(vim.bo.commentstring, "host %s")
  MiniTest.expect.equality(vim.fn.maparg("<C-O>", "n"), "<Plug>(gin-blame-navigate-older)")
  MiniTest.expect.equality(vim.fn.maparg("<CR>", "n"), "<Plug>(gin-blame-switch-commit)")
  MiniTest.expect.equality(
    type(vim.fn.maparg("<Plug>(gin-blame-switch-commit)", "n", false, true).callback),
    "function"
  )
end
T["compound blame respects disabled defaults while retaining Plug mappings"] = function()
  vim.g.gin_blame_disable_default_mappings = 1
  vim.bo.filetype = "ginhost.gin-blame"
  MiniTest.expect.equality(vim.bo.commentstring, "host %s")
  MiniTest.expect.equality(vim.fn.maparg("<C-O>", "n"), "host-older")
  MiniTest.expect.equality(vim.fn.maparg("<CR>", "n"), "")
  MiniTest.expect.equality(
    type(vim.fn.maparg("<Plug>(gin-blame-navigate-older)", "n", false, true).callback),
    "function"
  )
end
T["compound blame reload preserves user mapping changes"] = function()
  vim.bo.filetype = "ginhost.gin-blame"
  vim.keymap.set("n", "<CR>", "user-enter", { buffer = 0 })
  vim.keymap.del("n", "<C-O>", { buffer = 0 })
  vim.keymap.set("n", "<Plug>(gin-blame-switch-commit)", "user-switch", { buffer = 0 })
  local undo = vim.b.undo_ftplugin
  vim.cmd.source(project .. "/after/ftplugin/gin-blame.lua")
  require("gin.ftplugin").blame_mappings(vim.api.nvim_get_current_buf())
  MiniTest.expect.equality(vim.fn.maparg("<CR>", "n"), "user-enter")
  MiniTest.expect.equality(vim.fn.maparg("<C-O>", "n"), "")
  MiniTest.expect.equality(vim.fn.maparg("<Plug>(gin-blame-switch-commit)", "n"), "user-switch")
  MiniTest.expect.equality(vim.b.undo_ftplugin, undo)
end
T["compound blame cleanup retains the host undo and allows reinitialization"] = function()
  vim.bo.filetype = "ginhost.gin-blame"
  vim.bo.filetype = "text"
  MiniTest.expect.equality(vim.bo.commentstring, vim.go.commentstring)
  MiniTest.expect.equality(vim.fn.maparg("<CR>", "n"), "")
  MiniTest.expect.equality(vim.fn.maparg("<Plug>(gin-blame-switch-commit)", "n"), "")
  vim.bo.filetype = "ginhost.gin-blame"
  MiniTest.expect.equality(vim.bo.commentstring, "host %s")
  MiniTest.expect.equality(vim.fn.maparg("<C-O>", "n"), "<Plug>(gin-blame-navigate-older)")
end
T["built-in Lua ftplugin and blame navigation coexist"] = function()
  vim.bo.filetype = "lua.gin-blame"
  MiniTest.expect.equality(vim.bo.commentstring, "-- %s")
  MiniTest.expect.equality(vim.fn.maparg("<C-O>", "n"), "<Plug>(gin-blame-navigate-older)")
  MiniTest.expect.equality(vim.fn.maparg("<CR>", "n"), "<Plug>(gin-blame-switch-commit)")
end
return T
