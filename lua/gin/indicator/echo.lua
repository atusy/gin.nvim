local M = {}
local handles = {}

function M.open(_id)
  handles[#handles + 1] = require("gin.indicator").open({ preserve_more = true })
end

function M.write(_id, lines)
  if handles[#handles] then
    handles[#handles].write_lines(lines)
  end
end

function M.close(_id)
  local handle = table.remove(handles)
  if handle then
    handle.close()
  end
end

return M
