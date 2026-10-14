local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      vim.cmd("filetype plugin on")
      vim.cmd.enew()
    end,
    post_case = function()
      vim.g.gin_proxy_disable_accept_and_cancel_aliases = nil
      vim.cmd("silent! delcommand Accept")
      vim.cmd.bwipeout({ bang = true })
    end,
  },
})

for _, filetype in ipairs({ "gitcommit", "gitrebase" }) do
  for _, disabled in ipairs({ 0, 1, vim.NIL, "0", "1", "false", "" }) do
    for _, existing in ipairs({ "none", "global Accept", "buffer Cancel" }) do
      T[filetype .. " aliases disabled=" .. vim.inspect(disabled) .. " with " .. existing] = function()
        vim.g.gin_proxy_disable_accept_and_cancel_aliases = disabled
        if existing == "global Accept" then
          vim.api.nvim_create_user_command("Accept", "echo 'user accept'", {})
        elseif existing == "buffer Cancel" then
          vim.api.nvim_buf_create_user_command(0, "Cancel", "echo 'user cancel'", {})
        end
        vim.bo.filetype = filetype
        local function check(installed)
          local local_commands = vim.api.nvim_buf_get_commands(0, {})
          local global_commands = vim.api.nvim_get_commands({})
          for name, definition in pairs({ Accept = "wq", Cancel = "cq" }) do
            if existing == "global " .. name then
              MiniTest.expect.equality(local_commands[name], nil)
              MiniTest.expect.equality(global_commands[name].definition, "echo 'user accept'")
            elseif existing == "buffer " .. name then
              MiniTest.expect.equality(local_commands[name].definition, "echo 'user cancel'")
            elseif installed then
              MiniTest.expect.equality(local_commands[name].definition, definition)
              MiniTest.expect.equality(local_commands[name].nargs, "0")
            else
              MiniTest.expect.equality(local_commands[name], nil)
            end
          end
        end
        check(disabled ~= 1 and disabled ~= "1")
        -- Re-sourcing must preserve the commands already installed by either owner.
        vim.cmd.runtime("ftplugin/" .. filetype .. "/gin.lua")
        check(disabled ~= 1 and disabled ~= "1")
        vim.bo.filetype = "text"
        check(false)
      end
    end
  end
end

return T
