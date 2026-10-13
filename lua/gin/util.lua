local M = {}

---Find the worktree for an explicit path or the current buffer/window context.
function M.worktree(path)
  assert(path == nil or type(path) == "string", "worktree path must be a string")
  return require("gin.worktree").current(path)
end

---Expand a Vim filename expression, resolving file-bearing Gin views.
function M.expand(expr)
  local name = vim.fn.expand(expr)
  if not name:match("^gin[%w]*://") then
    return name
  end
  local ok, expanded = pcall(function()
    local parsed = require("gin.uri").parse(name)
    local path
    if parsed.scheme == "ginedit" then
      path = parsed.fragment
    elseif parsed.scheme == "gindiff" and parsed.fragment then
      local decoded, paths = pcall(vim.json.decode, parsed.fragment)
      if decoded then
        path = paths[1]
      else
        path = parsed.fragment
      end
    elseif parsed.scheme == "ginlog" and parsed.fragment then
      -- Lua log URIs carry argv; file paths follow the explicit separator.
      local args = vim.json.decode(parsed.fragment)
      for i, value in ipairs(args) do
        if value == "--" then
          path = args[i + 1]
          break
        end
      end
    end
    if type(path) == "string" and path ~= "" then
      local absolute = path:match("^/") or path:match("^%a:[/\\]")
      return vim.fs.normalize(absolute and path or (parsed.root .. "/" .. path))
    end
    return name
  end)
  return ok and expanded or name
end

return M
