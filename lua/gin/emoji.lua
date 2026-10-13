local M = {}

function M.emojify(text)
  local records = require("gin.emoji_data")
  local output, position = {}, 1
  while true do
    local first, last, name = text:find(":([%w_+%-]+):", position)
    if not first then
      output[#output + 1] = text:sub(position)
      return table.concat(output)
    end
    if records[name] ~= nil then
      output[#output + 1] = text:sub(position, first - 1)
        .. (records[name] or text:sub(first, last))
      position = last + 1
    else
      -- An unknown name can share its closing colon with a known name.
      output[#output + 1] = text:sub(position, last - 1)
      position = last
    end
  end
end

return M
