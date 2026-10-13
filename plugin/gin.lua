if vim.g.loaded_gin then
  return
end
vim.g.loaded_gin = 1
vim.api.nvim_create_user_command("Gin", function(opts)
  require("gin.command").execute(opts)
end, { nargs = "*", bar = true })
for name, command in pairs({ GinCd = "cd", GinLcd = "lcd", GinTcd = "tcd" }) do
  vim.api.nvim_create_user_command(name, function()
    local root = require("gin.worktree").current()
    vim.cmd[command](vim.fn.fnameescape(root))
    vim.api.nvim_echo({ { ('[gin] %s on "%s"'):format(command, root), "None" } }, false, {})
  end, { nargs = 0, bar = true })
end
vim.api.nvim_create_user_command("GinBuffer", function(opts)
  require("gin.buffer").command(opts)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_buffer", { clear = true }),
  pattern = "gin://*",
  callback = function(event)
    require("gin.buffer").read(event.buf, event.match)
  end,
})
