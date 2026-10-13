local M = {}
local uri = require("gin.uri")
local action = require("gin.action")

function M.candidates(buf, range)
  local result = {}
  for _, line in
    ipairs(
      vim.api.nvim_buf_get_lines(
        buf,
        math.max(0, range[1] - 1),
        math.min(vim.api.nvim_buf_line_count(buf), range[2]),
        false
      )
    )
  do
    local text = line:gsub("^[ *|\\/+%=<>%-]*", "")
    text = text:gsub("^commit [+%=<>%-]? ?", "")
    local commit = text:match("^(%x+)%f[%X]") or text:match("^(%x+)$")
    if commit and #commit >= 4 then
      result[#result + 1] = { commit = commit }
    end
  end
  return result
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  local kind = parsed.scheme == "ginreflog" and "reflog" or "log"
  local args = kind == "reflog" and { "reflog", "show" } or { "log" }
  vim.list_extend(args, { "--decorate=short", "--color=always" })
  vim.list_extend(args, parsed.fragment and vim.json.decode(parsed.fragment) or {})
  local output = require("gin.git").run(args, { cwd = parsed.root }).stdout
  require("gin.buffer").replace_output(buf, output, parsed.root, "gin-" .. kind, parsed.params)
  vim.bo[buf].buflisted, vim.bo[buf].modeline = false, false
  action.setup(buf, M.candidates)
  for _, opener in ipairs({ "edit", "split", "vsplit", "tabedit" }) do
    action.define(buf, "show:" .. opener, function(target, range)
      for _, row in ipairs(M.candidates(target, range)) do
        require("gin.buffer").open(
          uri.format("gin", parsed.root, {
            filetype = "git",
            diffjump = row.commit,
            difffold = "",
          }, uri.join({ "show", row.commit })),
          { opener = opener }
        )
      end
    end)
  end
  action.alias(buf, "show", "show:edit")
  for _, detach in ipairs({ false, true }) do
    action.define(buf, detach and "switch:detach" or "switch", function(target, range)
      local row = M.candidates(target, range)[1]
      if not row then
        return
      end
      local args = { "switch" }
      if detach then
        args[#args + 1] = "--detach"
      end
      vim.list_extend(args, { "--", row.commit })
      require("gin.command").finish(require("gin.git").run(args, { cwd = parsed.root }), {}, {})
    end)
  end
  local function run(args)
    require("gin.command").finish(require("gin.git").run(args, { cwd = parsed.root }), {}, {})
  end
  for _, method in ipairs({ "ff", "no-ff", "ff-only" }) do
    action.define(buf, "merge:" .. method, function(target, range)
      local row = M.candidates(target, range)[1]
      if row then
        run({ "merge", "--" .. method, row.commit })
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
          and { "rebase", "--onto", row.commit .. "~", row.commit, "HEAD" }
        or { "rebase", row.commit }
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
  for _, command in ipairs({ "cherry-pick", "revert" }) do
    for _, mainline in ipairs({ "", "1", "2" }) do
      action.define(
        buf,
        command .. (mainline ~= "" and ":" .. mainline or ""),
        function(target, range)
          local row = M.candidates(target, range)[1]
          if not row then
            return
          end
          local args = { command }
          if mainline ~= "" then
            vim.list_extend(args, { "--mainline", mainline })
          end
          args[#args + 1] = row.commit
          local result = require("gin.git").run(args, { cwd = parsed.root })
          require("gin.command").finish(result, {}, {})
        end
      )
    end
  end
  for _, mode in ipairs({ "", "soft", "hard", "merge", "keep" }) do
    action.define(buf, "reset" .. (mode ~= "" and ":" .. mode or ""), function(target, range)
      local row = M.candidates(target, range)[1]
      if not row then
        return
      end
      local args = { "reset", "--quiet" }
      if mode ~= "" then
        args[#args + 1] = "--" .. mode
      end
      args[#args + 1] = row.commit
      require("gin.command").finish(require("gin.git").run(args, { cwd = parsed.root }), {}, {})
    end)
  end
  for _, force in ipairs({ false, true }) do
    action.define(
      buf,
      force and "tag:lightweight:force" or "tag:lightweight",
      function(target, range)
        local row = M.candidates(target, range)[1]
        if not row then
          return
        end
        vim.ui.input({ prompt = "Name: " }, function(name)
          if not name or name == "" then
            return
          end
          local args = { "tag" }
          if force then
            args[#args + 1] = "--force"
          end
          vim.list_extend(args, { "--", name, row.commit })
          require("gin.command").finish(require("gin.git").run(args, { cwd = parsed.root }), {}, {})
        end)
      end
    )
  end
  for _, force in ipairs({ false, true }) do
    action.define(buf, force and "tag:annotate:force" or "tag:annotate", function(target, range)
      local row = M.candidates(target, range)[1]
      if not row then
        return
      end
      vim.ui.input({ prompt = "Name: " }, function(name)
        if not name or name == "" then
          return
        end
        local args = { "++worktree=" .. parsed.root, "tag", "--annotate" }
        if force then
          args[#args + 1] = "--force"
        end
        vim.list_extend(args, { "--", name, row.commit })
        require("gin.command").execute({
          fargs = args,
          smods = {},
          on_exit = function()
            vim.cmd("silent checktime")
          end,
        })
      end)
    end)
  end
  action.alias(buf, "tag", "tag:annotate")
  for _, instant in ipairs({ false, true }) do
    action.define(buf, instant and "fixup:instant-fixup" or "fixup:fixup", function(target, range)
      local rows = M.candidates(target, range)
      if #rows == 0 then
        return
      end
      assert(#rows == 1, "Fixup requires exactly one commit")
      local commit = rows[1].commit
      local git = require("gin.git")
      local result = git.run({ "commit", "--fixup=" .. commit }, { cwd = parsed.root })
      require("gin.command").finish(result, {}, {})
      if instant then
        local parent = git.run(
          { "rev-parse", "--verify", commit .. "^" },
          { cwd = parsed.root, check = false }
        )
        local args = {
          "-c",
          "sequence.editor=true",
          "rebase",
          "--interactive",
          "--autostash",
          "--autosquash",
          "--quiet",
        }
        args[#args + 1] = parent.code == 0 and vim.trim(parent.stdout) or "--root"
        require("gin.command").finish(git.run(args, { cwd = parsed.root }), {}, {})
        vim.cmd("silent checktime")
      end
    end)
  end
  action.alias(buf, "fixup", "fixup:fixup")
  action.define(buf, "yank:commit", function(target, range)
    local values = {}
    for _, row in ipairs(M.candidates(target, range)) do
      values[#values + 1] = row.commit
    end
    vim.fn.setreg(vim.v.register, table.concat(values, "\n"))
  end)
  local group = vim.api.nvim_create_augroup("gin_" .. kind .. "_" .. buf, { clear = true })
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
  if
    not vim.g["gin_" .. kind .. "_disable_default_mappings"]
    or vim.g["gin_" .. kind .. "_disable_default_mappings"] == 0
  then
    for key, name in pairs({
      a = "choice",
      ["."] = "repeat",
      ["?"] = "help",
      ["<CR>"] = "show",
      yy = "yank:commit",
    }) do
      vim.keymap.set(
        "n",
        key,
        "<Plug>(gin-action-" .. name .. ")",
        { buffer = buf, remap = true, nowait = true }
      )
    end
    vim.keymap.set("x", "y", "<Plug>(gin-action-yank:commit)<Esc>", { buffer = buf, remap = true })
  end
end

function M.open(root, args, options)
  options = options or {}
  return require("gin.buffer").open(
    uri.format("gin" .. (options.kind or "log"), root, {
      enc = options.enc or options.encoding,
      ff = options.ff or options.fileformat,
    }, vim.json.encode(args)),
    options
  )
end

function M.command(opts, kind)
  kind = kind or "log"
  local args = vim.deepcopy(vim.g["gin_" .. kind .. "_persistent_args"] or {})
  vim.list_extend(
    args,
    #opts.fargs == 0 and (vim.g["gin_" .. kind .. "_default_args"] or {}) or opts.fargs
  )
  local options, residue = require("gin.command").parse(
    args,
    { "worktree", "opener", "enc", "encoding", "ff", "fileformat" }
  )
  options.bang, options.smods, options.kind = opts.bang, opts.smods, kind
  return M.open(require("gin.worktree").current(options.worktree), residue, options)
end

return M
