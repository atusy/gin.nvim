local ranges = require("gin.encoding.gb18030_ranges")
local mapping = require("gin.encoding.gb18030_map")
local function decode(data, fatal)
  fatal = fatal ~= false
  local output, pos = {}, 1
  while pos <= #data do
    local a = data:byte(pos)
    if a < 128 then
      output[#output + 1] = string.char(a)
    elseif a == 128 then
      output[#output + 1] = "€"
    else
      local b = data:byte(pos + 1)
      if a == 255 or not b then
        assert(not fatal, "Invalid or incomplete GB18030 sequence")
        output[#output + 1] = "�"
      elseif b >= 48 and b <= 57 then
        local c, d = data:byte(pos + 2, pos + 3)
        if not c or (c >= 129 and c <= 254 and not d) then
          assert(not fatal, "Invalid or incomplete GB18030 sequence")
          output[#output + 1] = "�"
          pos = #data
        elseif c < 129 or c > 254 or d < 48 or d > 57 then
          assert(not fatal, "Invalid or incomplete GB18030 sequence")
          output[#output + 1] = "�"
        else
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
          assert(found or not fatal, "Unmapped GB18030 quadruple")
          output[#output + 1] = vim.fn.nr2char(found or 0xfffd)
          pos = pos + 3
        end
      else
        local row = mapping[a]
        local code = row and row[b]
        assert(code or not fatal, "Invalid GB18030 pair")
        output[#output + 1] = vim.fn.nr2char(code or 0xfffd)
        if code or b >= 128 then
          pos = pos + 1
        end
      end
    end
    pos = pos + 1
  end
  return table.concat(output)
end
return decode
