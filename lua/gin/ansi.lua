local M = {}
local highlights = {}
local namespace = vim.api.nvim_create_namespace("gin_ansi")
local palette = {
  "#282a2e",
  "#a54242",
  "#8c9440",
  "#de935f",
  "#5f819d",
  "#85678f",
  "#5e8d87",
  "#707880",
  "#373b41",
  "#cc6666",
  "#b5bd68",
  "#f0c674",
  "#81a2be",
  "#b294bb",
  "#8abeb7",
  "#c5c8c6",
}
local function color(index)
  if index < 16 then
    return vim.g["terminal_color_" .. index] or palette[index + 1]
  end
  if index >= 232 then
    local gray = 8 + (index - 232) * 10
    return string.format("#%02x%02x%02x", gray, gray, gray)
  end
  local levels = { 0, 95, 135, 175, 215, 255 }
  index = index - 16
  return string.format(
    "#%02x%02x%02x",
    levels[math.floor(index / 36) + 1],
    levels[math.floor(index / 6) % 6 + 1],
    levels[index % 6 + 1]
  )
end
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("gin_ansi", { clear = true }),
  callback = function()
    for name, attrs in pairs(highlights) do
      for _, key in ipairs({ "fg", "bg" }) do
        local index = attrs["cterm" .. key]
        if index then
          attrs[key] = color(index)
        end
      end
      vim.api.nvim_set_hl(0, name, attrs)
    end
  end,
})

local function update(state, sequence)
  local codes = {}
  for part in (sequence .. ";"):gmatch("([^;]*);") do
    codes[#codes + 1] = tonumber(part) or 0
  end
  local i = 1
  local on = {
    [1] = "bold",
    [2] = "dim",
    [3] = "italic",
    [4] = "underline",
    [7] = "reverse",
    [9] = "strikethrough",
  }
  local off = { [23] = "italic", [24] = "underline", [27] = "reverse", [29] = "strikethrough" }
  while i <= #codes do
    local code = codes[i]
    if code == 0 then
      state = {}
    elseif on[code] then
      state[on[code]] = true
    elseif off[code] then
      state[off[code]] = nil
    elseif code == 22 then
      state.bold, state.dim = nil, nil
    elseif code == 39 then
      state.fg, state.ctermfg = nil, nil
    elseif code == 49 then
      state.bg, state.ctermbg = nil, nil
    else
      local key, index
      if code >= 30 and code <= 37 then
        key, index = "fg", code - 30
      elseif code >= 40 and code <= 47 then
        key, index = "bg", code - 40
      elseif code >= 90 and code <= 97 then
        key, index = "fg", code - 82
      elseif code >= 100 and code <= 107 then
        key, index = "bg", code - 92
      elseif code == 38 or code == 48 then
        key = code == 38 and "fg" or "bg"
        if codes[i + 1] == 5 and codes[i + 2] and codes[i + 2] <= 255 then
          index, i = codes[i + 2], i + 2
        elseif codes[i + 1] == 2 and codes[i + 4] then
          local r, g, b = codes[i + 2], codes[i + 3], codes[i + 4]
          if r <= 255 and g <= 255 and b <= 255 then
            state[key], state["cterm" .. key] = string.format("#%02x%02x%02x", r, g, b), nil
          end
          i = i + 4
        end
      end
      if index then
        state[key], state["cterm" .. key] = color(index), index
      end
    end
    i = i + 1
  end
  return state
end

local function highlight_name(state)
  local parts = { "GinColor" }
  for _, entry in ipairs({ { "fg", "F" }, { "bg", "B" } }) do
    local key, prefix = entry[1], entry[2]
    if state[key] then
      parts[#parts + 1] = prefix .. (state["cterm" .. key] or state[key]:sub(2))
    end
  end
  for _, entry in ipairs({
    { "bold", "Bold" },
    { "reverse", "Inverse" },
    { "italic", "Italic" },
    { "strikethrough", "Strike" },
    { "underline", "Underline" },
  }) do
    if state[entry[1]] then
      parts[#parts + 1] = entry[2]
    end
  end
  return table.concat(parts)
end

function M.parse(lines)
  local plain, marks = {}, {}
  for row, line in ipairs(lines) do
    local state, parts, column, offset = {}, {}, 0, 1
    local function append(text)
      parts[#parts + 1] = text
      if #text > 0 and next(state) then
        local name = "Comment"
        if not state.dim then
          name = highlight_name(state)
          highlights[name] = vim.deepcopy(state)
          vim.api.nvim_set_hl(0, name, state)
        end
        marks[#marks + 1] = { row - 1, column, column + #text, name }
      end
      column = column + #text
    end
    while true do
      local first, last = line:find(require("gin.csi").pattern, offset)
      if not first then
        append(line:sub(offset))
        break
      end
      append(line:sub(offset, first - 1))
      local sequence = line:sub(first, last):match("^\27%[([%d;]*)m$")
      if sequence then
        state = update(state, sequence)
      end
      offset = last + 1
    end
    plain[row] = table.concat(parts)
  end
  return plain, marks
end

function M.apply(buf, marks)
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(
      buf,
      namespace,
      mark[1],
      mark[2],
      { end_col = mark[3], hl_group = mark[4] }
    )
  end
end
return M
