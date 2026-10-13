local M = {}

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

---Group flag arguments by first-seen name, retaining each name's value order.
---@param args string[] Flag arguments only, without a path separator.
---@return string[]
function M.group(args)
  local groups, order = {}, {}
  for _, arg in ipairs(args) do
    local key = arg:match("^%-%-([^=]+)") or arg:sub(2, 2)
    if not groups[key] then
      groups[key] = {}
      order[#order + 1] = key
    end
    table.insert(groups[key], arg)
  end
  local result = {}
  for _, key in ipairs(order) do
    vim.list_extend(result, groups[key])
  end
  return result
end

return M
