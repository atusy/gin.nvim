local M = {}

---Parse a flag prefix using the pinned argument parser's name grammar.
---@param arg string
---@return string? key
---@return string? value
function M.parse(arg)
  local key = arg:match("^%-%-([a-zA-Z0-9-]+)")
  local value
  if key then
    local rest = arg:sub(#key + 3)
    value = rest:sub(1, 1) == "=" and rest:sub(2) or ""
  else
    key = arg:match("^%-([a-zA-Z0-9])")
    if not key then
      return
    end
    value = arg:sub(3)
  end
  -- JavaScript's dot stops at these four line terminators.
  for _, separator in ipairs({ "\n", "\r", "\226\128\168", "\226\128\169" }) do
    local index = value:find(separator, 1, true)
    if index then
      value = value:sub(1, index - 1)
    end
  end
  return key, value
end

---Serialize one flag name and its ordered values into Git arguments.
---@param key string
---@param values string|string[]|nil
---@return string[]
function M.format(key, values)
  local result = {}
  for _, value in ipairs(type(values) == "table" and values or { values }) do
    result[#result + 1] = (#key == 1 and "-" or "--")
      .. key
      .. (value ~= "" and (#key == 1 and "" or "=") .. value or "")
  end
  return result
end

---Group and format flag arguments by first-seen name and ordered values.
---@param args string[] Flag arguments only, without a path separator.
---@return string[]
function M.group(args)
  local groups, order = {}, {}
  for _, arg in ipairs(args) do
    local key, value = M.parse(arg)
    assert(key, "Invalid Git flag: " .. arg)
    if not groups[key] then
      groups[key] = {}
      order[#order + 1] = key
    end
    table.insert(groups[key], value)
  end
  local result = {}
  for _, key in ipairs(order) do
    vim.list_extend(result, M.format(key, groups[key]))
  end
  return result
end

return M
