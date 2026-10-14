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

-- Replace invalid UTF-8 subsequences while retaining incomplete valid prefixes.
local function utf8(text, final)
  local output, pos = {}, 1
  while pos <= #text do
    local lead = text:byte(pos)
    local width = lead < 128 and 1
      or lead >= 194 and lead <= 223 and 2
      or lead >= 224 and lead <= 239 and 3
      or lead >= 240 and lead <= 244 and 4
    if not width then
      output[#output + 1], pos = "�", pos + 1
    else
      local count, valid = 1, true
      while count < width do
        local byte = text:byte(pos + count)
        if not byte then
          if not final then
            return table.concat(output), text:sub(pos)
          end
          valid = false
          break
        end
        local lower, upper = 128, 191
        if count == 1 then
          lower = lead == 224 and 160 or lead == 240 and 144 or lower
          upper = lead == 237 and 159 or lead == 244 and 143 or upper
        end
        if byte < lower or byte > upper then
          valid = false
          break
        end
        count = count + 1
      end
      output[#output + 1] = valid and text:sub(pos, pos + count - 1) or "�"
      pos = pos + count
    end
  end
  return table.concat(output), ""
end

-- Decode a complete byte string without stripping ANSI or trimming whitespace.
function M.utf8(text)
  local decoded = utf8(text, true)
  return decoded
end

function M.decoder()
  local pending, ansi = "", ""
  return function(data)
    local text
    text, pending = utf8(pending .. (data or ""), data == nil)
    text, ansi = ansi .. text, ""
    local escape = text:find(csi.partial) or text:find("\27$")
    if escape then
      ansi, text = text:sub(escape), text:sub(1, escape - 1)
    end
    if data == nil then
      ansi = ""
    end
    -- A complete control sequence is output even when stripping leaves no text.
    return csi.strip(text), text ~= ""
  end
end

return M
