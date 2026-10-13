local M = {}

---Run Git with literal argv and preserve its output and exit status.
---@param args string[]
---@param opts? {cwd?: string, env?: table, stdin?: string|boolean, timeout?: integer|false, check?: boolean, on_stdout?: function, on_stderr?: function}
---@param callback? fun(result: vim.SystemCompleted)
---@return vim.SystemObj
function M.start(args, opts, callback)
  opts = opts or {}
  local timeout = opts.timeout
  if timeout == nil then
    timeout = 30000
  elseif timeout == false then
    timeout = nil
  end
  local cmd = { "git", "--no-pager", "--literal-pathspecs", "--no-optional-locks" }
  vim.list_extend(cmd, args)
  local streams = {}
  local function listen(name)
    local listener = opts["on_" .. name]
    if not listener then
      return nil
    end
    streams[name] = {}
    return function(err, data)
      if data then
        streams[name][#streams[name] + 1] = data
      end
      listener(err, data)
    end
  end
  return vim.system(cmd, {
    cwd = opts.cwd,
    env = opts.env,
    stdin = opts.stdin,
    timeout = timeout,
    stdout = listen("stdout"),
    stderr = listen("stderr"),
  }, function(result)
    for name, chunks in pairs(streams) do
      result[name] = table.concat(chunks)
    end
    if callback then
      callback(result)
    end
  end)
end

local function with_progress(args, opts)
  local indicator = require("gin.indicator").open()
  local ok, result = pcall(function()
    local completed
    local stream_opts = vim.tbl_extend("force", opts, { on_stderr = indicator.write_stderr })
    local process = M.start(
      args,
      stream_opts,
      vim.schedule_wrap(function(value)
        completed = value
      end)
    )
    -- Scheduled progress must run before completion; SystemObj:wait only pumps fast events.
    if not vim.wait(2147483647, function()
      return completed ~= nil
    end, 10) then
      if not process:is_closing() then
        process:kill(15)
      end
      error("Gin read interrupted", 0)
    end
    return completed
  end)
  indicator.close()
  if not ok then
    error(result, 0)
  end
  return result
end

function M.run(args, opts)
  opts = opts or {}
  local result = opts.progress and with_progress(args, opts) or M.start(args, opts):wait()
  if opts.check ~= false and result.code ~= 0 then
    error(("git exited %d: %s"):format(result.code, vim.trim(result.stderr or "")), 0)
  end
  if result.code == 0 and opts.processor and #opts.processor > 0 then
    local processor = type(opts.processor) == "string" and require("gin.uri").split(opts.processor)
      or opts.processor
    result = vim
      .system(processor, {
        cwd = opts.cwd,
        env = opts.env,
        stdin = result.stdout,
        timeout = opts.timeout or 30000,
      })
      :wait()
    if opts.check ~= false and result.code ~= 0 then
      error(("processor exited %d: %s"):format(result.code, vim.trim(result.stderr or "")), 0)
    end
  end
  return result
end

return M
