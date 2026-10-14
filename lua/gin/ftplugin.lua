local M = {}

function M.list(kind)
  if vim.b.did_ftplugin ~= nil then
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
  M.setup_mappings(vim.api.nvim_get_current_buf(), kind)
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

function M.setup_mappings(buf, kind)
  if not M.default_mappings(buf, kind) then
    return
  end
  local field = ({ status = "path", branch = "branch", tag = "tag", stash = "stash" })[kind]
    or "commit"
  local enter = kind == "status" and "edit" or kind == "branch" and "switch" or "show"
  local actions = {
    a = "choice",
    ["."] = "repeat",
    ["?"] = "help",
    ["<CR>"] = enter,
    yy = "yank:" .. field,
  }
  if kind == "status" then
    actions = vim.tbl_extend("force", actions, {
      ["<<"] = "stage",
      [">>"] = "unstage",
      ["=="] = "stash",
      dd = "diff:smart",
      pp = "patch",
      ["!!"] = "chaperon",
    })
  end
  local options = { buffer = buf, remap = true, nowait = true }
  for key, action in pairs(actions) do
    local normal = key == "?" or key == "yy" or (key == "<CR>" and kind == "branch")
    local suffix = key == "<CR>" and kind ~= "branch" and "zv" or ""
    vim.keymap.set(
      normal and "n" or { "n", "x", "s", "o" },
      key,
      "<Plug>(gin-action-" .. action .. ")" .. suffix,
      options
    )
  end
  vim.keymap.set({ "x", "s" }, "y", "<Plug>(gin-action-yank:" .. field .. ")<Esc>", options)
end

function M.jump_mappings(buf, kind)
  if not M.default_mappings(buf, kind) then
    return
  end
  for key, side in pairs({ ["<CR>"] = "smart", ["g<CR>"] = "old", ["<C-g><CR>"] = "new" }) do
    vim.keymap.set(
      "n",
      key,
      "<Plug>(gin-diffjump-" .. side .. ")zv",
      { buffer = buf, remap = true }
    )
  end
end

function M.blame_mappings(target)
  local previous = vim.b[target]._gin_blame_mappings
  if previous == vim.bo[target].filetype then
    return
  end
  vim.b[target]._gin_blame_mappings = vim.bo[target].filetype
  vim.keymap.set("n", "<Plug>(gin-blame-switch-commit)", function()
    require("gin.blame").switch_commit()
  end, { buffer = target, silent = true })
  if
    not vim.g.gin_blame_disable_default_mappings or vim.g.gin_blame_disable_default_mappings == 0
  then
    vim.keymap.set(
      "n",
      "<CR>",
      "<Plug>(gin-blame-switch-commit)",
      { buffer = target, remap = true }
    )
  end
  for direction, key in pairs({ older = "<C-O>", newer = "<C-I>" }) do
    local plug = "<Plug>(gin-blame-navigate-" .. direction .. ")"
    vim.keymap.set("n", plug, function()
      require("gin.blame").navigate_history(direction)
    end, { buffer = target, silent = true })
    if
      not vim.g.gin_blame_disable_default_mappings
      or vim.g.gin_blame_disable_default_mappings == 0
    then
      vim.keymap.set("n", key, plug, { buffer = target, remap = true })
    end
  end
  local undo = "unlet! b:_gin_blame_mappings| setlocal winfixbuf<"
  for _, key in ipairs({
    "<CR>",
    "<C-O>",
    "<C-I>",
    "<Plug>(gin-blame-switch-commit)",
    "<Plug>(gin-blame-navigate-older)",
    "<Plug>(gin-blame-navigate-newer)",
  }) do
    -- Spaces before a command separator become part of an unmap key.
    undo = undo .. "| silent! nunmap <buffer> " .. key
  end
  local existing = vim.b[target].undo_ftplugin or ""
  if not existing:find(undo, 1, true) then
    vim.b[target].undo_ftplugin = existing ~= "" and (existing .. "| " .. undo) or undo
  end
end

function M.blame()
  if vim.b.did_ftplugin ~= nil then
    return
  end
  vim.b.did_ftplugin = 1
  vim.wo.winfixbuf = true
  M.blame_mappings(vim.api.nvim_get_current_buf())
end

return M
