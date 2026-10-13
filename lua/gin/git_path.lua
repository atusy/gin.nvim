local M = {}

---Decode Git C-quoted filenames without reinterpreting literal backslashes.
function M.unquote(value)
  if value:sub(1, 1) ~= '"' then
    return value
  end
  local escapes = { a = "\a", b = "\b", t = "\t", n = "\n", v = "\v", f = "\f", r = "\r" }
  local result, index = {}, 2
  while index < #value do
    local char = value:sub(index, index)
    if char == "\\" then
      index = index + 1
      local octal = value:sub(index, index + 2)
      if octal:match("^[0-7][0-7][0-7]$") then
        char, index = string.char(tonumber(octal, 8)), index + 2
      else
        char = value:sub(index, index)
        char = escapes[char] or char
      end
    end
    result[#result + 1], index = char, index + 1
  end
  return table.concat(result)
end

return M
