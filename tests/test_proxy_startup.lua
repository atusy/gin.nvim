local H = require("tests.helpers")
local child = MiniTest.new_child_neovim()
local project = vim.fn.getcwd()
local root
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      child.start({ "-u", "NONE" })
      child.lua([[vim.opt.rtp:prepend(...)]], { project })
      child.api.nvim_set_current_dir(root)
      child.cmd("filetype plugin on")
      child.lua([[
        for _, key in ipairs({ 'GIT_EDITOR', 'GIT_ASKPASS', 'GIN_EDITOR_ADDRESS', 'GIT_SEQUENCE_EDITOR' }) do
          vim.env[key] = nil
        end
      ]])
    end,
    post_case = function()
      child.stop()
      H.cleanup(root)
    end,
  },
})

T["terminal Git inherits the editor proxy at plugin startup"] = function()
  vim.fn.writefile({ "content" }, root .. "/file")
  H.git(root, "add", "file")
  child.cmd("runtime plugin/gin-proxy.lua")
  child.lua([[
    vim.fn.termopen({ 'git', '-c', 'core.editor=false', 'commit' }, {
      on_exit = function(_, code) _G.gin_terminal_exit = code end,
    })
  ]])
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return child.lua_get("vim.b.gin_editor_request ~= nil or _G.gin_terminal_exit ~= nil")
    end, 10),
    true
  )
  MiniTest.expect.equality(child.lua_get("vim.b.gin_editor_request ~= nil"), true)
  child.type_keys("gg0i", "terminal commit", "<Esc>", ":Apply<CR>")
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return child.lua_get("_G.gin_terminal_exit ~= nil")
    end, 10),
    true
  )
  MiniTest.expect.equality(child.lua_get("_G.gin_terminal_exit"), 0)
  MiniTest.expect.equality(H.git(root, "log", "-1", "--format=%s"), "terminal commit\n")
  MiniTest.expect.equality(H.git(root, "show", "HEAD:file"), "content\n")
end
for _, restart in ipairs({ false, true }) do
  T[restart and "terminal askpass follows a listener recreated by Gin" or "terminal Git inherits askpass without a Gin command"] = function()
    child.cmd("runtime plugin/gin-proxy.lua")
    if restart then
      child.lua("vim.fn.serverstop(vim.env.GIN_EDITOR_ADDRESS)")
      child.cmd("runtime plugin/gin.lua")
      child.cmd("silent Gin ++wait status --short")
    end
    child.lua([[
    _G.gin_prompts = {}
    vim.fn.inputsecret = function(prompt)
      table.insert(_G.gin_prompts, prompt)
      return #_G.gin_prompts == 1 and 'terminal-user' or 'terminal-password'
    end
    vim.env.GIT_TERMINAL_PROMPT = '0'
    _G.gin_terminal_output = ''
    vim.fn.termopen({ 'sh', '-c', "printf 'protocol=https\\nhost=example.invalid\\n\\n' | git -c credential.helper= credential fill" }, {
      on_stdout = function(_, lines)
        _G.gin_terminal_output = _G.gin_terminal_output .. table.concat(lines, '\n')
      end,
      on_exit = function(_, code) _G.gin_terminal_exit = code end,
    })
  ]])
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return child.lua_get("_G.gin_terminal_exit ~= nil")
      end, 10),
      true
    )
    MiniTest.expect.equality(child.lua_get("_G.gin_terminal_exit"), 0)
    local prompts = child.lua_get("_G.gin_prompts")
    MiniTest.expect.equality(#prompts, 2)
    MiniTest.expect.equality(prompts[1]:find("Username", 1, true) ~= nil, true)
    MiniTest.expect.equality(prompts[2]:find("Password", 1, true) ~= nil, true)
    local output = child.lua_get("_G.gin_terminal_output")
    MiniTest.expect.equality(output:find("username=terminal-user", 1, true) ~= nil, true)
    MiniTest.expect.equality(output:find("password=terminal-password", 1, true) ~= nil, true)
  end
end

T["listener recovery preserves a separately configured process address"] = function()
  child.cmd("runtime plugin/gin-proxy.lua")
  child.lua([[
    local old = vim.env.GIN_EDITOR_ADDRESS
    vim.fn.serverstop(old)
    vim.env.GIN_EDITOR_ADDRESS = 'separate-listener'
    local env = require('gin.editor').environment()
    assert(vim.tbl_contains(vim.fn.serverlist(), env.GIN_EDITOR_ADDRESS))
  ]])
  MiniTest.expect.equality(child.lua_get("vim.env.GIN_EDITOR_ADDRESS"), "separate-listener")
end

for _, editor in ipairs({ false, true }) do
  for _, askpass in ipairs({ false, true }) do
    T["startup respects independent opt-outs editor=" .. tostring(editor) .. " askpass=" .. tostring(
      askpass
    )] = function()
      child.lua([[
        vim.env.GIT_EDITOR = 'existing-editor'
        vim.env.GIT_ASKPASS = 'existing-askpass'
        vim.g.loaded_gin = 1
      ]])
      child.g.gin_proxy_disable_editor = editor
      child.g.gin_proxy_disable_askpass = askpass
      child.cmd("runtime plugin/gin-proxy.lua")
      local env =
        child.lua_get("{vim.env.GIT_EDITOR, vim.env.GIT_ASKPASS, vim.env.GIN_EDITOR_ADDRESS}")
      MiniTest.expect.equality(env[1] == "existing-editor", editor)
      MiniTest.expect.equality(env[2] == "existing-askpass", askpass)
      MiniTest.expect.equality(env[3] ~= nil, not (editor and askpass))
      child.cmd("runtime plugin/gin-proxy.lua")
      MiniTest.expect.equality(
        child.lua_get("{vim.env.GIT_EDITOR, vim.env.GIT_ASKPASS, vim.env.GIN_EDITOR_ADDRESS}"),
        env
      )
    end
  end
end
return T
