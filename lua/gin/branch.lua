local M = {}
local git = require("gin.git")
local uri = require("gin.uri")
local parse_flag = require("gin.flags").parse
local format_flag = require("gin.flags").format
local action = require("gin.action")

function M.candidates(buf, range)
  local rows, selected, seen = vim.b[buf].gin_branches or {}, {}, {}
  for i = math.max(1, range[1]), math.min(#rows, range[2]) do
    local key = rows[i].kind .. ":" .. rows[i].target
    if not seen[key] then
      selected[#selected + 1] = rows[i]
      seen[key] = true
    end
  end
  return selected
end

local function arguments(parsed)
  if not parsed.legacy then
    return parsed.params.args and vim.json.decode(parsed.params.args) or {},
      parsed.fragment and uri.split(parsed.fragment) or {}
  end
  local flags = {}
  for _, key in ipairs(require("gin.flags").order(parsed.param_order)) do
    vim.list_extend(flags, format_flag(key, parsed.params[key]))
  end
  return flags,
    parsed.fragment and vim.split(
      parsed.fragment:gsub("%$$", ""),
      " ",
      { plain = true, trimempty = true }
    ) or {}
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  local flags, patterns = arguments(parsed)
  local args = { "branch", "--list", "-vv", "--color=always" }
  local format, all
  local verbose = 2
  local colored = true
  local objectname = "%(objectname:short)"
  for _, arg in ipairs(flags) do
    if arg:sub(1, 9) == "--format=" then
      format = arg:sub(10)
    else
      args[#args + 1] = arg
      if arg == "--all" or arg == "-a" then
        all = true
      elseif arg == "--remotes" or arg == "-r" then
        all = false
      elseif arg == "--no-abbrev" or arg == "--abbrev=0" then
        objectname = "%(objectname)"
      elseif arg == "--abbrev" then
        objectname = "%(objectname:short)"
      elseif arg:match("^%-%-abbrev=%d+$") then
        objectname = "%(objectname:short=" .. arg:match("=(%d+)$") .. ")"
      elseif arg == "--no-color" or arg == "--color=never" or arg == "--color=auto" then
        colored = false
      elseif arg == "--color" or arg == "--color=always" then
        colored = true
      elseif arg == "--no-verbose" then
        verbose = 0
      elseif arg == "--verbose" then
        verbose = verbose + 1
      elseif arg:match("^%-v+$") then
        verbose = verbose + #arg - 1
      end
    end
  end
  local boundary = vim.fn.sha256(vim.fn.tempname())
  args[#args + 1] = "--format=%00"
    .. boundary
    .. "%00%(HEAD)%00%(refname)%00"
    .. objectname
    .. "%00%(subject)%00%(upstream:short)%00%(upstream:track)%00%(worktreepath)%00%(symref)%00"
    .. (format or "")
  args[#args + 1] = "--"
  vim.list_extend(args, patterns)
  local output = git.run(args, { cwd = parsed.root, progress = true }).stdout
  local colors = {}
  local defaults = {
    current = "green",
    remote = "red",
    ["local"] = "normal",
    upstream = "blue",
    worktree = "cyan",
  }
  local function paint(slot, text)
    if not colored or format then
      return text
    end
    if colors[slot] == nil then
      colors[slot] = git.run(
        { "config", "--get-color", "color.branch." .. slot, defaults[slot] },
        { cwd = parsed.root }
      ).stdout
    end
    return colors[slot] .. text .. "\27[m"
  end
  local rows, lines = {}, {}
  local records = vim.split(output, "\0" .. boundary .. "\0", { plain = true })
  local width, names, targets = 0, {}, {}
  for i = 2, #records do
    records[i] = vim.split(records[i]:sub(1, -2), "\0", { plain = true })
    targets[i] = records[i][2]:gsub("^refs/heads/", ""):gsub("^refs/remotes/", "")
    names[i] = all and records[i][2]:match("^refs/remotes/") and ("remotes/" .. targets[i])
      or targets[i]
    width = math.max(width, vim.fn.strdisplaywidth(names[i]))
  end
  for i = 2, #records do
    local fields = records[i]
    local remote = fields[2]:match("^refs/remotes/(.-)/")
    local target = targets[i]
    local row = {
      head = fields[1],
      target = target,
      commit = fields[3],
      branch = remote and target:sub(#remote + 2) or target,
      remote = remote,
      worktree = fields[7] ~= "" and fields[7] or nil,
      kind = fields[8] ~= "" and "alias" or remote and "remote" or "local",
    }
    local tracking = fields[5] ~= ""
        and (" [" .. paint("upstream", fields[5]) .. (fields[6] ~= "" and ": " .. fields[6]:sub(
          2,
          -2
        ) or "") .. "]")
      or ""
    if verbose < 2 then
      tracking = fields[6] ~= "" and (" " .. fields[6]) or ""
    end
    local linked = row.worktree and row.head ~= "*"
    local marker = linked and "+" or row.head
    local location = linked and verbose > 1 and (" (" .. paint("worktree", row.worktree) .. ")")
      or ""
    local padded = names[i]
      .. (verbose > 0 and string.rep(" ", width - vim.fn.strdisplaywidth(names[i])) or "")
    padded = paint(
      row.head == "*" and "current" or linked and "worktree" or remote and "remote" or "local",
      padded
    )
    local display = format and table.concat(fields, "\0", 9)
      or row.kind == "alias" and ("  " .. padded .. " -> " .. fields[8]
        :gsub("^refs/heads/", "")
        :gsub("^refs/remotes/", ""))
      or verbose == 0 and (marker .. " " .. padded)
      or marker .. " " .. padded .. " " .. row.commit .. location .. tracking .. " " .. fields[4]
    for _, line in ipairs(vim.split(display, "\n", { plain = true })) do
      rows[#rows + 1] = row
      lines[#lines + 1] = line
    end
  end
  require("gin.buffer").replace_output(
    buf,
    table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""),
    parsed.root,
    "gin-branch",
    parsed.params
  )
  vim.b[buf].gin_branches = rows
  action.setup(buf, M.candidates)
  local group = vim.api.nvim_create_augroup("gin_branch_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "GinCommandPost",
    callback = function()
      require("gin.util").reload(buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })
  local function run(args)
    local result = git.run(args, { cwd = parsed.root, progress = "both" })
    require("gin.command").finish(result, {}, {})
  end
  for _, detach in ipairs({ false, true }) do
    action.define(buf, detach and "switch:detach" or "switch", function(target, range)
      local row = M.candidates(target, range)[1]
      if row then
        local args = { "switch" }
        if detach then
          args[#args + 1] = "--detach"
        end
        vim.list_extend(args, { "--", row.branch })
        run(args)
      end
    end)
  end
  for _, force in ipairs({ false, true }) do
    action.define(buf, force and "delete:force" or "delete", function(target, range)
      local rows = M.candidates(target, range)
      for _, row in ipairs(rows) do
        if row.kind == "remote" then
          run({ "push", "--delete", row.remote, row.branch })
        elseif row.kind ~= "alias" then
          if row.worktree and row.head ~= "*" then
            local args = { "worktree", "remove" }
            if force then
              args[#args + 1] = "--force"
            end
            vim.list_extend(args, { "--", row.worktree })
            git.run(args, { cwd = parsed.root, progress = "both" })
          end
          run({ "branch", force and "-D" or "-d", "--", row.branch })
        end
      end
    end)
  end
  for _, variant in ipairs({ "new", "new:force", "new:orphan" }) do
    action.define(buf, variant, function(target, range)
      local row = M.candidates(target, range)[1]
      local from = row and row.target or "HEAD"
      local orphan = variant == "new:orphan"
      vim.ui.input({
        prompt = orphan and "New branch (orphan): " or ("New branch (from " .. from .. "): "),
        default = not orphan and from or nil,
      }, function(value)
        if not value or value == "" then
          vim.api.nvim_echo({ { "Cancelled", "ErrorMsg" } }, true, {})
          return
        end
        local args =
          { "switch", orphan and "--orphan" or variant == "new:force" and "-C" or "-c", value }
        if not orphan then
          args[#args + 1] = from
        end
        run(args)
      end)
    end)
  end
  for _, force in ipairs({ false, true }) do
    action.define(buf, force and "move:force" or "move", function(target, range)
      local row = M.candidates(target, range)[1]
      if not row then
        return
      end
      local worktree = row.worktree and row.head ~= "*"
      local from = worktree and row.worktree or row.branch
      vim.ui.input({
        prompt = (worktree and "New path (from " or "Rename (from ") .. from .. "): ",
        default = from,
      }, function(value)
        if not value or value == "" then
          vim.api.nvim_echo({ { "Cancelled", "ErrorMsg" } }, true, {})
          return
        end
        local args = worktree and { "worktree", "move" } or { "branch", "--move" }
        if force then
          args[#args + 1] = "--force"
        end
        vim.list_extend(args, { "--", from, value })
        run(args)
      end)
    end)
  end
  for _, variant in ipairs({ "worktree", "worktree:force", "worktree:orphan" }) do
    action.define(buf, variant, function(target, range)
      local row = M.candidates(target, range)[1]
      local from = row and row.target or "HEAD"
      local orphan = variant == "worktree:orphan"
      vim.ui.input({
        prompt = orphan and "New branch (orphan): " or ("New branch (from " .. from .. "): "),
        default = not orphan and from or nil,
      }, function(branch)
        if not branch or branch == "" then
          vim.api.nvim_echo({ { "Cancelled", "ErrorMsg" } }, true, {})
          return
        end
        local common =
          vim.trim(git.run({ "rev-parse", "--git-common-dir" }, { cwd = parsed.root }).stdout)
        if common:sub(1, 1) ~= "/" then
          common = parsed.root .. "/" .. common
        end
        local parent = vim.fs.dirname(vim.fs.normalize(common))
        vim.ui.input({
          prompt = "Worktree path (for " .. branch .. "): ",
          default = parent .. "/.worktrees/" .. branch:gsub("[/\\]", "_"),
          completion = "dir",
        }, function(path)
          if not path or path == "" then
            vim.api.nvim_echo({ { "Cancelled", "ErrorMsg" } }, true, {})
            return
          end
          if path:sub(1, 1) ~= "/" then
            path = parsed.root .. "/" .. path
          end
          local args = { "worktree", "add" }
          if variant == "worktree:force" then
            args[#args + 1] = "--force"
          end
          if orphan then
            args[#args + 1] = "--orphan"
          end
          if orphan or branch ~= from then
            vim.list_extend(args, { "-b", branch })
          end
          vim.list_extend(args, { "--", path })
          if not orphan then
            args[#args + 1] = from
          end
          run(args)
          vim.fn.chdir(path)
        end)
      end)
    end)
  end
  for _, method in ipairs({ "ff", "no-ff", "ff-only" }) do
    action.define(buf, "merge:" .. method, function(target, range)
      local row = M.candidates(target, range)[1]
      if row then
        return require("gin.command").execute({
          fargs = { "++worktree=" .. parsed.root, "merge", "--" .. method, row.target },
          smods = {},
          on_exit = function()
            vim.cmd("silent checktime")
          end,
        })
      end
    end)
  end
  action.alias(buf, "merge", "merge:ff")
  for _, variant in ipairs({ "rebase", "rebase:x", "rebase:i", "rebase:i:x", "rebase:instant-drop" }) do
    action.define(buf, variant, function(target, range)
      local row = M.candidates(target, range)[1]
      if not row then
        return
      end
      local args = variant == "rebase:instant-drop"
          and { "rebase", "--onto", row.target .. "~", row.target, "HEAD" }
        or { "rebase", row.target }
      local interactive = variant == "rebase:i" or variant == "rebase:i:x"
      if interactive then
        args[#args + 1] = "--interactive"
      end
      local function execute()
        if interactive then
          local fargs = { "++worktree=" .. parsed.root }
          vim.list_extend(fargs, args)
          return require("gin.command").execute({
            fargs = fargs,
            smods = {},
            on_exit = function()
              vim.cmd("silent checktime")
            end,
          })
        end
        run(args)
        vim.cmd("silent checktime")
      end
      if variant == "rebase:x" or variant == "rebase:i:x" then
        vim.ui.input({ prompt = "Execute command after rebase: " }, function(command)
          if not command or command == "" then
            return
          end
          vim.list_extend(args, { "-x", command })
          execute()
        end)
      else
        return execute()
      end
    end)
  end
  for _, opener in ipairs({ "edit", "split", "vsplit", "tabedit" }) do
    action.define(buf, "log:" .. opener, function(target, range)
      for _, row in ipairs(M.candidates(target, range)) do
        local ref = row.target:find(" ", 1, true) and row.commit
          or (row.remote and "refs/remotes/" or "refs/heads/") .. row.target
        require("gin.log").command({
          fargs = { "++opener=" .. opener, ref },
          smods = {},
        })
      end
    end)
  end
  action.alias(buf, "log", "log:edit")
  for _, field in ipairs({ "branch", "target", "commit" }) do
    action.define(buf, "yank:" .. field, function(target, range)
      local values = {}
      for _, row in ipairs(M.candidates(target, range)) do
        values[#values + 1] = row[field]
      end
      vim.fn.setreg(vim.v.register, table.concat(values, "\n"))
    end)
  end
end

function M.command(opts)
  local args = require("gin.command").arguments("branch", opts.fargs)
  local options, residue = require("gin.command").parse(
    args,
    { "worktree", "opener", "enc", "encoding", "ff", "fileformat" }
  )
  local flags, patterns, paths = {}, {}, false
  for _, value in ipairs(residue) do
    if value == "--" and not paths then
      paths = true
    elseif not paths and parse_flag(value) then
      flags[#flags + 1] = value
    else
      patterns[#patterns + 1] = value
    end
  end
  local root = require("gin.worktree").current(options.worktree)
  options.bang, options.smods = opts.bang, opts.smods
  return require("gin.buffer").open(
    uri.format("ginbranch", root, {
      args = vim.json.encode(require("gin.flags").group(flags)),
      enc = options.enc or options.encoding,
      ff = options.ff or options.fileformat,
    }, uri.join(patterns)),
    options
  )
end

return M
