local M = {}

---Read a flag whose upstream contract uses a Vimscript condition.
function M.vimscript_flag(name)
  return vim.fn.eval("!!get(g:, " .. vim.fn.string(name) .. ", 0)") ~= 0
end

---Reload a buffer asynchronously, or once it is entered if hidden.
function M.reload(bufnr)
  bufnr = bufnr or 0
  assert(type(bufnr) == "number" and bufnr % 1 == 0, "reload buffer must be an integer")
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local function edit()
    local views = {}
    for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
      views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    end
    local ok, err = pcall(vim.cmd.edit)
    for win, view in pairs(views) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
        vim.api.nvim_win_call(win, function()
          vim.fn.winrestview(view)
        end)
      end
    end
    if not ok then
      vim.notify(tostring(err), vim.log.levels.ERROR)
    end
  end
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    if vim.api.nvim_get_current_buf() == bufnr then
      edit()
      return
    end
    local win = vim.fn.bufwinid(bufnr)
    if win == -1 then
      local group = vim.api.nvim_create_augroup("gin_util_reload", { clear = false })
      vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })
      vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        buffer = bufnr,
        once = true,
        nested = true,
        callback = function(event)
          -- Older Neovim removes once callbacks only after nested events run.
          vim.api.nvim_del_autocmd(event.id)
          edit()
        end,
      })
      return
    end
    local saved = vim.api.nvim_get_current_win()
    vim.cmd("keepjumps keepalt call win_gotoid(" .. win .. ")")
    edit()
    if vim.api.nvim_win_is_valid(saved) then
      vim.cmd("keepjumps keepalt call win_gotoid(" .. saved .. ")")
    end
  end)
end

---Find the worktree for an explicit path or the current buffer/window context.
function M.worktree(path)
  assert(path == nil or type(path) == "string", "worktree path must be a string")
  return require("gin.worktree").current(path)
end

-- The pinned expander calls JSON.parse(fragment).at(0), falling back to the
-- entire fragment if indexing or joining fails.
local function legacy_path(fragment)
  local decoded, value = pcall(vim.json.decode, fragment)
  if not decoded then
    return fragment
  end
  local path
  if type(value) == "table" and vim.islist(value) then
    path = value[1]
  elseif type(value) == "string" then
    path = vim.fn.strcharpart(value, 0, 1)
    -- String.at selects a UTF-16 unit; an isolated surrogate cannot be sent to Neovim.
    assert(vim.fn.char2nr(path) <= 0xffff, "Unpaired surrogate in expanded path")
  else
    return fragment
  end
  if path == nil or path == vim.NIL or path == false or path == 0 or path == "" then
    return nil
  end
  return type(path) == "string" and path or fragment
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
    if
      parsed.legacy
      and parsed.fragment
      and vim.tbl_contains({ "ginedit", "gindiff", "ginlog" }, parsed.scheme)
    then
      path = legacy_path(parsed.fragment)
    elseif parsed.scheme == "ginedit" then
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
      local decoded, args = pcall(vim.json.decode, parsed.fragment)
      if decoded then
        for i, value in ipairs(args) do
          if value == "--" then
            path = args[i + 1]
            break
          end
        end
      end
    end
    if type(path) == "string" and path ~= "" then
      local absolute = not parsed.legacy and (path:match("^/") or path:match("^%a:[/\\]"))
      local joined = absolute and path or (parsed.root .. "/" .. path)
      -- Older supported Neovim versions cannot disable home expansion directly.
      if joined:sub(1, 1) == "~" then
        joined = "./" .. joined
      end
      return vim.fs.normalize(joined, { expand_env = false })
    end
    return name
  end)
  return ok and expanded or name
end

return M
