local M = {}
local git = require("gin.git")
local uri = require("gin.uri")
local action = require("gin.action")

function M.candidates(buf, range)
  local rows, selected = vim.b[buf].gin_branches or {}, {}
  for i = math.max(1, range[1]), math.min(#rows, range[2]) do
    selected[#selected + 1] = rows[i]
  end
  return selected
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  local args = { "branch", "--list", "--no-color" }
  vim.list_extend(args, parsed.params.args and vim.json.decode(parsed.params.args) or {})
  args[#args + 1] =
    "--format=%(HEAD)%00%(refname)%00%(objectname:short)%00%(subject)%00%(upstream:short)%00%(upstream:track)%00%(worktreepath)%00%(symref)"
  args[#args + 1] = "--"
  vim.list_extend(args, parsed.fragment and uri.split(parsed.fragment) or {})
  local output = git.run(args, { cwd = parsed.root }).stdout
  local rows, lines = {}, {}
  for line in output:gmatch("[^\n]+") do
    local fields = vim.split(line, "\0", { plain = true })
    local remote = fields[2]:match("^refs/remotes/(.-)/")
    local target = fields[2]:gsub("^refs/heads/", ""):gsub("^refs/remotes/", "")
    local row = {
      head = fields[1],
      target = target,
      commit = fields[3],
      branch = remote and target:sub(#remote + 2) or target,
      remote = remote,
      worktree = fields[7] ~= "" and fields[7] or nil,
      kind = fields[8] ~= "" and "alias" or remote and "remote" or "local",
    }
    rows[#rows + 1] = row
    local tracking = fields[5] ~= ""
        and (" [" .. fields[5] .. (fields[6] ~= "" and ": " .. fields[6]:sub(2, -2) or "") .. "]")
      or ""
    lines[#lines + 1] = row.head
      .. " "
      .. target
      .. " "
      .. row.commit
      .. tracking
      .. " "
      .. fields[4]
  end
  require("gin.buffer").replace(buf, #lines > 0 and lines or { "" }, parsed.root, "gin-branch")
  vim.b[buf].gin_branches = rows
  action.setup(buf)
  local group = vim.api.nvim_create_augroup("gin_branch_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "GinCommandPost",
    callback = function()
      if vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_buf_call(buf, function()
          local view = vim.fn.winsaveview()
          M.read(buf, name)
          vim.fn.winrestview(view)
        end)
      end
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
    local result = git.run(args, { cwd = parsed.root })
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
            git.run(args, { cwd = parsed.root })
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
  for _, field in ipairs({ "branch", "target", "commit" }) do
    action.define(buf, "yank:" .. field, function(target, range)
      local values = {}
      for _, row in ipairs(M.candidates(target, range)) do
        values[#values + 1] = row[field]
      end
      vim.fn.setreg(vim.v.register, table.concat(values, "\n"))
    end)
  end
  if
    not vim.g.gin_branch_disable_default_mappings
    or vim.g.gin_branch_disable_default_mappings == 0
  then
    for key, name in pairs({
      a = "choice",
      ["."] = "repeat",
      ["?"] = "help",
      ["<CR>"] = "switch",
      yy = "yank:branch",
    }) do
      vim.keymap.set(
        "n",
        key,
        "<Plug>(gin-action-" .. name .. ")",
        { buffer = buf, remap = true, nowait = true }
      )
    end
    vim.keymap.set("x", "y", "<Plug>(gin-action-yank:branch)<Esc>", { buffer = buf, remap = true })
  end
end

function M.command(opts)
  local args = vim.deepcopy(vim.g.gin_branch_persistent_args or {})
  vim.list_extend(args, #opts.fargs == 0 and (vim.g.gin_branch_default_args or {}) or opts.fargs)
  local options, residue = require("gin.command").parse(args, { "worktree", "opener" })
  local flags, patterns, paths = {}, {}, false
  for _, value in ipairs(residue) do
    if value == "--" and not paths then
      paths = true
    elseif not paths and value:sub(1, 1) == "-" then
      flags[#flags + 1] = value
    else
      patterns[#patterns + 1] = value
    end
  end
  local root = require("gin.worktree").current(options.worktree)
  options.bang, options.smods = opts.bang, opts.smods
  return require("gin.buffer").open(
    uri.format("ginbranch", root, { args = vim.json.encode(flags) }, uri.join(patterns)),
    options
  )
end

return M
