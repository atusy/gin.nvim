local jis0208 = require("gin.encoding.jis0208_map")
local jis0212 = require("gin.encoding.jis0212_map")
return function(data, fatal)
  fatal = fatal ~= false
  local output, lead, extended = {}, nil, false
  local pos = 1
  while pos <= #data do
    local byte = data:byte(pos)
    local code
    if lead then
      if lead == 142 and byte >= 161 and byte <= 223 then
        code = 0xff61 + byte - 161
        lead = nil
      elseif lead == 143 and byte >= 161 and byte <= 254 then
        lead = byte
        extended = true
      else
        if lead >= 161 and lead <= 254 and byte >= 161 and byte <= 254 then
          local map = extended and jis0212 or jis0208
          code = map[(lead - 161) * 94 + byte - 161]
        end
        lead = nil
        extended = false
        if not code then
          assert(not fatal, "Invalid EUC-JP sequence")
          code = 0xfffd
          if byte < 128 then
            pos = pos - 1
          end
        end
      end
    elseif byte < 128 then
      code = byte
    elseif byte == 142 or byte == 143 or byte >= 161 and byte <= 254 then
      lead = byte
    else
      assert(not fatal, "Invalid EUC-JP byte")
      code = 0xfffd
    end
    if code then
      output[#output + 1] = code == 0 and "\0" or vim.fn.nr2char(code)
    end
    pos = pos + 1
  end
  if lead then
    assert(not fatal, "Incomplete EUC-JP sequence")
    output[#output + 1] = "�"
  end
  return table.concat(output)
end
