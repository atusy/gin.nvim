local map = require("gin.encoding.shift_jis_map")
local function decode(data)
  local result, pos = {}, 1
  while pos <= #data do
    local byte = data:byte(pos)
    local code
    if byte <= 128 then
      code = byte
    elseif byte >= 161 and byte <= 223 then
      code = 0xff61 + byte - 161
    elseif byte >= 129 and byte <= 159 or byte >= 224 and byte <= 252 then
      local next_byte = assert(data:byte(pos + 1), "Incomplete Shift_JIS sequence")
      code = assert(map[byte * 256 + next_byte], "Invalid Shift_JIS sequence")
      pos = pos + 1
    else
      error("Invalid Shift_JIS byte")
    end
    result[#result + 1] = code == 0 and "\0" or vim.fn.nr2char(code)
    pos = pos + 1
  end
  return table.concat(result)
end
return decode
