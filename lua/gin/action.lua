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

function M.alias(buf, name, target)
  M.define(buf, name, function(_, range)
    return M.call(buf, target, range)
  end)
  vim.keymap.set(
    { "n", "x" },
    "<Plug>(gin-action-" .. name .. ")",
    "<Plug>(gin-action-" .. target .. ")",
    { buffer = buf, remap = true }
  )
end

function M.help(buf, reduced)
  local keys = {}
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    local name = (mapping.rhs or ""):match("^<Plug>%(gin%-action%-(.*)%)$")
    if name then
      keys[name] = mapping.lhs
    end
  end
  local rows, widths = {}, { 0, 0, 0 }
  for _, name in ipairs(M.list(buf)) do
    if not reduced or not name:find("[:=]") then
      local row = { keys[name] or "", name, "<Plug>(gin-action-" .. name .. ")" }
      rows[#rows + 1] = row
      for col, value in ipairs(row) do
        widths[col] = math.max(widths[col], vim.fn.strdisplaywidth(value))
      end
    end
  end
  local lines = {}
  for _, row in ipairs(rows) do
    for col, value in ipairs(row) do
      row[col] = value .. string.rep(" ", widths[col] - vim.fn.strdisplaywidth(value))
    end
    lines[#lines + 1] = table.concat(row, "  ")
  end
  if reduced then
    table.insert(lines, 1, "Use 'help:all' action to see complete help.")
  end
  return table.concat(lines, "\n")
end

function M.call(buf, name, range)
  local callback = actions[buf] and actions[buf][name]
  assert(callback, "Unknown Gin action: " .. name)
  if vim.api.nvim_get_current_buf() ~= buf then
    local windows = vim.fn.win_findbuf(buf)
    if #windows > 0 then
      vim.api.nvim_set_current_win(windows[1])
    else
      vim.api.nvim_set_current_buf(buf)
    end
  end
  return callback(buf, vim.deepcopy(range))
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

function M.setup(buf, gather)
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
  if gather then
    require("gin.browse").setup(buf, gather)
    M.define(buf, "echo", function(target, range)
      local selected = gather(target, range)
      local output = #selected == 0 and "[]" or vim.json.encode(selected)
      vim.api.nvim_echo({ { output, "None" } }, true, {})
    end)
  end
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
  for _, name in ipairs({ "help", "help:all" }) do
    M.define(buf, name, function(target)
      vim.api.nvim_echo({ { M.help(target, name == "help"), "None" } }, true, {})
    end)
  end
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
