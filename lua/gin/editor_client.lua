-- Separate headless Neovim process invoked by Git through GIT_EDITOR.
local ok, err = pcall(function()
  local address = assert(vim.env.GIN_EDITOR_ADDRESS, "GIN_EDITOR_ADDRESS is required")
  local path = vim.fn.fnamemodify(assert(arg[1], "Editor filename is required"), ":p")
  local channel = vim.fn.sockconnect("pipe", address, { rpc = true })
  assert(channel > 0, "Cannot connect to Gin editor")
  local id =
    vim.rpcrequest(channel, "nvim_exec_lua", "return require('gin.editor').request(...)", { path })
  local result
  vim.wait(2147483647, function()
    result =
      vim.rpcrequest(channel, "nvim_exec_lua", "return require('gin.editor').poll(...)", { id })
    return result.done
  end, 50)
  vim.fn.chanclose(channel)
  assert(
    result and result.done and result.accepted,
    result and result.error or "Git editor cancelled"
  )
end)
if not ok then
  io.stderr:write(tostring(err), "\n")
  vim.cmd("cquit 1")
else
  vim.cmd("quitall!")
end
