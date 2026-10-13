local M = {}
local uri = require("gin.uri")
local action = require("gin.action")

function M.candidates(buf, range)
  local result = {}
  local reflog = vim.api.nvim_buf_get_name(buf):match("^ginreflog://") ~= nil
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
    local text = line
    if not reflog then
      text = text:gsub("^[ *|\\/+%=<>%-]*", "")
      if text:sub(1, 7) == "commit " then
        text = text:sub(8):gsub("^[+=<>%-] ", "")
      end
    end
    local commit = text:match("^([a-fA-F0-9]+)%f[^a-zA-Z0-9_]")
    if commit then
      result[#result + 1] = { commit = commit }
    end
  end
  return result
end

function M.insert(buf, name)
  local parsed = uri.parse(name)
  local args = parsed.scheme == "ginreflog" and { "reflog", "show" } or { "log" }
  vim.list_extend(args, parsed.fragment and vim.json.decode(parsed.fragment) or {})
  local text = require("gin.git").run(args, { cwd = parsed.root, progress = "both" }).stdout
  require("gin.buffer").insert_output(buf, name, text)
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  local kind = parsed.scheme == "ginreflog" and "reflog" or "log"
  local args = kind == "reflog" and { "reflog", "show" } or { "log" }
  vim.list_extend(args, { "--decorate=short", "--color=always" })
  vim.list_extend(args, parsed.fragment and vim.json.decode(parsed.fragment) or {})
  local output = require("gin.git").run(args, { cwd = parsed.root, progress = true }).stdout
  require("gin.buffer").replace_output(buf, output, parsed.root, "gin-" .. kind, parsed.params)
  vim.bo[buf].buflisted, vim.bo[buf].modeline = false, false
  action.setup(buf, M.candidates)
  for _, opener in ipairs({ "edit", "split", "vsplit", "tabedit" }) do
    for _, emojify in ipairs({ false, true }) do
      action.define(
        buf,
        "show:" .. opener .. (emojify and ":emojify" or ""),
        function(target, range)
          for _, row in ipairs(M.candidates(target, range)) do
            require("gin.buffer").open(
              uri.format("gin", parsed.root, {
                diffjump = row.commit,
                difffold = "",
                emojify = emojify and "" or nil,
              }, uri.join({ "show", row.commit })),
              { opener = opener }
            )
          end
        end
      )
    end
  end
  action.alias(buf, "show", "show:edit")
  action.alias(buf, "show:emojify", "show:edit:emojify")
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
      require("gin.command").finish(
        require("gin.git").run(args, { cwd = parsed.root, progress = "both" }),
        {},
        {}
      )
    end)
  end
  local function run(args)
    require("gin.command").finish(
      require("gin.git").run(args, { cwd = parsed.root, progress = "both" }),
      {},
      {}
    )
  end
  for _, method in ipairs({ "ff", "no-ff", "ff-only" }) do
    action.define(buf, "merge:" .. method, function(target, range)
      local row = M.candidates(target, range)[1]
      if row then
        return require("gin.command").execute({
          fargs = { "++worktree=" .. parsed.root, "merge", "--" .. method, row.commit },
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
          local args = { "++worktree=" .. parsed.root, command }
          if mainline ~= "" then
            vim.list_extend(args, { "--mainline", mainline })
          end
          args[#args + 1] = row.commit
          return require("gin.command").execute({
            fargs = args,
            smods = {},
            on_exit = function()
              vim.cmd("silent checktime")
            end,
          })
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
      require("gin.command").finish(
        require("gin.git").run(args, { cwd = parsed.root, progress = "both" }),
        {},
        {}
      )
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
          require("gin.command").finish(
            require("gin.git").run(args, { cwd = parsed.root, progress = "both" }),
            {},
            {}
          )
        end)
      end
    )
  end
  for _, kind in ipairs({ "annotate", "sign" }) do
    for _, force in ipairs({ false, true }) do
      action.define(buf, "tag:" .. kind .. (force and ":force" or ""), function(target, range)
        local row = M.candidates(target, range)[1]
        if not row then
          return
        end
        vim.ui.input({ prompt = "Name: " }, function(name)
          if not name or name == "" then
            return
          end
          local args = { "++worktree=" .. parsed.root, "tag", "--" .. kind }
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
  end
  action.alias(buf, "tag", "tag:annotate")
  local function instant_squash(commit)
    local git = require("gin.git")
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
    require("gin.command").finish(git.run(args, { cwd = parsed.root, progress = "both" }), {}, {})
    vim.cmd("silent checktime")
  end
  for _, instant in ipairs({ false, true }) do
    action.define(buf, instant and "fixup:instant-fixup" or "fixup:fixup", function(target, range)
      local rows = M.candidates(target, range)
      if #rows == 0 then
        return
      end
      assert(#rows == 1, "Fixup requires exactly one commit")
      local commit = rows[1].commit
      local git = require("gin.git")
      local result = git.run(
        { "commit", "--fixup=" .. commit },
        { cwd = parsed.root, progress = "both" }
      )
      require("gin.command").finish(result, {}, {})
      if instant then
        instant_squash(commit)
      end
    end)
  end
  for _, variant in ipairs({ "amend", "reword" }) do
    for _, instant in ipairs({ false, true }) do
      local name = "fixup:" .. (instant and "instant-" or "") .. variant
      action.define(buf, name, function(target, range)
        local rows = M.candidates(target, range)
        if #rows == 0 then
          return
        end
        assert(#rows == 1, "Fixup requires exactly one commit")
        local commit = rows[1].commit
        local args = {
          "++worktree=" .. parsed.root,
          "commit",
          "--fixup=" .. variant .. ":" .. commit,
        }
        if instant then
          args[#args + 1] = "--quiet"
        end
        return require("gin.command").execute({
          fargs = args,
          smods = {},
          on_exit = function(result)
            if instant and result.code == 0 then
              instant_squash(commit)
            end
            vim.cmd("silent checktime")
          end,
        })
      end)
    end
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
        (key == "a" or key == "." or key == "<CR>") and { "n", "x" } or "n",
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
      emojify = options.emojify and "" or nil,
    }, vim.json.encode(args)),
    options
  )
end

function M.command(opts, kind)
  kind = kind or "log"
  local args = require("gin.command").arguments(kind, opts.fargs)
  local options, residue = require("gin.command").parse(
    args,
    { "worktree", "opener", "enc", "encoding", "ff", "fileformat", "emojify" }
  )
  options.bang, options.smods, options.kind = opts.bang, opts.smods, kind
  return M.open(require("gin.worktree").current(options.worktree), residue, options)
end

return M
