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
  local result = require("gin.git").run(args, { cwd = root })
  local output = (result.stdout or "") .. (result.stderr or "")
  local encoding = options.enc or options.encoding
  if encoding then
    output = vim.fn.iconv(output, encoding, "utf-8")
  end
  local ff = options.ff or options.fileformat
  output = ff == "mac" and output:gsub("\r", "\n") or output:gsub("\r\n", "\n")
  output = output:gsub("\27%[[%d;]*m", "")
  if output ~= "" and not opts.smods.silent then
    vim.api.nvim_echo({ { output:gsub("\n$", ""), "None" } }, true, {})
  end
  M.post()
  return result
end

return M
