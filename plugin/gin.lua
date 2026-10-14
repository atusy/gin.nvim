if vim.g.loaded_gin then
  return
end
vim.g.loaded_gin = 1
for name, prefixes in pairs(require("gin.difffold").presets) do
  vim.g["gin#difffold#prefixes_" .. name] = prefixes
end
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
end, { nargs = "*", bar = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_buffer", { clear = true }),
  pattern = "gin://*",
  callback = function(event)
    require("gin.buffer").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_user_command("GinStatus", function(opts)
  require("gin.status").command(opts)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_status", { clear = true }),
  pattern = "ginstatus://*",
  callback = function(event)
    require("gin.status").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_user_command("GinEdit", function(opts)
  require("gin.edit").command(opts)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_edit", { clear = true }),
  pattern = "ginedit://*",
  callback = function(event)
    require("gin.edit").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("BufWriteCmd", {
  group = vim.api.nvim_create_augroup("gin_edit", { clear = false }),
  pattern = "ginedit://*",
  nested = true,
  callback = function(event)
    require("gin.edit").write(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("FileReadCmd", {
  group = vim.api.nvim_create_augroup("gin_edit", { clear = false }),
  pattern = "ginedit://*",
  callback = function(event)
    require("gin.edit").insert(event.buf, event.match)
  end,
})
vim.api.nvim_create_user_command("GinDiff", function(opts)
  require("gin.diff").command(opts)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_diff", { clear = true }),
  pattern = "gindiff://*",
  callback = function(event)
    require("gin.diff").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_user_command("GinPatch", function(opts)
  require("gin.patch").command(opts)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_user_command("GinChaperon", function(opts)
  require("gin.chaperon").command(opts)
end, { nargs = "*", bar = true, bang = true })

for scheme, module in pairs({ gin = "buffer", gindiff = "diff" }) do
  vim.api.nvim_create_autocmd("FileReadCmd", {
    group = vim.api.nvim_create_augroup("gin_" .. module, { clear = false }),
    pattern = scheme .. "://*",
    callback = function(event)
      if module == "diff" then
        require("gin.buffer").insert_output(
          event.buf,
          event.match,
          require("gin.diff").output(event.match, "both")
        )
      else
        require("gin.buffer").insert(event.buf, event.match)
      end
    end,
  })
end
vim.api.nvim_create_user_command("GinBranch", function(opts)
  require("gin.branch").command(opts)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_branch", { clear = true }),
  pattern = "ginbranch://*",
  callback = function(event)
    require("gin.branch").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_user_command("GinTag", function(opts)
  require("gin.tag").command(opts)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_tag", { clear = true }),
  pattern = "gintag://*",
  callback = function(event)
    require("gin.tag").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("FileReadCmd", {
  group = vim.api.nvim_create_augroup("gin_tag", { clear = false }),
  pattern = "gintag://*",
  callback = function(event)
    require("gin.tag").insert(event.buf, event.match)
  end,
})
vim.api.nvim_create_user_command("GinLog", function(opts)
  require("gin.log").command(opts)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_log", { clear = true }),
  pattern = "ginlog://*",
  callback = function(event)
    require("gin.log").read(event.buf, event.match)
  end,
})

vim.api.nvim_create_user_command("GinReflog", function(opts)
  require("gin.log").command(opts, "reflog")
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_reflog", { clear = true }),
  pattern = "ginreflog://*",
  callback = function(event)
    require("gin.log").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_user_command("GinStash", function(opts)
  require("gin.stash").command(opts)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_stash", { clear = true }),
  pattern = "ginstash://*",
  callback = function(event)
    require("gin.stash").read(event.buf, event.match)
  end,
})
for scheme, module in pairs({ ginlog = "log", ginreflog = "log", ginstash = "stash" }) do
  vim.api.nvim_create_autocmd("FileReadCmd", {
    group = vim.api.nvim_create_augroup("gin_" .. scheme:sub(4), { clear = false }),
    pattern = scheme .. "://*",
    callback = function(event)
      require("gin." .. module).insert(event.buf, event.match)
    end,
  })
end
vim.api.nvim_create_user_command("GinBrowse", function(opts)
  require("gin.browse").command(opts)
end, { nargs = "*", bar = true, range = 0 })
vim.api.nvim_create_user_command("GinBlame", function(opts)
  require("gin.blame").command(opts)
end, { nargs = "*", bar = true, bang = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_blame", { clear = true }),
  pattern = "ginblame://*",
  callback = function(event)
    require("gin.blame").read(event.buf, event.match)
  end,
})
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("gin_blame", { clear = false }),
  pattern = "ginblamenav://*",
  callback = function(event)
    require("gin.blame").read_nav(event.buf)
  end,
})
require("gin.blame").highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("gin_blame", { clear = false }),
  callback = function()
    require("gin.blame").highlights()
  end,
})
