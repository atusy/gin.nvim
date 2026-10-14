local M = {}
local csi = require("gin.csi")

-- ECMAScript WhiteSpace and LineTerminator characters used by String.trim().
local whitespace = {}
for _, cp in ipairs({
  9,
  10,
  11,
  12,
  13,
  32,
  0xA0,
  0x1680,
  0x2028,
  0x2029,
  0x202F,
  0x205F,
  0x3000,
  0xFEFF,
}) do
  whitespace[vim.fn.nr2char(cp)] = true
end
for cp = 0x2000, 0x200A do
  whitespace[vim.fn.nr2char(cp)] = true
end

function M.trim(text)
  local first, last = 1, #text
  while first <= last do
    local width = 1
    while width <= 3 and not whitespace[text:sub(first, first + width - 1)] do
      width = width + 1
    end
    if width > 3 then
      break
    end
    first = first + width
  end
  while last >= first do
    local width = 1
    while width <= 3 and not whitespace[text:sub(last - width + 1, last)] do
      width = width + 1
    end
    if width > 3 then
      break
    end
    last = last - width
  end
  return text:sub(first, last)
end

function M.decoder()
  local pending = ""
  return function(data)
    if data == nil then
      local tail = pending ~= "" and pending:byte() ~= 27 and "�" or ""
      pending = ""
      return tail, tail ~= ""
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
    -- A complete control sequence is output even when stripping leaves no text.
    return csi.strip(text), text ~= ""
  end
end

return M
