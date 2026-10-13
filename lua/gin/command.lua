local M = {}

---Normalize Vim filename placeholders and separate ++ options from Git arguments.
function M.parse(args, allowed)
  local options, residue = {}, {}
  for _, arg in ipairs(args) do
    local name, value = arg:match("^%+%+([^=]+)=(.*)$")
    if not name then
      name = arg:match("^%+%+(.+)$")
      value = true
    end
    if name then
      if not vim.tbl_contains(allowed, name) then
        error("Unknown Gin option: ++" .. name, 0)
      end
      options[name] = value
    else
      if arg:match("^[%%#]") then
        arg = vim.fn.expand(arg)
      else
        arg = arg:gsub("^\\([%%#])", "%1")
      end
      residue[#residue + 1] = arg
    end
  end
  return options, residue
end

function M.post()
  vim.api.nvim_exec_autocmds("User", { pattern = "GinCommandPost", modeline = false })
end

function M.execute(opts)
  local options, args =
    M.parse(opts.fargs, { "wait", "worktree", "enc", "encoding", "ff", "fileformat" })
  local root = require("gin.worktree").current(options.worktree)
  if options.wait then
    local result = require("gin.git").run(args, { cwd = root })
    M.finish(result, options, opts.smods)
    return result
  end
  return require("gin.git").start(
    args,
    { cwd = root },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        if not opts.smods.emsg_silent then
          vim.notify(
            ("git exited %d: %s"):format(result.code, vim.trim(result.stderr or "")),
            vim.log.levels.ERROR
          )
        end
        return
      end
      M.finish(result, options, opts.smods)
    end)
  )
end

function M.finish(result, options, mods)
  local output = (result.stdout or "") .. (result.stderr or "")
  local encoding = options.enc or options.encoding
  if encoding then
    output = vim.fn.iconv(output, encoding, "utf-8")
  end
  local ff = options.ff or options.fileformat
  output = ff == "mac" and output:gsub("\r", "\n") or output:gsub("\r\n", "\n")
  output = output:gsub("\27%[[%d;]*m", "")
  if output ~= "" and not mods.silent then
    vim.api.nvim_echo({ { output:gsub("\n$", ""), "None" } }, true, {})
  end
  M.post()
  return result
end

return M
