-- Run in an isolated process: a candidate native extension may crash.
local root = assert(vim.env.GIN_JSREGEXP_ROOT, "GIN_JSREGEXP_ROOT is required")
package.preload["jsregexp.core"] =
  assert(package.loadlib(root .. "/jsregexp.so", "luaopen_jsregexp_core"))
package.path = root .. "/?.lua;" .. package.path
local backend = require("jsregexp")
local case = vim.json.decode(assert(vim.env.GIN_REGEX_CASE))
local ok, regex = pcall(backend.compile, case.pattern)
local result
if not ok then
  result = { status = "compile-error" }
else
  local match = regex:match(case.input)
  if not match then
    result = { status = "no-match" }
  else
    local captures = {}
    for i = 0, match.capture_count - 1 do
      if match[i] == nil then
        captures[i + 1] = vim.NIL
      else
        local units = {}
        -- Vimscript string arguments cannot contain NUL; retain separators.
        local points = {}
        for part_index, part in ipairs(vim.split(match[i], "\0", { plain = true })) do
          if part_index > 1 then
            points[#points + 1] = 0
          end
          vim.list_extend(points, vim.fn.str2list(part, true))
        end
        for _, cp in ipairs(points) do
          if cp > 0xFFFF then
            cp = cp - 0x10000
            units[#units + 1] = 0xD800 + math.floor(cp / 0x400)
            units[#units + 1] = 0xDC00 + cp % 0x400
          else
            units[#units + 1] = cp
          end
        end
        captures[i + 1] = units
      end
    end
    result = { status = "match", captures = captures }
  end
end
io.write(vim.json.encode(result))
vim.cmd.qa()
