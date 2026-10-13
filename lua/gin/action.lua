local M = {}
local actions = {}

function M.range()
  local line = vim.fn.line(".")
  local mode = vim.fn.mode()
  local other = mode == "n" and line or vim.fn.line("v")
  return { math.min(line, other), math.max(line, other) }
end

function M.define(buf, name, callback)
  assert(actions[buf], "Action buffer has not been initialized")
  actions[buf][name] = callback
  vim.keymap.set({ "n", "x" }, "<Plug>(gin-action-" .. name .. ")", function()
    M.call(buf, name, M.range())
  end, { buffer = buf, silent = true })
end

function M.call(buf, name, range)
  local callback = actions[buf] and actions[buf][name]
  assert(callback, "Unknown Gin action: " .. name)
  return vim.api.nvim_buf_call(buf, function()
    return callback(buf, vim.deepcopy(range))
  end)
end

function M.list(buf)
  local names = vim.tbl_keys(actions[buf] or {})
  table.sort(names)
  return names
end

function M.complete(lead)
  return vim.tbl_filter(function(name)
    return name:sub(1, #lead) == lead
  end, M.list(vim.api.nvim_get_current_buf()))
end

function M.setup(buf)
  if not actions[buf] then
    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = buf,
      once = true,
      callback = function()
        actions[buf] = nil
      end,
    })
  end
  actions[buf] = {}
  M.define(buf, "choice", function(target, range)
    vim.ui.input(
      { prompt = "action: ", completion = "customlist,v:lua.require'gin.action'.complete" },
      function(name)
        if not name or name == "" or not vim.api.nvim_buf_is_valid(target) then
          return
        end
        vim.b[target].denops_action_previous = name
        M.call(target, name, range)
      end
    )
  end)
  M.define(buf, "repeat", function(target, range)
    local name = vim.b[target].denops_action_previous
    if not name or name == "" then
      vim.api.nvim_echo({ { "[gin] Nothing to repeat", "None" } }, false, {})
      return
    end
    M.call(target, name, range)
  end)
end

return M
