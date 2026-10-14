local T = MiniTest.new_set()

T["fold presets autoload before plugin initialization"] = function()
  local check = [[
    local ok, err = pcall(function()
      assert(vim.g.loaded_gin == nil)
      vim.cmd('let g:gin_difffold_prefixes = g:gin#difffold#prefixes_nerdfont')
      assert(vim.deep_equal(vim.g.gin_difffold_prefixes, {
        added = ' ', deleted = ' ', modified = ' ', renamed = ' ',
      }))
      vim.cmd('let g:gin_difffold_prefixes = g:gin#difffold#prefixes_ascii')
      assert(vim.deep_equal(vim.g.gin_difffold_prefixes, {
        added = '[+]', deleted = '[-]', modified = '[.]', renamed = '[/]',
      }))
      assert(vim.g.loaded_gin == nil)
    end)
    if not ok then
      io.stderr:write(tostring(err) .. '\n')
      vim.cmd('cquit 1')
    end
  ]]
  local result = vim
    .system({
      vim.v.progpath,
      "--headless",
      "-u",
      "NONE",
      "-i",
      "NONE",
      "--cmd",
      "set runtimepath^=" .. vim.fn.fnameescape(vim.fn.getcwd()),
      "-c",
      "lua " .. check,
      "-c",
      "qa!",
    }, { text = true })
    :wait(10000)
  assert(result.code == 0, result.stderr)
end

T["public User events exist immediately after plugin startup"] = function()
  local result = vim
    .system({
      vim.v.progpath,
      "--headless",
      "-u",
      "NONE",
      "-i",
      "NONE",
      "--cmd",
      "set runtimepath^=" .. vim.fn.fnameescape(vim.fn.getcwd()),
      "-c",
      "runtime plugin/gin.lua",
      "-c",
      [[lua local ok, err = pcall(function()
      for _, event in ipairs({ 'GinCommandPost', 'GinComponentPost' }) do
        assert(vim.fn.exists('#User#' .. event) == 1, event .. ' is not registered')
        vim.api.nvim_exec_autocmds('User', { pattern = event })
      end
    end)
    if not ok then io.stderr:write(tostring(err)); vim.cmd('cquit 1') end]],
      "-c",
      "qa!",
    }, { text = true })
    :wait(10000)
  assert(result.code == 0, result.stderr)
end

return T
