local M = {}
local labels = require("gin.encoding.labels")
local bom = "\239\187\191"

local function remove_bom(text)
  local present = text:sub(1, 3) == bom
  return present and text:sub(4) or text, present
end

local function canonical(label)
  return labels[label:match("^[\t\n\f\r ]*(.-)[\t\n\f\r ]*$"):lower()]
end

---Whether replacement decoding is implemented for this label.
function M.supports_replacement(label)
  local encoding = canonical(label)
  return encoding == "utf-8"
    or encoding == "utf-16le"
    or encoding == "utf-16be"
    or encoding == "euc-jp"
    or encoding == "shift_jis"
    or encoding == "big5"
    or encoding == "euc-kr"
    or require("gin.encoding.single_byte")[encoding] ~= nil
end

---Decode a candidate strictly by default; fatal=false replaces malformed input.
function M.decode(data, label, options)
  local encoding = assert(canonical(label), "Unsupported encoding: " .. label)
  local fatal = not options or options.fatal ~= false
  assert(
    fatal or M.supports_replacement(label),
    "Replacement decoding not implemented: " .. encoding
  )
  if encoding == "utf-8" then
    local text = require("gin.stream_text").utf8(data)
    assert(not fatal or text == data, "Invalid UTF-8")
    return remove_bom(text)
  elseif encoding == "utf-16le" or encoding == "utf-16be" then
    return remove_bom(require("gin.encoding.utf16")(data, encoding == "utf-16le", fatal))
  end
  if encoding == "gbk" or encoding == "gb18030" then
    return require("gin.encoding.gb18030")(data), false
  end
  if encoding == "iso-2022-jp" then
    return require("gin.encoding.iso_2022_jp")(data), false
  end
  if encoding == "euc-jp" then
    return require("gin.encoding.euc_jp")(data, fatal), false
  end
  if encoding == "shift_jis" then
    return require("gin.encoding.shift_jis")(data, fatal), false
  end
  if encoding == "big5" or encoding == "euc-kr" then
    local map = require("gin.encoding." .. encoding:gsub("-", "_") .. "_map")
    return require("gin.encoding.double_byte")(data, map, fatal), false
  end
  local map = assert(
    require("gin.encoding.single_byte")[encoding],
    "Encoding decoder not implemented: " .. encoding
  )
  local output = {}
  for i = 1, #data do
    local byte = data:byte(i)
    if byte < 128 then
      output[#output + 1] = string.char(byte)
    else
      local code = map[byte - 127]
      assert(code or not fatal, "Invalid " .. encoding .. " byte")
      code = code or 0xfffd
      output[#output + 1] = vim.fn.nr2char(code)
    end
  end
  return table.concat(output), false
end

---Try fileencodings in order, falling back to replacement-decoded UTF-8.
function M.detect(data, candidates)
  for _, label in ipairs(candidates) do
    local ok, text, has_bom = pcall(M.decode, data, label)
    if ok then
      return text, label, has_bom
    end
  end
  local text, has_bom = remove_bom(require("gin.stream_text").utf8(data))
  return text, "", has_bom
end

return M
