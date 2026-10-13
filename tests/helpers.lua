local M = {}

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

return M
