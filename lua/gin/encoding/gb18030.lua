local ranges = require("gin.encoding.gb18030_ranges")
local mapping = require("gin.encoding.gb18030_map")
local function decode(data)
  local output, pos = {}, 1
  while pos <= #data do
    local a = data:byte(pos)
    if a < 128 then
      output[#output + 1] = string.char(a)
    elseif a == 128 then
      output[#output + 1] = "€"
    else
      assert(a >= 129 and a <= 254, "Invalid lead")
      local b = assert(data:byte(pos + 1), "Incomplete sequence")
      if b >= 48 and b <= 57 then
        local c, d = data:byte(pos + 2, pos + 3)
        assert(c and c >= 129 and c <= 254 and d and d >= 48 and d <= 57, "Invalid quadruple")
        local pointer = ((a - 129) * 10 + b - 48) * 1260 + (c - 129) * 10 + d - 48
        local low, high, found = 1, #ranges, nil
        while low <= high do
          local mid = math.floor((low + high) / 2)
          local range = ranges[mid]
          if pointer < range[1] then
            high = mid - 1
          elseif pointer > range[2] then
            low = mid + 1
          else
            found = range[3] + pointer - range[1]
            break
          end
        end
        output[#output + 1] = vim.fn.nr2char(assert(found, "Unmapped quadruple"))
        pos = pos + 3
      else
        local row = mapping[a]
        local code = assert(row and row[b], "Invalid pair")
        output[#output + 1] = vim.fn.nr2char(code)
        pos = pos + 1
      end
    end
    pos = pos + 1
  end
  return table.concat(output)
end
return decode
