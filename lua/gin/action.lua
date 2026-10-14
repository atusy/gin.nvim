local M = {}
local actions = {}
local range_internal

local function pretty_json(json)
  local parts, depth, quoted, escaped = {}, 0, false, false
  local function newline()
    parts[#parts + 1] = "\n" .. string.rep("  ", depth)
  end
  for i = 1, #json do
    local char = json:sub(i, i)
    if quoted then
      parts[#parts + 1] = char
      if escaped then
        escaped = false
      elseif char == "\\" then
        escaped = true
      elseif char == '"' then
        quoted = false
      end
    elseif char == '"' then
      quoted = true
      parts[#parts + 1] = char
    elseif char == "[" or char == "{" then
      parts[#parts + 1] = char
      depth = depth + 1
      if json:sub(i + 1, i + 1) ~= (char == "[" and "]" or "}") then
        newline()
      end
    elseif char == "]" or char == "}" then
      depth = depth - 1
      if json:sub(i - 1, i - 1) ~= (char == "]" and "[" or "{") then
        newline()
      end
      parts[#parts + 1] = char
    elseif char == "," then
      parts[#parts + 1] = char
      newline()
    else
      parts[#parts + 1] = char == ":" and ": " or char
    end
  end
  return table.concat(parts)
end

function M.range()
  if range_internal then
    return vim.deepcopy(range_internal)
  end
  local line = vim.fn.line(".")
  local mode = vim.fn.mode()
  local other = mode == "n" and line or vim.fn.line("v")
  return { math.min(line, other), math.max(line, other) }
end

function M.define(buf, name, callback)
  assert(actions[buf], "Action buffer has not been initialized")
  local dispatch = function()
    return callback(buf, M.range())
  end
  actions[buf][name] = { callback = callback, dispatch = dispatch }
  vim.keymap.set({ "n", "x", "s", "o" }, "<Plug>(gin-action-" .. name .. ")", dispatch, {
    buffer = buf,
    silent = true,
  })
end

function M.alias(buf, name, target)
  M.define(buf, name, function(_, range)
    return M.call(buf, target, range)
  end)
  vim.keymap.set(
    { "n", "x", "s", "o" },
    "<Plug>(gin-action-" .. name .. ")",
    "<Plug>(gin-action-" .. target .. ")",
    { buffer = buf, remap = true }
  )
end

function M.help(buf, reduced)
  local records = {}
  local function action_name(value)
    return (value or ""):match("^<Plug>%(gin%-action%-(.*)%)$")
  end
  for _, mode in ipairs({ "n", "x", "s", "o", "i", "c", "t", "l" }) do
    local effective = {}
    for _, mapping in ipairs(vim.api.nvim_get_keymap(mode)) do
      effective[mapping.lhs] = mapping
    end
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
      effective[mapping.lhs] = mapping
    end
    for _, lhs in ipairs(vim.fn.sort(vim.tbl_keys(effective))) do
      local mapping = effective[lhs]
      local defined, mapped = action_name(lhs), action_name(mapping.rhs)
      local name = defined or mapped
      if name and not (reduced and defined and defined:find("[:=]")) then
        local row = records[name] or { "", name, "<Plug>(gin-action-" .. name .. ")" }
        if not defined then
          row[1] = lhs
        end
        records[name] = row
      end
    end
  end
  local rows, widths = {}, { 0, 0, 0 }
  for _, name in ipairs(vim.fn.sort(vim.tbl_keys(records))) do
    local row = records[name]
    rows[#rows + 1] = row
    for col, value in ipairs(row) do
      widths[col] = math.max(widths[col], vim.fn.strdisplaywidth(value))
    end
  end
  local lines = {}
  for _, row in ipairs(rows) do
    for col, value in ipairs(row) do
      row[col] = value .. string.rep(" ", widths[col] - vim.fn.strdisplaywidth(value))
    end
    lines[#lines + 1] = table.concat(row, "  ")
  end
  if reduced and #lines > 0 then
    local hint = "Use 'help:all' action to see complete help."
    local width = math.max(vim.fn.strdisplaywidth(lines[1]), #hint)
    table.insert(lines, 1, string.rep("~", width))
    table.insert(lines, 1, string.rep(" ", math.floor((width - #hint) / 2)) .. hint)
    table.insert(lines, 1, string.rep("~", width))
  end
  return table.concat(lines, "\n")
end

function M.call(buf, name, range)
  if vim.api.nvim_get_current_buf() ~= buf then
    local windows = vim.fn.win_findbuf(buf)
    if #windows > 0 then
      vim.api.nvim_set_current_win(windows[1])
    else
      vim.api.nvim_set_current_buf(buf)
    end
  end
  local plug = "<Plug>(gin-action-" .. name .. ")"
  local mode = vim.fn.mode(1)
  if vim.tbl_contains({ "v", "V", "\22" }, mode:sub(1, 1)) then
    mode = "x"
  elseif vim.tbl_contains({ "s", "S", "\19" }, mode:sub(1, 1)) then
    mode = "s"
  elseif mode:match("^[iR]") then
    mode = "i"
  else
    mode = mode:sub(1, 1)
  end
  local mapping = vim.fn.maparg(plug, mode, false, true)
  assert(next(mapping), "Unknown Gin action: " .. name)
  local previous = range_internal
  range_internal = vim.deepcopy(range)
  local ok, result = pcall(function()
    local entry = actions[buf] and actions[buf][name]
    if entry and mapping.callback == entry.dispatch then
      return entry.callback(buf, vim.deepcopy(range))
    elseif mapping.callback and mapping.expr == 0 then
      return mapping.callback()
    end
    local target = (mapping.rhs or ""):match("^<Plug>%(gin%-action%-(.*)%)$")
    if target and mapping.expr == 0 then
      return M.call(buf, target, range)
    end
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes(plug .. "<Ignore>", true, false, true),
      "mx",
      false
    )
  end)
  range_internal = previous
  if not ok then
    error(result, 0)
  end
  return result
end

function M.list(buf)
  local found = {}
  local mappings = vim.api.nvim_get_keymap("n")
  vim.list_extend(mappings, vim.api.nvim_buf_get_keymap(buf, "n"))
  for _, mapping in ipairs(mappings) do
    local name = mapping.lhs:match("^<Plug>%(gin%-action%-(.*)%)$")
    if name then
      found[name] = true
    end
  end
  local names = vim.tbl_keys(found)
  table.sort(names)
  return names
end

function M.complete(lead)
  return vim.tbl_filter(function(name)
    return name:sub(1, #lead) == lead
  end, M.list(vim.api.nvim_get_current_buf()))
end

function M.setup(buf, gather, target_field)
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
    require("gin.browse").setup(buf, gather, target_field)
    M.define(buf, "echo", function(target, range)
      local selected = gather(target, range)
      local output = #selected == 0 and "[]" or pretty_json(vim.json.encode(selected))
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
