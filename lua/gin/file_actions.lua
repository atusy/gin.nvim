local action = require("gin.action")
local M = {}

---Install file actions whose candidates contain repository-relative paths.
function M.setup(buf, gather)
  local function define_git(name, args)
    action.define(buf, name, function(target, range)
      local entries = gather(target, range)
      if #entries == 0 then
        return
      end
      local command = vim.list_extend(vim.deepcopy(args), { "--" })
      for _, entry in ipairs(entries) do
        command[#command + 1] = entry.path
      end
      local result = require("gin.git").run(command, {
        cwd = vim.b[target].gin_worktree,
        progress = "both",
      })
      require("gin.command").finish(result, {}, {})
    end)
  end
  define_git("stash", { "stash", "push", "--all" })
  define_git("stash:keep-index", { "stash", "push", "--all", "--keep-index" })
  define_git("add", { "add", "--ignore-errors", "--force" })
  define_git("add:intent-to-add", { "add", "--ignore-errors", "--force", "--intent-to-add" })
  define_git("rm", { "rm", "--quiet", "--ignore-unmatch", "--cached" })
  define_git("rm:force", { "rm", "--quiet", "--ignore-unmatch", "--cached", "--force" })
  for name, flags in pairs({
    restore = { "--ignore-unmerged" },
    ["restore:staged"] = { "--ignore-unmerged", "--staged" },
    ["restore:ours"] = { "--ignore-unmerged", "--ours" },
    ["restore:theirs"] = { "--ignore-unmerged", "--theirs" },
    ["restore:conflict:merge"] = { "--conflict=merge" },
    ["restore:conflict:diff3"] = { "--conflict=diff3" },
  }) do
    define_git(name, vim.list_extend({ "restore", "--quiet" }, flags))
  end
  for _, source in ipairs({ "local", "cached", "HEAD" }) do
    for _, opener in ipairs({ "edit", "split", "vsplit", "tabedit" }) do
      action.define(buf, "edit:" .. source .. ":" .. opener, function(target, range)
        local root = vim.b[target].gin_worktree
        local entries = gather(target, range)
        for _, entry in ipairs(entries) do
          if source == "local" then
            require("gin.buffer").open(root .. "/" .. entry.path, { opener = opener })
          else
            local args = { "++opener=" .. opener }
            if source == "HEAD" then
              args[#args + 1] = "HEAD"
            end
            -- Absolute paths cannot be mistaken for Vim filename placeholders.
            args[#args + 1] = root .. "/" .. entry.path
            require("gin.edit").command({ fargs = args, smods = {} })
          end
        end
      end)
    end
    action.alias(buf, "edit:" .. source, "edit:" .. source .. ":edit")
  end
  action.alias(buf, "edit", "edit:local")
  for _, source in ipairs({ "local", "cached", "HEAD", "smart" }) do
    for _, opener in ipairs({ "edit", "split", "vsplit", "tabedit" }) do
      action.define(buf, "diff:" .. source .. ":" .. opener, function(target, range)
        local root = vim.b[target].gin_worktree
        local entries = gather(target, range)
        for _, entry in ipairs(entries) do
          local cached = source == "cached" or (source == "smart" and entry.xy:sub(1, 1) ~= " ")
          local args = { "++opener=" .. opener }
          if cached then
            args[#args + 1] = "--cached"
          elseif source == "HEAD" then
            args[#args + 1] = "HEAD"
          end
          vim.list_extend(args, { "--", root .. "/" .. entry.path })
          require("gin.diff").command({ fargs = args, smods = {} })
        end
      end)
    end
    action.alias(buf, "diff:" .. source, "diff:" .. source .. ":edit")
  end
  action.alias(buf, "diff", "diff:smart")
  for _, variant in ipairs({ "both", "head", "worktree" }) do
    action.define(buf, "patch:" .. variant, function(target, range)
      local root = vim.b[target].gin_worktree
      local entries = gather(target, range)
      for _, entry in ipairs(entries) do
        local args = { "++opener=tabedit" }
        if variant == "worktree" then
          args[#args + 1] = "++no-head"
        elseif variant == "head" then
          args[#args + 1] = "++no-worktree"
        end
        args[#args + 1] = root .. "/" .. entry.path
        require("gin.patch").command({ fargs = args, smods = {} })
      end
    end)
  end
  action.alias(buf, "patch", "patch:both")
  for _, variant in ipairs({ "both", "theirs", "ours" }) do
    action.define(buf, "chaperon:" .. variant, function(target, range)
      local root = vim.b[target].gin_worktree
      local entries = gather(target, range)
      for _, entry in ipairs(entries) do
        local args = { "++opener=tabedit" }
        if variant == "theirs" then
          args[#args + 1] = "++no-ours"
        elseif variant == "ours" then
          args[#args + 1] = "++no-theirs"
        end
        args[#args + 1] = root .. "/" .. entry.path
        require("gin.chaperon").command({ fargs = args, smods = {} })
      end
    end)
  end
  action.alias(buf, "chaperon", "chaperon:both")
  for _, spec in ipairs({ { "yank:path", "path" }, { "yank:path:orig", "orig_path" } }) do
    action.define(buf, spec[1], function(target, range)
      local values = {}
      for _, entry in ipairs(gather(target, range)) do
        local path = entry[spec[2]]
        values[#values + 1] = path and vim.b[target].gin_worktree .. "/" .. path or ""
      end
      vim.fn.setreg(vim.v.register, table.concat(values, "\n"))
    end)
  end
end

return M
