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
  H.drain()
  MiniTest.expect.equality(#vim.b.gin_stashes, 2)
end
T["stash command groups flags without accepting positional arguments"] = function()
  local stashes = H.git(root, "stash", "list", "--format=%H")
  vim.cmd("GinStash --format=%s -n1 --max-count=2 -n1")
  for _ = 1, 2 do
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(0, 0, -1, false),
      { "On main: newer", "On main: older" }
    )
    MiniTest.expect.equality(vim.b.gin_stashes[2].stash, "stash@{1}")
    vim.cmd.edit()
  end
  local name = vim.api.nvim_buf_get_name(0)
  for _, arg in ipairs({ "HEAD", "-- file", "-- --max-count=1" }) do
    MiniTest.expect.error(function()
      vim.cmd("GinStash " .. arg)
    end, "GinStash does not accept positional arguments")
    MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), name)
  end
  require("gin.action").call(vim.api.nvim_get_current_buf(), "apply:index", { 2, 2 })
  H.drain()
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "older" })
  MiniTest.expect.equality(H.git(root, "show", ":file"), "older\n")
  MiniTest.expect.equality(H.git(root, "stash", "list", "--format=%H"), stashes)
end
T["legacy stash URIs restore filters and selected stash references"] = function()
  local stashes = H.git(root, "stash", "list", "--format=%H")
  local name = "ginstash://" .. root .. ";format=%25s&skip=1&max-count=2&max-count=1"
  require("gin.buffer").open(name, {})
  for _ = 1, 2 do
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "On main: older" })
    MiniTest.expect.equality(vim.b.gin_stashes[1].stash, "stash@{1}")
    vim.cmd.edit()
  end
  vim.cmd.enew()
  vim.bo.filetype = "lua"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
  vim.api.nvim_cmd({ cmd = "read", args = { name }, range = { 1 }, magic = { file = false } }, {})
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "before", "On main: older", "after" }
  )
  MiniTest.expect.equality(vim.bo.filetype, "lua")
  require("gin.buffer").open(name, { bang = true })
  require("gin.action").call(vim.api.nvim_get_current_buf(), "apply:index", { 1, 1 })
  H.drain()
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "older" })
  MiniTest.expect.equality(H.git(root, "show", ":file"), "older\n")
  MiniTest.expect.equality(H.git(root, "stash", "list", "--format=%H"), stashes)
end
T["stash echo exposes the selected reflog reference and index"] = function()
  vim.cmd.GinStash()
  local echo, output = vim.api.nvim_echo, nil
  vim.api.nvim_echo = function(chunks)
    output = chunks[1][1]
  end
  local ok, err =
    pcall(require("gin.action").call, vim.api.nvim_get_current_buf(), "echo", { 2, 2 })
  vim.api.nvim_echo = echo
  assert(ok, err)
  MiniTest.expect.equality(vim.json.decode(output), {
    { stashRef = "stash@{1}", index = 1, commit = "stash@{1}" },
  })
end
T["stash show opens the selected reflog reference"] = function()
  for _, value in ipairs({ "selected", "unselected" }) do
    vim.fn.writefile({ value }, root .. "/file")
    H.git(root, "stash", "push", "-m", value)
  end
  vim.cmd.GinStash()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "show", { 2, 2 })
  local parsed = require("gin.uri").parse(vim.api.nvim_buf_get_name(0))
  MiniTest.expect.equality(parsed.params.diffjump, "stash@{1}")
  MiniTest.expect.equality(require("gin.uri").split(parsed.fragment), { "show", "stash@{1}" })
  local row
  for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line == "++selected" then
      row = i
      break
    end
  end
  assert(row, "selected stash content must appear in the combined diff")
end
T["stash pop restores only the selected stash and removes it"] = function()
  vim.cmd.GinStash()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "pop", { 2, 2 })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "older" })
  H.drain()
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
  H.drain()
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
  H.drain()
  MiniTest.expect.equality(#vim.b.gin_stashes, 2)
end
T["custom stash formats preserve filtered pop targets across reload"] = function()
  vim.cmd("GinStash --format=%s --grep=older")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "On main: older" })
  require("gin.action").call(vim.api.nvim_get_current_buf(), "pop:index", { 1, 1 })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "older" })
  MiniTest.expect.equality(H.git(root, "show", ":file"), "older\n")
  MiniTest.expect.equality(H.git(root, "stash", "list", "--format=%s"), "On main: newer\n")
end
T["multiline stash formats retain metadata through embedded NUL bytes"] = function()
  vim.cmd("GinStash --format=%gd%x00%n%s")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
    "stash@{0}\0",
    "On main: newer",
    "stash@{1}\0",
    "On main: older",
  })
  local buf = vim.api.nvim_get_current_buf()
  require("gin.action").call(buf, "yank:stash", { 3, 4 })
  MiniTest.expect.equality(vim.fn.getreg('"'), "stash@{1}")
  require("gin.action").call(buf, "pop:index", { 4, 4 })
  MiniTest.expect.equality(H.git(root, "show", ":file"), "older\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "older" })
  MiniTest.expect.equality(H.git(root, "stash", "list", "--format=%s"), "On main: newer\n")
end
return T
