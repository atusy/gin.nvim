local M = {}
local requests, serial = {}, 0
local address, askpass_launcher
local script = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)) .. "/editor_client.lua"

function M.aliases()
  if
    vim.g.gin_proxy_disable_accept_and_cancel_aliases
    and vim.g.gin_proxy_disable_accept_and_cancel_aliases ~= 0
  then
    return
  end
  for name, command in pairs({ Accept = "wq", Cancel = "cq" }) do
    if vim.fn.exists(":" .. name) == 0 then
      vim.api.nvim_buf_create_user_command(0, name, command, {})
      local undo = "silent! delcommand -buffer " .. name
      vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | " .. undo) or undo
    end
  end
end

function M.environment()
  local function disabled(name)
    local value = vim.g[name]
    return value and value ~= vim.NIL and value ~= 0
  end
  local disable_editor = disabled("gin_proxy_disable_editor")
  local disable_askpass = disabled("gin_proxy_disable_askpass")
  if disable_editor and disable_askpass then
    return nil
  end
  address = address or vim.fn.serverstart()
  local command = {}
  for _, arg in ipairs({
    vim.v.progpath,
    "--headless",
    "-u",
    "NONE",
    "-i",
    "NONE",
    "-n",
    "-l",
    script,
  }) do
    command[#command + 1] = vim.fn.shellescape(arg)
  end
  local launcher = table.concat(command, " ")
  if not disable_askpass and not askpass_launcher then
    -- Git executes GIT_ASKPASS as a path, unlike the GIT_EDITOR shell command.
    askpass_launcher = vim.fn.tempname()
    assert(
      vim.fn.writefile({ "#!/bin/sh", "exec " .. launcher .. ' --askpass "$@"' }, askpass_launcher)
        == 0
    )
    assert(vim.uv.fs_chmod(askpass_launcher, 448))
    vim.api.nvim_create_autocmd("VimLeavePre", {
      once = true,
      callback = function()
        vim.uv.fs_unlink(askpass_launcher)
      end,
    })
  end
  return {
    GIT_EDITOR = not disable_editor and launcher or nil,
    GIT_ASKPASS = not disable_askpass and askpass_launcher or nil,
    GIN_EDITOR_ADDRESS = address,
  }
end

function M.request(path)
  serial = serial + 1
  local id = serial
  requests[id] = { done = false }
  vim.schedule(function()
    local ok, err = pcall(function()
      local buf =
        require("gin.buffer").open(path, { opener = vim.g.gin_proxy_editor_opener or "tabedit" })
      assert(not vim.b[buf].gin_editor_request, "File already has a pending Git editor request")
      vim.b[buf].gin_editor_request = id
      vim.bo[buf].bufhidden, vim.bo[buf].swapfile = "hide", false
      local group = vim.api.nvim_create_augroup("gin_editor_" .. id, { clear = true })
      local function finish(accept, quitting)
        if accept then
          vim.api.nvim_buf_call(buf, function()
            vim.cmd.write()
          end)
        else
          assert(vim.fn.writefile({}, path) == 0, "Cannot clear cancelled Git editor file")
        end
        requests[id] = { done = true, accepted = accept }
        vim.api.nvim_del_augroup_by_id(group)
        vim.b[buf].gin_editor_request = nil
        local function wipe()
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end
        if quitting then
          vim.schedule(wipe)
        else
          wipe()
        end
      end
      vim.api.nvim_buf_create_user_command(buf, "Apply", function()
        finish(true)
      end, {})
      vim.api.nvim_buf_create_user_command(buf, "Cancel", function()
        finish(false)
      end, {})
      vim.api.nvim_create_autocmd("QuitPre", {
        group = group,
        buffer = buf,
        nested = true,
        callback = function()
          if
            vim.g.gin_proxy_apply_without_confirm and vim.g.gin_proxy_apply_without_confirm ~= 0
          then
            finish(true, true)
          else
            local answer =
              vim.fn.input({ prompt = "Do you want to apply changes? [Y/n] ", cancelreturn = "no" })
            finish(answer == "" or vim.tbl_contains({ "y", "ye", "yes" }, answer:lower()), true)
          end
        end,
      })
      vim.api.nvim_create_autocmd("BufWipeout", {
        group = group,
        buffer = buf,
        once = true,
        callback = function()
          requests[id] = { done = true, accepted = false }
          vim.api.nvim_del_augroup_by_id(group)
        end,
      })
    end)
    if not ok then
      requests[id] = { done = true, accepted = false, error = tostring(err) }
    end
  end)
  return id
end

function M.poll(id)
  local result = assert(requests[id], "Unknown Git editor request")
  if result.done then
    requests[id] = nil
  end
  return result
end
return M
