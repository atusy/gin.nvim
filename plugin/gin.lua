if vim.g.loaded_gin ~= nil then
  return
end
vim.g.loaded_gin = 1
vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("gin_plugin_internal", { clear = true }),
  pattern = { "GinCommandPost", "GinComponentPost" },
  callback = function() end,
})
for name, prefixes in pairs(require("gin.difffold").presets) do
  vim.g["gin#difffold#prefixes_" .. name] = prefixes
end
vim.api.nvim_create_user_command("Gin", function(opts)
  require("gin.command").command(opts)
end, { nargs = "*", bar = true })
vim.api.nvim_create_user_command("GinBuffer", function(opts)
  require("gin.buffer").command(opts)
end, { nargs = "*", bar = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_buffer", { clear = true }),
  pattern = "gin://*",
  callback = function(event)
    require("gin.buffer").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("FileReadCmd", {
  group = vim.api.nvim_create_augroup("gin_buffer", { clear = false }),
  pattern = "gin://*",
  callback = function(event)
    require("gin.buffer").insert(event.buf, event.match)
  end,
})
