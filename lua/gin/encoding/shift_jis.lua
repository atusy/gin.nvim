local map = require("gin.encoding.shift_jis_map")
local function decode(data, fatal)
  fatal = fatal ~= false
  local result, pos = {}, 1
  while pos <= #data do
    local byte = data:byte(pos)
    local code
    if byte <= 128 then
      code = byte
    elseif byte >= 161 and byte <= 223 then
      code = 0xff61 + byte - 161
    elseif byte >= 129 and byte <= 159 or byte >= 224 and byte <= 252 then
      local next_byte = data:byte(pos + 1)
      code = next_byte and map[byte * 256 + next_byte]
      assert(code or not fatal, "Invalid or incomplete Shift_JIS sequence")
      -- An invalid ASCII trail is decoded again as an independent byte.
      if next_byte and (code or next_byte >= 128) then
        pos = pos + 1
      end
      code = code or 0xfffd
    else
      assert(not fatal, "Invalid Shift_JIS byte")
      code = 0xfffd
    end
    result[#result + 1] = code == 0 and "\0" or vim.fn.nr2char(code)
    pos = pos + 1
  end
  return table.concat(result)
end
return decode
