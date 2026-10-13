local H = require("tests.helpers")
local root
local inputsecret = vim.fn.inputsecret
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
    end,
    post_case = function()
      vim.fn.inputsecret = inputsecret
      vim.g.gin_proxy_disable_askpass = nil
      vim.g.gin_proxy_disable_editor = nil
      H.cleanup(root)
    end,
  },
})
T["Git obtains credentials through masked Neovim prompts"] = function()
  local prompts = {}
  vim.fn.inputsecret = function(prompt)
    prompts[#prompts + 1] = prompt
    return #prompts == 1 and "unit-user" or "unit-password"
  end
  local env = require("gin.editor").environment()
  env.GIT_TERMINAL_PROMPT = "0"
  local result
  require("gin.git").start({ "-c", "credential.helper=", "credential", "fill" }, {
    cwd = root,
    env = env,
    stdin = "protocol=https\nhost=example.invalid\n\n",
  }, function(value)
    result = value
  end)
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return result ~= nil
    end, 10),
    true
  )
  assert(result.code == 0, result.stderr)
  MiniTest.expect.equality(result.code, 0)
  MiniTest.expect.equality(#prompts, 2)
  MiniTest.expect.equality(prompts[1]:find("Username", 1, true) ~= nil, true)
  MiniTest.expect.equality(prompts[2]:find("Password", 1, true) ~= nil, true)
  MiniTest.expect.equality(result.stdout:find("username=unit-user\n", 1, true) ~= nil, true)
  MiniTest.expect.equality(result.stdout:find("password=unit-password\n", 1, true) ~= nil, true)
end
T["interrupted askpass fails Git without returning a credential"] = function()
  vim.fn.inputsecret = function()
    error("interrupted")
  end
  local env = require("gin.editor").environment()
  env.GIT_TERMINAL_PROMPT = "0"
  local result
  require("gin.git").start({ "-c", "credential.helper=", "credential", "fill" }, {
    cwd = root,
    env = env,
    stdin = "protocol=https\nhost=example.invalid\n\n",
  }, function(value)
    result = value
  end)
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return result ~= nil
    end, 10),
    true
  )
  MiniTest.expect.equality(result.code ~= 0, true)
  MiniTest.expect.equality(result.stdout, "")
end
T["editor and askpass proxy opt-outs are independent"] = function()
  vim.g.gin_proxy_disable_editor = 1
  local env = require("gin.editor").environment()
  MiniTest.expect.equality(env.GIT_EDITOR, nil)
  MiniTest.expect.equality(vim.fn.executable(env.GIT_ASKPASS), 1)
  vim.g.gin_proxy_disable_editor = 0
  vim.g.gin_proxy_disable_askpass = 1
  env = require("gin.editor").environment()
  MiniTest.expect.equality(type(env.GIT_EDITOR), "string")
  MiniTest.expect.equality(env.GIT_ASKPASS, nil)
  vim.g.gin_proxy_disable_editor = 1
  MiniTest.expect.equality(require("gin.editor").environment(), nil)
end
return T
