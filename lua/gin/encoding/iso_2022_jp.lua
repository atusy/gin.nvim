local jis0208 = require("gin.encoding.jis0208_map")
local function decode(data, fatal)
  fatal = fatal ~= false
  local output, pos, state, switched = {}, 1, "ascii", false
  local function emit(code)
    assert(code or not fatal, "Invalid or incomplete ISO-2022-JP sequence")
    output[#output + 1] = code == 0 and "\0" or vim.fn.nr2char(code or 0xfffd)
  end
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
      if next_state then
        state = next_state
        if switched then
          emit()
        end
        switched = true
        pos = pos + 3
      else
        emit()
        switched = false
        pos = pos + 1
      end
    else
      switched = false
      if state == "ascii" or state == "roman" then
        if byte >= 128 or byte == 14 or byte == 15 then
          emit()
        elseif state == "roman" and byte == 92 then
          emit(0xa5)
        elseif state == "roman" and byte == 126 then
          emit(0x203e)
        else
          emit(byte)
        end
      elseif state == "kana" then
        emit(byte >= 33 and byte <= 95 and 0xff61 + byte - 33 or nil)
      elseif byte >= 33 and byte <= 126 then
        local tail = data:byte(pos + 1)
        local code = tail and tail >= 33 and tail <= 126 and jis0208[(byte - 33) * 94 + tail - 33]
        emit(code or nil)
        if tail and tail ~= 27 then
          pos = pos + 1
        end
      else
        emit()
      end
      pos = pos + 1
    end
  end
  return table.concat(output)
end
return decode
