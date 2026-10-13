local git = require("gin.git")
local uri = require("gin.uri")
local buffer = require("gin.buffer")
local M = {}

---Read porcelain v1 with NUL termination, preserving all filename bytes.
function M.parse(output)
  local records = vim.split(output, "\0", { plain = true, trimempty = true })
  local entries, branch, i = {}, nil, 1
  while i <= #records do
    local record = records[i]
    if record:sub(1, 2) == "##" then
      branch = record
    else
      local entry = { xy = record:sub(1, 2), path = record:sub(4) }
      if entry.xy:find("[RC]") then
        i = i + 1
        entry.orig_path = records[i]
      end
      entries[#entries + 1] = entry
    end
    i = i + 1
  end
  table.sort(entries, function(a, b)
    return a.path < b.path
  end)
  return branch, entries
end

local function quote(path)
  if path:find('[%s"\\]') then
    return vim.json.encode(path)
  end
  return path
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  local args = { "status", "--short", "--branch", "--ahead-behind", "--untracked-files", "-z" }
  for key, value in pairs(parsed.params) do
    args[#args + 1] = "--" .. key .. (value ~= "" and "=" .. value or "")
  end
  args[#args + 1] = "--"
  vim.list_extend(args, parsed.fragment and vim.json.decode(parsed.fragment) or {})
  local branch, entries = M.parse(git.run(args, { cwd = parsed.root }).stdout)
  local lines = { branch or "## HEAD" }
  for _, entry in ipairs(entries) do
    entry.line = #lines + 1
    lines[#lines + 1] = entry.xy
      .. " "
      .. (entry.orig_path and quote(entry.orig_path) .. " -> " or "")
      .. quote(entry.path)
  end
  buffer.replace(buf, lines, parsed.root, "gin-status")
  vim.b[buf].gin_status_entries = entries
  vim.bo[buf].buflisted = false
  vim.bo[buf].modeline = false
  local group = vim.api.nvim_create_augroup("gin_status_" .. buf, { clear = true })
  local function reload()
    if vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_call(buf, function()
        local view = vim.fn.winsaveview()
        M.read(buf, name)
        vim.fn.winrestview(view)
      end)
    end
  end
  vim.api.nvim_create_autocmd(
    "User",
    { group = group, pattern = "GinCommandPost", callback = reload }
  )
  vim.api.nvim_create_autocmd(
    { "BufWritePost", "FileWritePost" },
    { group = group, pattern = "*", callback = reload }
  )
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })
end

function M.command(opts)
  local args = vim.deepcopy(vim.g.gin_status_persistent_args or {})
  vim.list_extend(args, #opts.fargs == 0 and (vim.g.gin_status_default_args or {}) or opts.fargs)
  local options, residue = require("gin.command").parse(args, { "worktree", "opener" })
  local flags, paths, path_mode = {}, {}, false
  local allowed =
    { "untracked-files", "ignore-submodules", "ignored", "renames", "no-renames", "find-renames" }
  for _, arg in ipairs(residue) do
    if not path_mode and arg == "--" then
      path_mode = true
    elseif not path_mode and arg:sub(1, 1) == "-" then
      local key, value = arg:match("^%-%-([^=]+)=(.*)$")
      key = key or arg:match("^%-%-(.+)$")
      if arg:match("^%-u") then
        key, value = "untracked-files", arg:sub(3)
      end
      if not vim.tbl_contains(allowed, key) then
        error("Unsupported GinStatus flag: " .. arg, 0)
      end
      flags[key] = value or ""
    else
      paths[#paths + 1] = arg
    end
  end
  local root = require("gin.worktree").current(options.worktree)
  return buffer.open(
    uri.format("ginstatus", root, flags, #paths > 0 and vim.json.encode(paths) or nil),
    { opener = options.opener, bang = opts.bang, smods = opts.smods }
  )
end

return M
