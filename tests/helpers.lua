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

function M.cleanup(root)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf):find(root, 1, true) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  vim.fn.delete(root, "rf")
end

return M
