-- Big5 and EUC-KR share lead ranges and ASCII recovery after invalid pairs.
return function(data, map, fatal)
  fatal = fatal ~= false
  local output, pos = {}, 1
  while pos <= #data do
    local byte = data:byte(pos)
    if byte < 128 then
      output[#output + 1] = string.char(byte)
    else
      local tail = data:byte(pos + 1)
      local leading = byte >= 129 and byte <= 254
      local row = map[byte]
      local text = leading and tail and row and row[tail]
      assert(text or not fatal, "Invalid or incomplete multibyte sequence")
      output[#output + 1] = text or "�"
      if leading and tail and (text or tail >= 128) then
        pos = pos + 1
      end
    end
    pos = pos + 1
  end
  return table.concat(output)
end
