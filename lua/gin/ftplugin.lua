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

-- Default keys belong to the filetype lifecycle, not each content refresh.
function M.default_mappings(buf, kind)
  local previous = vim.b[buf]._gin_list_mappings
  if previous == kind then
    return false
  end
  if previous == nil then
    vim.api.nvim_create_autocmd("FileType", {
      buffer = buf,
      callback = function()
        local installed = vim.b[buf]._gin_list_mappings
        if type(installed) == "string" and vim.bo[buf].filetype ~= "gin-" .. installed then
          -- Keep a sentinel so later initializations reuse this buffer-local autocmd.
          vim.b[buf]._gin_list_mappings = false
        end
      end,
    })
  end
  vim.b[buf]._gin_list_mappings = kind
  local disabled = vim.g["gin_" .. kind .. "_disable_default_mappings"]
  return not disabled or disabled == 0
end

return M
