local jis0208 = require("gin.encoding.jis0208_map")
local function decode(data)
  local output, pos, state, switched = {}, 1, "ascii", false
  while pos <= #data do
    local byte = data:byte(pos)
    if byte == 27 then
      local one, two = data:byte(pos + 1, pos + 2)
      local next_state
      if one == 40 then
        next_state = ({ [66] = "ascii", [74] = "roman", [73] = "kana" })[two]
      elseif one == 36 and (two == 64 or two == 66) then
        next_state = "jis"
      end
      assert(next_state, "Invalid escape")
      assert(not switched, "Consecutive escape")
      state, switched = next_state, true
      pos = pos + 3
    else
      switched = false
      if state == "ascii" or state == "roman" then
        assert(byte < 128 and byte ~= 14 and byte ~= 15, "Invalid ASCII/Roman byte")
        if state == "roman" and byte == 92 then
          output[#output + 1] = "¥"
        elseif state == "roman" and byte == 126 then
          output[#output + 1] = "‾"
        else
          output[#output + 1] = string.char(byte)
        end
      elseif state == "kana" then
        assert(byte >= 33 and byte <= 95, "Invalid kana byte")
        output[#output + 1] = vim.fn.nr2char(0xff61 + byte - 33)
      else
        local tail = assert(data:byte(pos + 1), "Incomplete JIS pair")
        assert(byte >= 33 and byte <= 126 and tail >= 33 and tail <= 126, "Invalid JIS byte range")
        output[#output + 1] =
          vim.fn.nr2char(assert(jis0208[(byte - 33) * 94 + tail - 33], "Invalid JIS pair"))
        pos = pos + 1
      end
      pos = pos + 1
    end
  end
  return table.concat(output)
end
return decode
