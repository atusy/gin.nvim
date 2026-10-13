local M = {}

function M.list(kind)
  if vim.b.did_ftplugin then
    return
  end
  vim.b.did_ftplugin = 1
  vim.wo.list, vim.wo.spell, vim.wo.wrap, vim.wo.foldenable = false, false, false, false
  vim.bo.modeline = false
  local undo = { "list", "spell", "wrap", "foldenable", "modeline" }
  if kind ~= "branch" then
    vim.bo.buflisted = false
    undo[#undo + 1] = "buflisted"
  end
  if kind ~= "branch" and kind ~= "status" then
    vim.wo.cursorline = true
    undo[#undo + 1] = "cursorline"
  end
  vim.b.undo_ftplugin = "setlocal "
    .. table.concat(
      vim.tbl_map(function(name)
        return name .. "<"
      end, undo),
      " "
    )
end

return M
