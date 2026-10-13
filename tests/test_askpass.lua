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
T["synchronous progress commands service the configured askpass proxy"] = function()
  local prompts = {}
  vim.fn.inputsecret = function(prompt)
    prompts[#prompts + 1] = prompt
    return #prompts == 1 and "unit-user" or "unit-password"
  end
  local more, height = vim.o.more, vim.o.cmdheight
  local result = require("gin.git").run({ "-c", "credential.helper=", "credential", "fill" }, {
    cwd = root,
    env = { GIT_TERMINAL_PROMPT = "0" },
    stdin = "protocol=https\nhost=example.invalid\n\n",
    progress = true,
    timeout = 5000,
  })
  MiniTest.expect.equality(result.code, 0)
  MiniTest.expect.equality(#prompts, 2)
  MiniTest.expect.equality(result.stdout:find("username=unit-user\n", 1, true) ~= nil, true)
  MiniTest.expect.equality(result.stdout:find("password=unit-password\n", 1, true) ~= nil, true)
  MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { more, height })
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
T["synchronous proxy opt-out keeps credential requests noninteractive"] = function()
  vim.g.gin_proxy_disable_askpass = 1
  local prompts = 0
  vim.fn.inputsecret = function()
    prompts = prompts + 1
    return "unexpected"
  end
  local result = require("gin.git").run({ "-c", "credential.helper=", "credential", "fill" }, {
    cwd = root,
    env = { GIT_TERMINAL_PROMPT = "0" },
    stdin = "protocol=https\nhost=example.invalid\n\n",
    progress = true,
    check = false,
    timeout = 5000,
  })
  MiniTest.expect.equality(result.code ~= 0, true)
  MiniTest.expect.equality(result.stdout, "")
  MiniTest.expect.equality(prompts, 0)
end
T["synchronous output processors service askpass requests"] = function()
  local prompts = 0
  vim.fn.inputsecret = function()
    prompts = prompts + 1
    return prompts == 1 and "unit-user" or "unit-password"
  end
  local result = require("gin.git").run({
    "-c",
    [[alias.request=!printf 'protocol=https\nhost=example.invalid\n\n']],
    "request",
  }, {
    cwd = root,
    env = { GIT_TERMINAL_PROMPT = "0" },
    processor = { "git", "-c", "credential.helper=", "credential", "fill" },
    progress = true,
    timeout = 5000,
  })
  MiniTest.expect.equality(result.code, 0)
  MiniTest.expect.equality(prompts, 2)
  MiniTest.expect.equality(result.stdout:find("username=unit-user\n", 1, true) ~= nil, true)
  MiniTest.expect.equality(result.stdout:find("password=unit-password\n", 1, true) ~= nil, true)
end
for _, wait in ipairs({ true, false }) do
  T[(wait and "waiting" or "asynchronous") .. " Gin processors inherit askpass environment"] = function()
    local prompts, completed = 0, nil
    vim.fn.inputsecret = function()
      prompts = prompts + 1
      return prompts == 1 and "unit-user" or "unit-password"
    end
    local terminal = vim.env.GIT_TERMINAL_PROMPT
    vim.env.GIT_TERMINAL_PROMPT = "0"
    local ok, err = pcall(function()
      require("gin.command").execute({
        fargs = vim.list_extend(wait and { "++wait" } or {}, {
          "++worktree=" .. root,
          "++processor=git -c credential.helper= credential fill",
          "-c",
          [[alias.request=!printf 'protocol=https\nhost=example.invalid\n\n']],
          "request",
        }),
        smods = { silent = true, emsg_silent = true },
        on_exit = function(value)
          completed = value
        end,
      })
      MiniTest.expect.equality(
        vim.wait(5000, function()
          return completed ~= nil
        end, 10),
        true
      )
      MiniTest.expect.equality(completed.code, 0)
      MiniTest.expect.equality(prompts, 2)
      MiniTest.expect.equality(
        completed.stdout:find("password=unit-password\n", 1, true) ~= nil,
        true
      )
    end)
    vim.env.GIT_TERMINAL_PROMPT = terminal
    assert(ok, err)
  end
end
return T
