local M = {}
local requests, serial = {}, 0
local address
local script = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)) .. "/editor_client.lua"

function M.environment()
  if vim.g.gin_proxy_disable_editor and vim.g.gin_proxy_disable_editor ~= 0 then
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
  return { GIT_EDITOR = table.concat(command, " "), GIN_EDITOR_ADDRESS = address }
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
      local function finish(accept)
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
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      vim.api.nvim_buf_create_user_command(buf, "Apply", function()
        finish(true)
      end, {})
      vim.api.nvim_buf_create_user_command(buf, "Cancel", function()
        finish(false)
      end, {})
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
