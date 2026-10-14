local git = require("gin.git")
local uri = require("gin.uri")
local parse_flag = require("gin.flags").parse
local format_flag = require("gin.flags").format
local buffer = require("gin.buffer")
local M = {}

---Read NUL-terminated short status, preserving all filename bytes.
function M.parse(output)
  local records = vim.split(output, "\0", { plain = true, trimempty = true })
  local entries, prefixes, branch, i = {}, {}, nil, 1
  while i <= #records do
    local record = records[i]
    if record:sub(1, 2) == "##" then
      branch = record
    else
      -- Only the two status columns and their separator may contain Git colors.
      -- Filename bytes after that separator must never be interpreted as ANSI.
      local offset, columns = 1, {}
      for column = 1, 3 do
        while true do
          local after = record:sub(offset):match("^\27%[[%d;]*m()")
          if not after then
            break
          end
          offset = offset + after - 1
        end
        columns[column] = record:sub(offset, offset)
        offset = offset + 1
      end
      local entry = { xy = columns[1] .. columns[2], path = record:sub(offset) }
      prefixes[entry.path] = record:sub(1, offset - 1)
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
  return branch, entries, prefixes
end

local function quote(path)
  if path:find('[%s%c"\\]') then
    return (vim.json.encode(path):gsub("\\/", "/"))
  end
  return path
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  local args = {
    "-c",
    "color.status=always",
    "status",
    "--short",
    "--branch",
    "--ahead-behind",
    "-z",
  }
  for _, key in ipairs(require("gin.flags").order(parsed.param_order)) do
    if key ~= "enc" and key ~= "ff" then
      vim.list_extend(args, format_flag(key, parsed.params[key]))
    end
  end
  args[#args + 1] = "--"
  local fragment = parsed.fragment
  if fragment and parsed.legacy then
    fragment = fragment:gsub("%$$", "")
  end
  vim.list_extend(args, fragment and vim.json.decode(fragment) or {})
  local branch, entries, prefixes =
    M.parse(git.run(args, { cwd = parsed.root, progress = true }).stdout)
  local lines = { branch or "## HEAD" }
  for _, entry in ipairs(entries) do
    entry.line = #lines + 1
    lines[#lines + 1] = prefixes[entry.path]
      .. (entry.orig_path and quote(entry.orig_path) .. " -> " or "")
      .. quote(entry.path)
  end
  buffer.replace_output(
    buf,
    table.concat(lines, "\n") .. "\n",
    parsed.root,
    "gin-status",
    parsed.params
  )
  vim.b[buf].gin_status_entries = entries
  vim.bo[buf].buflisted = false
  vim.bo[buf].modeline = false
  M.mappings(buf)
  local group = vim.api.nvim_create_augroup("gin_status_" .. buf, { clear = true })
  local function reload()
    require("gin.util").reload(buf)
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
  local args = require("gin.command").arguments("status", opts.fargs)
  local options, residue = require("gin.command").parse(
    args,
    { "worktree", "opener", "enc", "encoding", "ff", "fileformat" }
  )
  local flags, paths, path_mode = {}, {}, false
  -- Upstream inserts this default before merging the parsed flag names.
  local flag_order = { "untracked-files" }
  local allowed = {
    "u",
    "untracked-files",
    "ignore-submodules",
    "ignored",
    "renames",
    "no-renames",
    "find-renames",
  }
  for _, arg in ipairs(residue) do
    local key, value = parse_flag(arg)
    if not path_mode and arg == "--" then
      path_mode = true
    elseif not path_mode and key then
      if not vim.tbl_contains(allowed, key) then
        error("Unsupported GinStatus flag: " .. arg, 0)
      end
      value = value or ""
      if flags[key] == nil then
        if key ~= "untracked-files" then
          flag_order[#flag_order + 1] = key
        end
        flags[key] = value
      else
        if type(flags[key]) ~= "table" then
          flags[key] = { flags[key] }
        end
        table.insert(flags[key], value)
      end
    else
      paths[#paths + 1] = arg
    end
  end
  flags["untracked-files"] = flags["untracked-files"] or ""
  local root = require("gin.worktree").current(options.worktree)
  return buffer.open(
    uri.format(
      "ginstatus",
      root,
      vim.tbl_extend("force", flags, {
        enc = options.enc or options.encoding,
        ff = options.ff or options.fileformat,
      }),
      #paths > 0 and vim.json.encode(paths) or nil,
      flag_order
    ),
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
      { cwd = root, progress = "both" }
    )
  end
  if #paths > 0 then
    local args = unstage and { "reset", "--quiet", "--" }
      or { "add", "--ignore-errors", "--force", "--" }
    git.run(vim.list_extend(args, paths), { cwd = root, progress = "both" })
  end
  if #intent > 0 then
    git.run(
      vim.list_extend({ "add", "--ignore-errors", "--force", "--intent-to-add", "--" }, intent),
      { cwd = root, progress = "both" }
    )
  end
  require("gin.command").post()
end

function M.mappings(buf)
  local action = require("gin.action")
  action.setup(buf, M.candidates)
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
      pp = "patch",
      ["!!"] = "chaperon",
      a = "choice",
      ["<CR>"] = "edit",
      ["."] = "repeat",
      ["?"] = "help",
    }) do
      vim.keymap.set(
        { "n", "x" },
        lhs,
        "<Plug>(gin-action-" .. action .. ")" .. (lhs == "<CR>" and "zv" or ""),
        { buffer = buf, remap = true, nowait = true }
      )
    end
  end
end

return M
