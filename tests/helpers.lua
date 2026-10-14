local M = {}

function M.drain()
  local command = require("gin.command")
  repeat
    assert(
      vim.wait(2000, function()
        return not command.post_pending()
      end, 10),
      "command completion event must finish"
    )
    local done = false
    vim.schedule(function()
      done = true
    end)
    assert(
      vim.wait(1000, function()
        return done
      end, 10),
      "scheduled callbacks must finish"
    )
  -- A queued process callback can schedule a post event during this drain.
  until not command.post_pending()
end

function M.git(cwd, ...)
  local cmd = { "git", "-C", cwd }
  vim.list_extend(cmd, { ... })
  local result = vim
    .system(cmd, {
      text = true,
      env = {
        GIT_CONFIG_NOSYSTEM = "1",
        GIT_CONFIG_GLOBAL = "/dev/null",
        GIT_AUTHOR_NAME = "Gin Test",
        GIT_AUTHOR_EMAIL = "gin@example.invalid",
        GIT_COMMITTER_NAME = "Gin Test",
        GIT_COMMITTER_EMAIL = "gin@example.invalid",
      },
    })
    :wait(10000)
  assert(result.code == 0, result.stderr)
  return result.stdout
end

function M.repo()
  local dir = vim.fn.tempname() .. " gin test"
  vim.fn.mkdir(dir, "p")
  M.git(dir, "init", "--initial-branch=main")
  return dir
end

function M.cleanup(root)
  M.drain()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.uri_decode(vim.api.nvim_buf_get_name(buf)):find(root, 1, true)
      or vim.b[buf].gin_worktree == vim.uv.fs_realpath(root)
    then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  vim.fn.delete(root, "rf")
end

-- User commands report errors without throwing; direct APIs still throw.
function M.command_error(callback, pattern)
  local echo, messages = vim.api.nvim_echo, {}
  vim.api.nvim_echo = function(chunks, history)
    if chunks[1][2] == "ErrorMsg" then
      messages[#messages + 1] = chunks[1][1]
      MiniTest.expect.equality(history, false)
    end
  end
  local ok, err = pcall(callback)
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(#messages, 1)
  MiniTest.expect.equality(messages[1]:match("^%[gin%]: ") ~= nil, true)
  if pattern then
    MiniTest.expect.equality(messages[1]:find(pattern) ~= nil, true)
  end
end

return M
