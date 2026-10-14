local T = MiniTest.new_set()

T["feature loaded markers disable only their own commands and URI handlers"] = function()
  local groups = {
    gin = { commands = { "Gin", "GinBuffer" }, schemes = { "gin" } },
    cd = { commands = { "GinCd", "GinLcd", "GinTcd" } },
    blame = { commands = { "GinBlame" }, schemes = { "ginblame", "ginblamenav" } },
    branch = { commands = { "GinBranch" }, schemes = { "ginbranch" } },
    browse = { commands = { "GinBrowse" } },
    chaperon = { commands = { "GinChaperon" } },
    diff = { commands = { "GinDiff" }, schemes = { "gindiff" } },
    edit = { commands = { "GinEdit" }, schemes = { "ginedit" } },
    log = { commands = { "GinLog" }, schemes = { "ginlog" } },
    patch = { commands = { "GinPatch" } },
    reflog = { commands = { "GinReflog" }, schemes = { "ginreflog" } },
    stash = { commands = { "GinStash" }, schemes = { "ginstash" } },
    status = { commands = { "GinStatus" }, schemes = { "ginstatus" } },
    tag = { commands = { "GinTag" }, schemes = { "gintag" } },
  }
  for disabled in pairs(groups) do
    for _, value in ipairs({ "v:false", "1" }) do
      local script = ([=[
        local ok, err = pcall(function()
          local root, groups, disabled = %q, vim.json.decode(%q), %q
          vim.opt.runtimepath:prepend(root)
          local marker = disabled == 'gin' and 'loaded_gin' or 'loaded_gin_' .. disabled
          vim.cmd('let g:' .. marker .. ' = ' .. %q)
          local function source()
            for _, path in ipairs(vim.fn.globpath(root, 'plugin/*.lua', false, true)) do
              vim.cmd.source(vim.fn.fnameescape(path))
            end
          end
          source()
          for feature, group in pairs(groups) do
            for _, command in ipairs(group.commands) do
              assert((vim.api.nvim_get_commands({ builtin = false })[command] ~= nil) == (feature ~= disabled), command)
            end
            for _, scheme in ipairs(group.schemes or {}) do
              local handlers = vim.api.nvim_get_autocmds({ event = 'BufReadCmd', pattern = scheme .. '://*' })
              assert(#handlers == (feature == disabled and 0 or 1), scheme)
              if feature == disabled then
                for _, event in ipairs({ 'FileReadCmd', 'BufWriteCmd' }) do
                  assert(#vim.api.nvim_get_autocmds({ event = event, pattern = scheme .. '://*' }) == 0, event .. scheme)
                end
              end
            end
            local name = feature == 'gin' and 'loaded_gin' or 'loaded_gin_' .. feature
            assert(vim.fn.exists('g:' .. name) == 1, name)
          end
          assert(vim.g[marker] == (%q == '1' and 1 or false), 'marker overwritten')
          assert(vim.fn.exists('#User#GinCommandPost') == (disabled == 'gin' and 0 or 1))
          local count = #vim.api.nvim_get_autocmds({})
          source()
          assert(#vim.api.nvim_get_autocmds({}) == count, 'duplicate registration')
        end)
        if not ok then io.stderr:write(tostring(err)); vim.cmd('cquit 1') end
      ]=]):format(vim.fn.getcwd(), vim.json.encode(groups), disabled, value, value)
      local result = vim
        .system({
          vim.v.progpath,
          "--headless",
          "-u",
          "NONE",
          "-i",
          "NONE",
          "-c",
          "lua " .. script,
          "-c",
          "qa!",
        }, { text = true })
        :wait(10000)
      assert(result.code == 0, disabled .. "=" .. value .. ": " .. result.stderr)
    end
  end
end

return T
