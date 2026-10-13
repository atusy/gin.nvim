local M = {}
local csi = require("gin.csi")

function M.decoder()
  local pending = ""
  return function(data)
    if data == nil then
      local tail = pending ~= "" and pending:byte() ~= 27 and "�" or ""
      pending = ""
      return tail
    end
    local text = pending .. data
    pending = ""
    local escape = text:find(csi.partial) or text:find("\27$")
    if escape then
      pending, text = text:sub(escape), text:sub(1, escape - 1)
    end
    local start = #text
    while start > 0 and text:byte(start) >= 128 and text:byte(start) < 192 do
      start = start - 1
    end
    local lead = text:byte(start)
    local width = lead
      and (
        lead >= 194 and lead <= 223 and 2
        or lead >= 224 and lead <= 239 and 3
        or lead >= 240 and lead <= 244 and 4
      )
    if width and #text - start + 1 < width then
      pending, text = text:sub(start) .. pending, text:sub(1, start - 1)
    end
    return csi.strip(text)
  end
end

return M
