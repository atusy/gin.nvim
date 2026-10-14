local M = {}
local labels = require("gin.encoding.labels")
local bom = "\239\187\191"

local function remove_bom(text)
  local present = text:sub(1, 3) == bom
  return present and text:sub(4) or text, present
end

---Decode a candidate with TextDecoder's fatal-error behavior.
function M.decode(data, label)
  local normalized = label:match("^[\t\n\f\r ]*(.-)[\t\n\f\r ]*$"):lower()
  local encoding = assert(labels[normalized], "Unsupported encoding: " .. label)
  if encoding == "utf-8" then
    local text = require("gin.stream_text").utf8(data)
    assert(text == data, "Invalid UTF-8")
    return remove_bom(text)
  elseif encoding == "utf-16le" or encoding == "utf-16be" then
    return remove_bom(require("gin.unicode").decode(data, encoding))
  end
  if encoding == "gbk" or encoding == "gb18030" then
    return require("gin.encoding.gb18030")(data), false
  end
  if encoding == "iso-2022-jp" then
    return require("gin.encoding.iso_2022_jp")(data), false
  end
  if encoding == "euc-jp" then
    return require("gin.encoding.euc_jp")(data), false
  end
  if encoding == "shift_jis" then
    return require("gin.encoding.shift_jis")(data), false
  end
  if encoding == "big5" or encoding == "euc-kr" then
    local map = require("gin.encoding." .. encoding:gsub("-", "_") .. "_map")
    return require("gin.encoding.double_byte")(data, map), false
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
      local code = assert(map[byte - 127], "Invalid " .. encoding .. " byte")
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
