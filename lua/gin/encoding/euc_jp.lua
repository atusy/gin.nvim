local jis0208 = require("gin.encoding.jis0208_map")
local jis0212 = require("gin.encoding.jis0212_map")
return function(data)
  local output, pos = {}, 1
  while pos <= #data do
    local lead = data:byte(pos)
    if lead < 128 then
      output[#output + 1] = string.char(lead)
    else
      local tail = assert(data:byte(pos + 1), "Incomplete EUC-JP sequence")
      local code
      if lead == 142 then
        assert(tail >= 161 and tail <= 223, "Invalid EUC-JP kana")
        code = 0xff61 + tail - 161
      else
        local map = jis0208
        if lead == 143 then
          map, lead = jis0212, tail
          tail = assert(data:byte(pos + 2), "Incomplete EUC-JP triple")
          pos = pos + 1
        end
        assert(lead >= 161 and lead <= 254 and tail >= 161 and tail <= 254, "Invalid EUC-JP pair")
        code = assert(map[(lead - 161) * 94 + tail - 161], "Unmapped EUC-JP pair")
      end
      output[#output + 1] = vim.fn.nr2char(code)
      pos = pos + 1
    end
    pos = pos + 1
  end
  return table.concat(output)
end
