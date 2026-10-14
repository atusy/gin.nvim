local H = require("tests.helpers")
local child = MiniTest.new_child_neovim()
local root
local project = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      child.start({ "-u", "NONE" })
      child.lua([[vim.opt.rtp:prepend(...)]], { project })
      child.api.nvim_set_current_dir(root)
      child.lua(
        [[
        local root = ...
        local inputsecret = vim.fn.inputsecret
        vim.fn.inputsecret = function(prompt)
          vim.fn.writefile({ prompt }, root .. "/prompt")
          return inputsecret(prompt)
        end
      ]],
        { root }
      )
    end,
    post_case = function()
      child.stop()
      H.cleanup(root)
    end,
  },
})
local function wait_for_prompt(kind)
  MiniTest.expect.equality(
    vim.wait(5000, function()
      if vim.fn.filereadable(root .. "/prompt") == 0 then
        return false
      end
      return table.concat(vim.fn.readfile(root .. "/prompt")):find(kind, 1, true) ~= nil
    end, 10),
    true
  )
end
for _, synchronous in ipairs({ false, true }) do
  for _, interrupt in ipairs({ false, true }) do
    T[(synchronous and "synchronous" or "asynchronous") .. (interrupt and " Git preserves the native interrupted username response" or " Git accepts typed askpass responses")] = function()
      child.lua_notify(
        [[
      local root, synchronous = ...
      local git = require("gin.git")
      local args = { "-c", "credential.helper=", "credential", "fill" }
      local options = {
        cwd = root,
        stdin = "protocol=https\nhost=example.invalid\n\n",
        env = { GIT_TERMINAL_PROMPT = "0" },
      }
      local function finish(result)
        vim.fn.writefile({ vim.json.encode(result) }, root .. "/result")
      end
      if synchronous then
        options.progress = true
        options.timeout = 5000
        options.check = false
        finish(git.run(args, options))
      else
        options.env = vim.tbl_extend("force", options.env, require("gin.editor").environment())
        git.start(args, options, vim.schedule_wrap(finish))
      end
    ]],
        { root, synchronous }
      )
      wait_for_prompt("Username")
      if interrupt then
        child.type_keys("<C-c>")
      else
        child.type_keys("keyboard-user<CR>")
      end
      wait_for_prompt("Password")
      child.type_keys("keyboard-password<CR>")
      local finished = vim.wait(5000, function()
        return vim.fn.filereadable(root .. "/result") == 1
      end, 10)
      assert(finished, vim.inspect(vim.fn.readfile(root .. "/prompt")))
      local result = vim.json.decode(table.concat(vim.fn.readfile(root .. "/result")))
      MiniTest.expect.equality(result.code, 0)
      MiniTest.expect.equality(
        result.stdout,
        "protocol=https\nhost=example.invalid\nusername="
          .. (interrupt and "" or "keyboard-user")
          .. "\npassword=keyboard-password\n"
      )
    end
  end
end
return T
