local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.writefile({ "base" }, root .. "/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      for _, value in ipairs({ "older", "newer" }) do
        vim.fn.writefile({ value }, root .. "/file")
        H.git(root, "add", "file")
        H.git(root, "stash", "push", "-m", value)
      end
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
T["stash apply index restores selected content and retains both stashes"] = function()
  vim.cmd.GinStash()
  MiniTest.expect.equality(vim.bo.filetype, "gin-stash")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "apply:index", { 2, 2 })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "older" })
  MiniTest.expect.equality(H.git(root, "show", ":file"), "older\n")
  MiniTest.expect.equality(#vim.b.gin_stashes, 2)
end
T["stash pop restores only the selected stash and removes it"] = function()
  vim.cmd.GinStash()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "pop", { 2, 2 })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "older" })
  MiniTest.expect.equality(#vim.b.gin_stashes, 1)
  MiniTest.expect.equality(H.git(root, "stash", "list", "--format=%s"), "On main: newer\n")
end
T["stash drop acts on first selected entry without index-shift deletion"] = function()
  vim.cmd.GinStash()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "drop", { 1, 2 })
  MiniTest.expect.equality(H.git(root, "stash", "list", "--format=%s"), "On main: older\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "base" })
end
T["failed stash pop retains the stash and exposes conflict state"] = function()
  vim.fn.writefile({ "conflicting base" }, root .. "/file")
  H.git(root, "commit", "-am", "conflicting change")
  local before = H.git(root, "stash", "list", "--format=%H")
  vim.cmd.GinStash()
  MiniTest.expect.error(function()
    require("gin.action").call(vim.api.nvim_get_current_buf(), "pop", { 1, 1 })
  end, "git exited")
  MiniTest.expect.equality(H.git(root, "stash", "list", "--format=%H"), before)
  MiniTest.expect.equality(H.git(root, "ls-files", "--unmerged") ~= "", true)
end

T["stash emojify retains pop targets across reload"] = function()
  vim.fn.writefile({ "emoji content" }, root .. "/file")
  H.git(root, "stash", "push", "-m", ":sparkles: stash")
  local commit = vim.trim(H.git(root, "rev-parse", "stash"))
  vim.cmd("GinStash ++emojify")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.b.gin_stashes[1], { stash = "stash@{0}", commit = commit })
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]:find("✨ stash", 1, true) ~= nil,
    true
  )
  require("gin.action").call(vim.api.nvim_get_current_buf(), "pop", { 1, 1 })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "emoji content" })
  MiniTest.expect.equality(#vim.b.gin_stashes, 2)
  MiniTest.expect.equality(
    H.git(root, "stash", "list", "--format=%s"),
    "On main: newer\nOn main: older\n"
  )
end

T["stash decoding options survive reload and preserve pop targets"] = function()
  vim.fn.writefile({ "encoded content" }, root .. "/file")
  H.git(root, "stash", "push", "-m", "café")
  vim.cmd("GinStash ++encoding=latin1 ++fileformat=unix --encoding=ISO-8859-1")
  vim.cmd.edit()
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]:find("café", 1, true) ~= nil,
    true
  )
  MiniTest.expect.equality(vim.bo.fileencoding, "latin1")
  MiniTest.expect.equality(vim.bo.fileformat, "unix")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "pop", { 1, 1 })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "encoded content" })
  MiniTest.expect.equality(#vim.b.gin_stashes, 2)
end
return T
