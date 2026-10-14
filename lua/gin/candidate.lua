local M = {}

-- A nil result means the setting is absent; an empty table is a custom no-match.
function M.custom(buf, range, kind)
  local setting = "gin_" .. kind .. "_parse_pattern"
  local pattern = vim.g[setting]
  assert(
    pattern == nil or pattern == vim.NIL or type(pattern) == "string",
    "g:" .. setting .. " must be string"
  )
  if pattern == nil or pattern == vim.NIL then
    return nil
  end
  local regex = require("gin.regex").compile(pattern)
  local indices = (kind == "tag" or kind == "stash") and { 2, 3 } or { 2 }
  local integer = kind == "stash" and require("gin.regex").compile("^\\s*([+-]?[0-9]+)")
  local result = {}
  for _, line in ipairs(vim.fn.getbufline(buf, math.max(range[1], 1), math.max(range[2], 1))) do
    if line ~= "" then
      local captures = regex:match_strings(line, indices)
      if captures then
        local first = captures[1] ~= vim.NIL and captures[1] or nil
        local second = captures[2] ~= vim.NIL and captures[2] or nil
        local entry = vim.empty_dict()
        if kind == "tag" then
          entry.commit, entry.tag = first, second
        elseif kind == "stash" then
          local number = second and integer:match_strings(second, { 2 })
          local index = number and tonumber(number[1])
          -- Upstream JSON.stringify exposes NaN/Infinity as null to the editor.
          if not index or index == math.huge or index == -math.huge then
            index = vim.NIL
          end
          entry.stashRef, entry.commit, entry.index = first, first, index
        else
          entry.commit = first
        end
        result[#result + 1] = entry
      end
    end
  end
  return result
end
function M.field(row, name)
  local value = row[name]
  assert(type(value) == "string", "Missing custom parser capture for " .. name)
  return value
end
return M
