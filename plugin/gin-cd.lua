if vim.g.loaded_gin_cd ~= nil then
  return
end
vim.g.loaded_gin_cd = 1
for name, command in pairs({ GinCd = "cd", GinLcd = "lcd", GinTcd = "tcd" }) do
  vim.api.nvim_create_user_command(name, function()
    local ok, root = pcall(function()
      local worktree = require("gin.worktree").current()
      vim.cmd[command](vim.fn.fnameescape(worktree))
      return worktree
    end)
    if not ok then
      vim.api.nvim_echo({ { "[gin] no git repository found", "WarningMsg" } }, false, {})
      return
    end
    vim.api.nvim_echo({ { ('[gin] %s on "%s"'):format(command, root), "None" } }, false, {})
  end, { nargs = 0, bar = true })
end
