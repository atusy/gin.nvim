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

return M
