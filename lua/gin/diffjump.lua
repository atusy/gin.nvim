local M = {}

function M.prefixes(params)
  if params["no-prefix"] ~= nil then
    return { old = "", new = "" }
  end
  local prefixes = { old = params["src-prefix"] or "a/", new = params["dst-prefix"] or "b/" }
  if params["-R"] ~= nil or params.reverse ~= nil then
    prefixes.old, prefixes.new = prefixes.new, prefixes.old
  end
  return prefixes
end

function M.path(header, prefix)
  local path = header:match("^[^\t]+") or ""
  path = require("gin.git_path").unquote(path)
  if path == "/dev/null" then
    return path
  end
  if prefix ~= nil then
    return path:sub(1, #prefix) == prefix and path:sub(#prefix + 1) or path
  end
  return path:gsub("^[ab]/", "")
end

function M.parse(lines, row, side, prefixes)
  prefixes = prefixes or {}
  local old_path, new_path, old_line, new_line
  for i = 1, row do
    local line = lines[i] or ""
    if line:match("^diff ") then
      old_path, new_path, old_line, new_line = nil, nil, nil, nil
    elseif line:match("^%-%-%- ") and not old_line then
      old_path = M.path(line:sub(5), prefixes.old)
    elseif line:match("^%+%+%+ ") and not old_line then
      new_path = M.path(line:sub(5), prefixes.new)
    elseif line:match("^@@ ") then
      local a, b = line:match("^@@ %-(%d+)[,%d]* %+(%d+)[,%d]* @@")
      old_line, new_line = tonumber(a), tonumber(b)
    elseif old_line and new_line then
      local prefix = line:sub(1, 1)
      if i == row and (prefix == " " or prefix == "-" or prefix == "+") then
        local location_side = prefix == "-" and "old" or prefix == "+" and "new" or side
        local path = location_side == "old" and old_path or new_path
        if path and path ~= "/dev/null" then
          return { path = path, lnum = math.max(1, location_side == "old" and old_line or new_line) }
        end
      end
      if prefix == " " or prefix == "-" then
        old_line = old_line + 1
      end
      if prefix == " " or prefix == "+" then
        new_line = new_line + 1
      end
    end
  end
end

local function revisions(parsed)
  local params = parsed.params
  if params.diffjump then
    local commitish = params.diffjump ~= "" and params.diffjump or "HEAD"
    return commitish .. "^", commitish
  end
  local cached = params.cached ~= nil or params.staged ~= nil
  local rev = params.commitish or ""
  local old, new
  if rev:find("...", 1, true) then
    local a, b = rev:match("^(.-)%.%.%.(.-)$")
    a, b = a ~= "" and a or "HEAD", b ~= "" and b or "HEAD"
    old = vim.trim(require("gin.git").run({ "merge-base", a, b }, { cwd = parsed.root }).stdout)
    new = b
  elseif rev:find("..", 1, true) then
    old, new = rev:match("^(.-)%.%.(.-)$")
    old, new = old ~= "" and old or "HEAD", new ~= "" and new or "HEAD"
  else
    old = rev ~= "" and rev or cached and "HEAD" or "INDEX"
    new = cached and "INDEX" or "WORKTREE"
  end
  if params["-R"] ~= nil or params.reverse ~= nil then
    old, new = new, old
  end
  return old, new
end

function M.jump(side, options)
  local parsed = require("gin.uri").parse(vim.api.nvim_buf_get_name(0))
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if side == "smart" then
    side = lines[cursor[1]]:sub(1, 1) == "-" and "old" or "new"
  end
  local target = M.parse(lines, cursor[1], side, M.prefixes(parsed.params))
  if not target then
    return
  end
  local old, new = revisions(parsed)
  local rev = side == "old" and old or new
  options = vim.deepcopy(options or {})
  if rev == "WORKTREE" then
    require("gin.buffer").open(parsed.root .. "/" .. target.path, options)
  else
    options.commitish = rev ~= "INDEX" and rev or nil
    require("gin.edit").open(parsed.root, target.path, options)
  end
  local row = math.min(target.lnum, vim.api.nvim_buf_line_count(0))
  local text = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  vim.api.nvim_win_set_cursor(0, { row, math.min(cursor[2], math.max(0, #text - 1)) })
  vim.cmd("normal! zv")
end

function M.setup(buf, kind)
  for _, side in ipairs({ "old", "new", "smart" }) do
    vim.keymap.set("n", "<Plug>(gin-diffjump-" .. side .. ")", function()
      M.jump(side)
    end, { buffer = buf })
  end
  local disabled = vim.g["gin_" .. (kind or "diff") .. "_disable_default_mappings"]
  if not disabled or disabled == 0 then
    for key, side in pairs({ ["<CR>"] = "smart", ["g<CR>"] = "old", ["<C-g><CR>"] = "new" }) do
      vim.keymap.set(
        "n",
        key,
        "<Plug>(gin-diffjump-" .. side .. ")",
        { buffer = buf, remap = true }
      )
    end
  end
end

return M
