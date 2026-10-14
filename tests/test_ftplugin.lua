local foldlevel
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      foldlevel = vim.wo.foldlevel
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
      vim.wo.foldlevel = foldlevel
    end,
  },
})
T["display options match every pinned Gin ftplugin"] = function()
  local root = vim.fn.getcwd()
  local files = {}
  for _, path in ipairs(vim.fn.glob(root .. "/.deps/vim-gin/ftplugin/gin-*.vim", false, true)) do
    files[#files + 1] = vim.fn.fnamemodify(path, ":t:r")
  end
  MiniTest.expect.equality(#files, 10)
  local function inspect(directory, extension)
    local script = ([=[
      local ok, err = pcall(function()
        vim.opt.runtimepath:prepend(%q)
        local data = vim.json.decode(%q)
        vim.opt.runtimepath:prepend(data.directory)
        local result = {}
        local options = {'list', 'spell', 'wrap', 'foldenable', 'cursorline',
          'modeline', 'buflisted', 'winfixbuf', 'foldlevel', 'commentstring',
          'comments', 'formatoptions'}
        for _, name in ipairs(data.files) do
          for _, initial in ipairs({false, true}) do
            vim.wo.winfixbuf = false
            vim.cmd.enew({bang=true})
            for _, option in ipairs(options) do
              if option == 'foldlevel' then
                vim.wo.foldlevel = 7
              elseif option == 'commentstring' then
                vim.bo.commentstring = 'custom %%s'
              elseif option == 'comments' then
                vim.bo.comments = ':custom'
              elseif option == 'formatoptions' then
                vim.bo.formatoptions = 'tcq'
              else
                vim.api.nvim_set_option_value(option, initial, {scope='local'})
              end
            end
            vim.cmd.source(data.directory .. '/ftplugin/' .. name .. data.extension)
            -- Both implementations defer the diff window's fold level.
            if name == 'gin-diff' then
              assert(vim.wait(1000, function() return vim.wo.foldlevel == 1 end))
            end
            local values = {}
            for _, option in ipairs(options) do
              values[option] = vim.api.nvim_get_option_value(option, {scope='local'})
            end
            values.did_ftplugin = vim.b.did_ftplugin
            result[name .. tostring(initial)] = values
          end
        end
        io.stdout:write(vim.json.encode(result))
      end)
      if not ok then io.stderr:write(tostring(err)); vim.cmd('cquit 1') end
    ]=]):format(
      root,
      vim.json.encode({ files = files, directory = directory, extension = extension })
    )
    local result = vim
      .system({
        vim.v.progpath,
        "--headless",
        "--clean",
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
    assert(result.code == 0, result.stderr)
    return vim.json.decode(result.stdout)
  end
  MiniTest.expect.equality(inspect(root, ".lua"), inspect(root .. "/.deps/vim-gin", ".vim"))
end
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
T["diff filetype opens top-level folds in its own window after initialization"] = function()
  local original = vim.api.nvim_get_current_win()
  vim.wo.foldlevel = 7
  vim.bo.filetype = "gin-diff"
  vim.cmd.vnew()
  local other = vim.api.nvim_get_current_win()
  vim.wo.foldlevel = 4
  require("tests.helpers").drain()
  local levels = { vim.wo[original].foldlevel, vim.wo[other].foldlevel }
  vim.api.nvim_win_close(other, true)
  MiniTest.expect.equality(levels, { 1, 4 })
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
