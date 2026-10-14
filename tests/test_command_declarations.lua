local T = MiniTest.new_set()

T["public command declarations match the pinned plugin"] = function()
  local upstream = vim.fn.getcwd() .. "/.deps/vim-gin"
  local script = ([=[
    local ok, err = pcall(function()
      vim.opt.runtimepath:prepend(%q)
      for _, path in ipairs(vim.fn.globpath(%q, 'plugin/*.vim', false, true)) do
        vim.cmd.source(vim.fn.fnameescape(path))
      end
      local commands = vim.api.nvim_get_commands({ builtin = false })
      for _, command in pairs(commands) do
        for field, value in pairs(command) do
          if type(value) == 'function' then command[field] = nil end
        end
      end
      io.stdout:write(vim.json.encode(commands))
    end)
    if not ok then
      io.stderr:write(tostring(err))
      vim.cmd('cquit 1')
    end
  ]=]):format(upstream, upstream)
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
  local expected = vim.json.decode(result.stdout)
  local actual = vim.api.nvim_get_commands({ builtin = false })
  local function declarations(commands)
    local selected = {}
    for name, command in pairs(commands) do
      if name:match("^Gin") then
        local fields = {}
        for _, field in ipairs({
          "bang",
          "bar",
          "nargs",
          "range",
          "count",
          "complete",
          "addr",
          "register",
        }) do
          fields[field] = command[field]
        end
        selected[name] = fields
      end
    end
    return selected
  end
  MiniTest.expect.equality(declarations(actual), declarations(expected))
end

return T
