-- TextDecoder byte order is fixed by the label, including when a BOM is present.
return function(data, little, fatal)
  local output, pos = {}, 1
  local function unit(at)
    local a, b = data:byte(at, at + 1)
    return little and a + b * 256 or a * 256 + b
  end
  while pos <= #data do
    if pos == #data then
      assert(not fatal, "Incomplete UTF-16 code unit")
      output[#output + 1] = "�"
      break
    end
    local code = unit(pos)
    if code >= 0xd800 and code <= 0xdbff then
      if pos + 3 > #data then
        assert(not fatal, "Incomplete UTF-16 surrogate pair")
        -- EOF replaces a pending surrogate and partial trailing unit together.
        output[#output + 1] = "�"
        break
      end
      local low = unit(pos + 2)
      if low >= 0xdc00 and low <= 0xdfff then
        code = 0x10000 + (code - 0xd800) * 1024 + low - 0xdc00
        pos = pos + 2
      else
        assert(not fatal, "Invalid UTF-16 surrogate pair")
        code = 0xfffd
      end
    elseif code >= 0xdc00 and code <= 0xdfff then
      assert(not fatal, "Unpaired UTF-16 low surrogate")
      code = 0xfffd
    end
    output[#output + 1] = code == 0 and "\0" or vim.fn.nr2char(code)
    pos = pos + 2
  end
  return table.concat(output)
end
