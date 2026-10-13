local M = {}

function M.sections(lines)
  local sections, current = {}, nil
  local old_left, new_left = 0, 0
  local function close(last)
    if current then
      current.last = last
      sections[#sections + 1] = current
      current = nil
    end
  end
  for i, line in ipairs(lines) do
    if line:match("^diff ") then
      close(i - 1)
      old_left, new_left = 0, 0
    elseif line:match("^@@ ") then
      local a, ac, b, bc = line:match("^@@ %-(%d+)([,0-9]*) %+(%d+)([,0-9]*) @@")
      if a and b then
        old_left = ac == "" and 1 or tonumber(ac:sub(2))
        new_left = bc == "" and 1 or tonumber(bc:sub(2))
      end
    elseif old_left > 0 or new_left > 0 then
      local prefix = line:sub(1, 1)
      old_left = old_left - ((prefix == " " or prefix == "-") and 1 or 0)
      new_left = new_left - ((prefix == " " or prefix == "+") and 1 or 0)
    elseif line:match("^%-%-%- ") and (lines[i + 1] or ""):match("^%+%+%+ ") then
      close(i - 1)
      current = { first = i }
    end
  end
  close(#lines)
  return sections
end

function M.text()
  local lines = vim.api.nvim_buf_get_lines(0, vim.v.foldstart - 1, vim.v.foldend, false)
  local path = require("gin.diffjump").path
  local old, new = path(lines[1]:sub(5)), path(lines[2]:sub(5))
  local kind, label = "modified", new
  if old == "/dev/null" then
    kind = "added"
  elseif new == "/dev/null" then
    kind, label = "deleted", old
  elseif old ~= new then
    kind, label = "renamed", old .. " -> " .. new
  end
  local added, deleted = 0, 0
  for i = 3, #lines do
    local prefix = lines[i]:sub(1, 1)
    added = added + (prefix == "+" and 1 or 0)
    deleted = deleted + (prefix == "-" and 1 or 0)
  end
  local stats = {}
  if added > 0 then
    stats[#stats + 1] = "+" .. added
  end
  if deleted > 0 then
    stats[#stats + 1] = "-" .. deleted
  end
  local prefixes = vim.tbl_extend("force", {
    added = "[+]",
    deleted = "[-]",
    modified = "[.]",
    renamed = "[/]",
  }, vim.g.gin_difffold_prefixes or {})
  return prefixes[kind] .. " " .. label .. " (" .. table.concat(stats, " ") .. ")"
end

function M.apply(buf)
  local sections = M.sections(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.api.nvim_win_call(win, function()
      vim.wo.foldenable = true
      vim.wo.foldmethod = "manual"
      vim.wo.foldtext = "v:lua.require'gin.difffold'.text()"
      vim.cmd("normal! zE")
      for _, section in ipairs(sections) do
        vim.api.nvim_cmd({ cmd = "fold", range = { section.first, section.last } }, {})
      end
      vim.wo.foldlevel = 1
    end)
  end
end

function M.setup(buf)
  if not vim.b[buf].gin_difffold_initialized then
    vim.api.nvim_create_autocmd("BufWinEnter", {
      buffer = buf,
      callback = function()
        M.apply(buf)
      end,
    })
    vim.b[buf].gin_difffold_initialized = true
  end
  M.apply(buf)
end

return M
