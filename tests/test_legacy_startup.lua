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

return T
