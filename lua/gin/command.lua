local M = {}
local post_timer
local post_generation = 0

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
  local separated = false
  for _, arg in ipairs(args) do
    if arg:match("^[%%#]") then
      arg = require("gin.util").expand(arg)
    else
      arg = arg:gsub("^\\([%%#])", "%1")
    end
    local name, value
    if not separated then
      name, value = arg:match("^%+%+([a-zA-Z0-9-]+)=(.*)$")
      if not name then
        name = arg:match("^%+%+([a-zA-Z0-9-]+)")
        value = ""
      end
    end
    separated = separated or arg == "--"
    if name then
      if not vim.tbl_contains(allowed, name) then
        error("Unknown Gin option: ++" .. name, 0)
      end
      assert(options[name] == nil, "Duplicate Gin option: ++" .. name)
      -- The upstream JavaScript option pattern uses a dot without the s flag.
      options[name] = value:gsub("[\r\n].*", ""):gsub("\226\128[\168\169].*", "")
    else
      residue[#residue + 1] = arg
    end
  end
  return options, residue
end

function M.post()
  post_generation = post_generation + 1
  local generation = post_generation
  if post_timer and not post_timer:is_closing() then
    post_timer:stop()
    post_timer:close()
  end
  post_timer = vim.defer_fn(function()
    if generation ~= post_generation then
      return
    end
    post_timer = nil
    vim.api.nvim_exec_autocmds("User", { pattern = "GinCommandPost", modeline = false })
  end, 100)
end

function M.post_pending()
  return post_timer ~= nil
end

local function report_error(message, mods, result)
  if mods.emsg_silent then
    return
  end
  if result then
    message = require("gin.csi").strip(require("gin.stream_text").utf8(result.stderr or ""))
  else
    message = tostring(message):gsub("^[^\n]-:%d+: ", "")
    if message:match("^nvim_%w+%(") then
      message = message:match("^[^\n]-[Ll]ua callback: (.*)\nstack traceback:\n\t") or message
    end
  end
  message = "[gin]: " .. message
  if message:find("\0", 1, true) then
    message = vim.fn.string(message)
  end
  vim.api.nvim_echo({ { message, "ErrorMsg" } }, false, {})
end

---Catch errors only at a user-command boundary, leaving internal APIs strict.
function M.friendly(callback, mods)
  local ok, result = pcall(callback)
  if not ok then
    report_error(result, mods)
    return
  end
  return result
end

---User-command errors are friendly messages; execute retains strict API errors.
function M.command(opts)
  local function report(message, result)
    report_error(message, opts.smods, result)
  end
  local ok, err = pcall(
    M.execute,
    vim.tbl_extend("force", opts, {
      progress = true,
      on_error = report,
    })
  )
  if not ok then
    report(err)
  end
end

function M.execute(opts)
  local wait, raw_args = false, {}
  for _, arg in ipairs(opts.fargs) do
    if arg == "++wait" then
      wait = true
    else
      raw_args[#raw_args + 1] = arg
    end
  end
  local options, args =
    M.parse(raw_args, { "worktree", "processor", "enc", "encoding", "ff", "fileformat" })
  options.wait = wait
  options.eventignore_all = vim.tbl_contains(vim.split(vim.o.eventignore, ","), "all")
  local root = require("gin.worktree").current(options.worktree)
  local completed, failure, cancelled, running
  local function report(message, result)
    if opts.on_error then
      opts.on_error(message, result)
    elseif options.wait then
      failure = message
    elseif not opts.smods.emsg_silent then
      vim.notify(message, vim.log.levels.ERROR)
    end
  end
  local function finish(result, source, progress_error)
    if cancelled then
      return
    end
    completed = result
    if opts.on_exit then
      opts.on_exit(result)
    end
    if progress_error then
      report(tostring(progress_error))
      return
    end
    if result.code ~= 0 then
      report(require("gin.git").error_message(result, source), result)
      return
    end
    local ok, err = pcall(M.finish, result, options, opts.smods)
    if not ok then
      report(tostring(err))
    end
  end
  local env = require("gin.editor").environment()
  local indicator = (opts.progress or not opts.smods.silent)
      and require("gin.indicator").channels(
        opts.stdout_indicator or "echo",
        opts.stderr_indicator or "echo"
      )
    or nil
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
        local closed, err = pcall(indicator.close)
        if not closed then
          finish(result, "git", err)
          return
        end
      end
      if cancelled then
        return
      end
      if result.code ~= 0 or not options.processor or options.processor == "" then
        finish(result, "git")
        return
      end
      local ok, err = pcall(function()
        running = vim.system(
          require("gin.uri").split(options.processor),
          {
            cwd = root,
            env = env,
            stdin = result.stdout,
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
      pcall(indicator.close)
    end
    error(process, 0)
  end
  if options.wait then
    running = process
    -- Process scheduled callbacks and editor RPCs while the caller waits.
    local done = vim.wait(2147483647, function()
      require("gin.editor").process_input()
      return completed ~= nil or failure ~= nil
    end, 10)
    if not done then
      cancelled = true
      if not running:is_closing() then
        running:kill(15)
      end
      if indicator then
        pcall(indicator.close)
      end
      error("Gin wait interrupted", 0)
    end
    if failure then
      error(failure, 0)
    end
    return completed
  end
  return process
end

---Run a synchronous action while retaining completion-event suppression.
function M.run(args, options)
  local finish_options =
    { eventignore_all = vim.tbl_contains(vim.split(vim.o.eventignore, ","), "all") }
  return M.finish(require("gin.git").run(args, options), finish_options, {})
end

function M.finish(result, options, mods)
  local output = (result.stdout or "") .. (result.stderr or "")
  local encoding = options.enc or options.encoding or "utf-8"
  output = require("gin.encoding").decode(output, encoding, { fatal = false })
  local ff = options.ff or options.fileformat
  if ff == "mac" then
    output = output:gsub("\r", "\n")
  elseif ff ~= "unix" then
    output = output:gsub("\r\n", "\n")
  end
  output = require("gin.csi").strip(output)
  if output:find("\0", 1, true) then
    output = vim.fn.string(output)
  end
  if output ~= "" and not mods.silent then
    vim.api.nvim_echo({ { output, "None" } }, false, {})
  end
  if not options.eventignore_all then
    M.post()
  end
  return result
end

return M
