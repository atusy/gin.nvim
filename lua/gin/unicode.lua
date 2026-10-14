local M = {}

local formats = {
  ["utf-16"] = { width = 2 },
  ["utf-16le"] = { width = 2, little = true },
  ["utf-16be"] = { width = 2 },
  ["ucs-2"] = { width = 2, ucs2 = true },
  ["ucs-2le"] = { width = 2, little = true, ucs2 = true },
  ["ucs-4"] = { width = 4 },
  ["ucs-4le"] = { width = 4, little = true },
}

function M.supports(encoding)
  return formats[encoding] ~= nil
end

function M.encode(text, encoding)
  local format = assert(formats[encoding])
  local result = {}
  local function unit(value)
    local bytes = {}
    for i = 1, format.width do
      bytes[format.little and i or format.width - i + 1] = string.char(value % 256)
      value = math.floor(value / 256)
    end
    result[#result + 1] = table.concat(bytes)
  end
  -- Vimscript strings cannot contain NUL; convert each intervening span separately.
  for i, part in ipairs(vim.split(text, "\0", { plain = true })) do
    if i > 1 then
      unit(0)
    end
    for _, code in ipairs(vim.fn.str2list(part, true)) do
      assert(code <= 0x10ffff and not (code >= 0xd800 and code <= 0xdfff), "Invalid Unicode scalar")
      if format.width == 2 and code > 0xffff then
        assert(not format.ucs2, "Character cannot be encoded as UCS-2")
        code = code - 0x10000
        unit(0xd800 + math.floor(code / 1024))
        unit(0xdc00 + code % 1024)
      else
        unit(code)
      end
    end
  end
  return table.concat(result)
end

function M.decode(data, encoding)
  local format = assert(formats[encoding])
  assert(#data % format.width == 0, "Incomplete Unicode code unit")
  local little = format.little
  if encoding == "utf-16" or encoding == "ucs-2" then
    little = data:sub(1, 2) == "\255\254"
  elseif encoding == "ucs-4" then
    little = data:sub(1, 4) == "\255\254\0\0"
  end
  local result, offset = {}, 1
  local function unit()
    local value = 0
    for i = 1, format.width do
      local at = little and format.width - i or i - 1
      value = value * 256 + data:byte(offset + at)
    end
    offset = offset + format.width
    return value
  end
  while offset <= #data do
    local code = unit()
    if format.width == 2 and code >= 0xd800 and code <= 0xdbff and not format.ucs2 then
      assert(offset <= #data, "Incomplete UTF-16 surrogate pair")
      local low = unit()
      assert(low >= 0xdc00 and low <= 0xdfff, "Invalid UTF-16 surrogate pair")
      code = 0x10000 + (code - 0xd800) * 1024 + low - 0xdc00
    end
    assert(code <= 0x10ffff and not (code >= 0xd800 and code <= 0xdfff), "Invalid Unicode scalar")
    result[#result + 1] = code == 0 and "\0" or vim.fn.nr2char(code)
  end
  return table.concat(result)
end

return M
