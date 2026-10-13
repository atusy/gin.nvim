local M = {}

function M.arguments(kind, args)
  local function configured(suffix)
    local name = "gin_" .. kind .. "_" .. suffix .. "_args"
    local value = vim.g[name]
    if value == nil then
      return {}
    end
    local message = "g:" .. name .. " must be a list of strings"
    assert(type(value) == "table" and vim.islist(value), message)
    for _, arg in ipairs(value) do
      assert(type(arg) == "string", message)
    end
    return value
  end
  local defaults, persistent = configured("default"), configured("persistent")
  return vim.list_extend(vim.deepcopy(persistent), #args == 0 and defaults or args)
end

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
        if arg:match("^gin[%w]*://") then
          local parsed = require("gin.uri").parse(arg)
          local path
          if parsed.scheme == "ginedit" then
            path = parsed.fragment
          elseif parsed.scheme == "gindiff" and parsed.fragment then
            path = vim.json.decode(parsed.fragment)[1]
          elseif parsed.scheme == "ginlog" and parsed.fragment then
            -- Log URIs store the full argv; paths follow the explicit separator.
            local args = vim.json.decode(parsed.fragment)
            for i, value in ipairs(args) do
              if value == "--" then
                path = args[i + 1]
                break
              end
            end
          end
          if path then
            local absolute = path:match("^/") or path:match("^%a:[/\\]")
            arg = vim.fs.normalize(absolute and path or (parsed.root .. "/" .. path))
          end
        end
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
    M.parse(opts.fargs, { "wait", "worktree", "processor", "enc", "encoding", "ff", "fileformat" })
  local root = require("gin.worktree").current(options.worktree)
  if options.wait then
    local result = require("gin.git").run(args, { cwd = root, processor = options.processor })
    M.finish(result, options, opts.smods)
    return result
  end
  local function report(message)
    if not opts.smods.emsg_silent then
      vim.notify(message, vim.log.levels.ERROR)
    end
  end
  local function finish(result, source)
    if opts.on_exit then
      opts.on_exit(result)
    end
    if result.code ~= 0 then
      report(("%s exited %d: %s"):format(source, result.code, vim.trim(result.stderr or "")))
      return
    end
    M.finish(result, options, opts.smods)
  end
  local env = require("gin.editor").environment()
  local indicator = not opts.smods.silent and require("gin.indicator").open() or nil
  local ok, process = pcall(
    require("gin.git").start,
    args,
    {
      cwd = root,
      env = env,
      timeout = false,
      on_stdout = indicator and indicator.write,
      on_stderr = indicator and indicator.write_stderr,
    },
    vim.schedule_wrap(function(result)
      if indicator then
        indicator.close()
      end
      if result.code ~= 0 or not options.processor or options.processor == "" then
        finish(result, "git")
        return
      end
      local ok, err = pcall(function()
        vim.system(
          require("gin.uri").split(options.processor),
          {
            cwd = root,
            stdin = result.stdout,
            timeout = 30000,
          },
          vim.schedule_wrap(function(processed)
            finish(processed, "processor")
          end)
        )
      end)
      if not ok then
        report("processor failed: " .. tostring(err))
      end
    end)
  )
  if not ok then
    if indicator then
      indicator.close()
    end
    error(process, 0)
  end
  return process
end

function M.finish(result, options, mods)
  local output = (result.stdout or "") .. (result.stderr or "")
  local encoding = options.enc or options.encoding
  if encoding then
    output = vim.fn.iconv(output, encoding, "utf-8")
  end
  local ff = options.ff or options.fileformat
  if ff == "mac" then
    output = output:gsub("\r", "\n")
  elseif ff ~= "unix" then
    output = output:gsub("\r\n", "\n")
  end
  output = output:gsub("\27%[[%d;]*m", "")
  if output ~= "" and not mods.silent then
    vim.api.nvim_echo({ { output:gsub("\n$", ""), "None" } }, true, {})
  end
  M.post()
  return result
end

return M
