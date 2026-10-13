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
  M.mappings(buf)
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

function M.candidates(buf, range)
  return vim.tbl_filter(function(entry)
    return entry.line >= range[1] and entry.line <= range[2]
  end, vim.b[buf].gin_status_entries or {})
end

function M.action(buf, name, range)
  local root = vim.b[buf].gin_worktree
  local paths, removed, intent = {}, {}, {}
  local unstage = name == "unstage" or name == "unstage:intent-to-add"
  for _, entry in ipairs(vim.b[buf].gin_status_entries or {}) do
    if entry.line >= range[1] and entry.line <= range[2] then
      if unstage then
        if name == "unstage:intent-to-add" and entry.xy == "A " then
          intent[#intent + 1] = entry.path
        end
        paths[#paths + 1] = entry.path
        if entry.orig_path then
          paths[#paths + 1] = entry.orig_path
        end
      elseif name == "stage" or name == "stage:intent-to-add" then
        if name == "stage:intent-to-add" and entry.xy == "??" then
          intent[#intent + 1] = entry.path
        elseif entry.xy:sub(2, 2) == "D" then
          removed[#removed + 1] = entry.path
        elseif name == "stage:intent-to-add" or entry.xy:sub(2, 2) ~= " " then
          paths[#paths + 1] = entry.path
        end
      end
    end
  end
  if #paths == 0 and #removed == 0 and #intent == 0 then
    return
  end
  if #removed > 0 then
    git.run(
      vim.list_extend({ "rm", "--quiet", "--ignore-unmatch", "--cached", "--" }, removed),
      { cwd = root }
    )
  end
  if #paths > 0 then
    local args = unstage and { "reset", "--quiet", "--" }
      or { "add", "--ignore-errors", "--force", "--" }
    git.run(vim.list_extend(args, paths), { cwd = root })
  end
  if #intent > 0 then
    git.run(
      vim.list_extend({ "add", "--ignore-errors", "--force", "--intent-to-add", "--" }, intent),
      { cwd = root }
    )
  end
  require("gin.command").post()
end

function M.mappings(buf)
  local action = require("gin.action")
  action.setup(buf)
  for _, name in ipairs({ "stage", "unstage", "stage:intent-to-add", "unstage:intent-to-add" }) do
    action.define(buf, name, function(target, range)
      M.action(target, name, range)
    end)
  end
  action.alias(buf, "reset", "unstage")
  require("gin.file_actions").setup(buf, M.candidates)
  if
    not vim.g.gin_status_disable_default_mappings
    or vim.g.gin_status_disable_default_mappings == 0
  then
    vim.keymap.set(
      "n",
      "yy",
      "<Plug>(gin-action-yank:path)",
      { buffer = buf, remap = true, nowait = true }
    )
    vim.keymap.set(
      "x",
      "y",
      "<Plug>(gin-action-yank:path)<Esc>",
      { buffer = buf, remap = true, nowait = true }
    )
    for lhs, action in pairs({
      ["<<"] = "stage",
      [">>"] = "unstage",
      ["=="] = "stash",
      dd = "diff:smart",
      a = "choice",
      ["<CR>"] = "edit",
      ["."] = "repeat",
      ["?"] = "help",
    }) do
      vim.keymap.set(
        { "n", "x" },
        lhs,
        "<Plug>(gin-action-" .. action .. ")",
        { buffer = buf, remap = true, nowait = true }
      )
    end
  end
end

return M
