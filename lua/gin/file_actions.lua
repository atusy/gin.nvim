local action = require("gin.action")
local M = {}

---Install file actions whose candidates contain repository-relative paths.
function M.setup(buf, gather)
  for _, source in ipairs({ "local", "cached", "HEAD" }) do
    for _, opener in ipairs({ "edit", "split", "vsplit", "tabedit" }) do
      action.define(buf, "edit:" .. source .. ":" .. opener, function(target, range)
        local root = vim.b[target].gin_worktree
        local entries = gather(target, range)
        for _, entry in ipairs(entries) do
          if source == "local" then
            require("gin.buffer").open(root .. "/" .. entry.path, { opener = opener })
          else
            require("gin.edit").open(root, entry.path, {
              opener = opener,
              commitish = source == "HEAD" and "HEAD" or nil,
            })
          end
        end
      end)
    end
    action.alias(buf, "edit:" .. source, "edit:" .. source .. ":edit")
  end
  action.alias(buf, "edit", "edit:local")
end

return M
