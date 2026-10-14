local M = {}
local active, generation = 0, 0
local saved
local serial = 0

function M.open(options)
  if active == 0 then
    saved = { more = vim.o.more, cmdheight = vim.o.cmdheight }
    generation = generation + 1
  end
  if not (options or {}).preserve_more then
    vim.o.more = false
  end
  active = active + 1
  local closed = false
  local function write_lines(lines)
    if closed or #lines == 0 then
      return
    end
    vim.o.cmdheight = math.max(vim.o.cmdheight, math.min(#lines, math.max(1, vim.o.lines - 1)))
    vim.cmd.redraw()
    vim.api.nvim_echo({ { table.concat(lines, "\n"), "None" } }, false, {})
    generation = generation + 1
    local version = generation
    vim.defer_fn(function()
      if saved and version == generation then
        vim.o.cmdheight = saved.cmdheight
      end
    end, 500)
  end
  local function stream()
    local decode = require("gin.stream_text").decoder()
    return vim.schedule_wrap(function(_, data)
      if closed then
        return
      end
      local text = vim.trim(decode(data))
      if text == "" then
        return
      end
      write_lines(vim.split(text, "\n", { plain = true }))
    end)
  end
  return {
    write = stream(),
    write_stderr = stream(),
    write_lines = write_lines,
    close = function()
      if closed then
        return
      end
      closed = true
      active = active - 1
      if active == 0 then
        generation = generation + 1
        vim.o.more, vim.o.cmdheight = saved.more, saved.cmdheight
        saved = nil
      end
    end,
  }
end

---Create one output channel for a built-in or Vimscript indicator backend.
function M.stream(name)
  if name == "null" then
    return { write = function() end, close = function() end }
  elseif name == "echo" then
    local handle = M.open()
    return { write = handle.write, close = handle.close }
  end
  assert(type(name) == "string", "indicator name must be a string")
  serial = serial + 1
  local id = "gin-indicator-" .. serial
  local function call(method, ...)
    return vim.fn["gin#indicator#" .. name .. "#" .. method](id, ...)
  end
  local opened, err = pcall(call, "open")
  if not opened then
    pcall(call, "close")
    error(err, 0)
  end
  local decode = require("gin.stream_text").decoder()
  local failure, closed
  return {
    write = vim.schedule_wrap(function(stream_error, data)
      if closed or failure then
        return
      end
      if stream_error then
        failure = stream_error
        return
      end
      local text, emitted = decode(data)
      if emitted then
        local ok, message = pcall(call, "write", vim.split(vim.trim(text), "\n", { plain = true }))
        if not ok then
          failure = message
        end
      end
    end),
    close = function()
      if closed then
        return
      end
      closed = true
      local ok, message = pcall(call, "close")
      if failure or not ok then
        error(failure or message, 0)
      end
    end,
  }
end

---Open paired output channels and always close both, even after a backend error.
function M.channels(stdout_name, stderr_name)
  local stdout = M.stream(stdout_name)
  local ok, stderr = pcall(M.stream, stderr_name)
  if not ok then
    pcall(stdout.close)
    error(stderr, 0)
  end
  return {
    write = stdout.write,
    write_stderr = stderr.write,
    close = function()
      local first_ok, first_error = pcall(stdout.close)
      local second_ok, second_error = pcall(stderr.close)
      if not first_ok or not second_ok then
        error(not first_ok and first_error or second_error, 0)
      end
    end,
  }
end

return M
