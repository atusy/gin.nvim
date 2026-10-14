-- Big5 and EUC-KR share ASCII bytes and strict two-byte lookup semantics.
return function(data, map)
  local output, pos = {}, 1
  while pos <= #data do
    local byte = data:byte(pos)
    if byte < 128 then
      output[#output + 1] = string.char(byte)
    else
      local tail = assert(data:byte(pos + 1), "Incomplete multibyte sequence")
      local row = map[byte]
      output[#output + 1] = assert(row and row[tail], "Invalid multibyte sequence")
      pos = pos + 1
    end
    pos = pos + 1
  end
  return table.concat(output)
end
