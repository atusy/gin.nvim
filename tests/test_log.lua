local H = require("tests.helpers")
local root, first, second
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      H.git(root, "config", "user.name", "Gin Test")
      H.git(root, "config", "user.email", "gin@example.invalid")
      H.git(root, "config", "core.editor", "true")
      vim.fn.writefile({ "first" }, root .. "/one")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "first change")
      first = vim.trim(H.git(root, "rev-parse", "HEAD"))
      vim.fn.writefile({ "second" }, root .. "/two")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "second change")
      second = vim.trim(H.git(root, "rev-parse", "HEAD"))
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd("silent! tabonly!")
      vim.cmd("silent! only!")
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
T["log preserves history order and yanks selected commits"] = function()
  vim.cmd("GinLog --oneline")
  local entries = require("gin.log").candidates(vim.api.nvim_get_current_buf(), { 1, 2 })
  MiniTest.expect.equality(#entries, 2)
  MiniTest.expect.equality(second:sub(1, #entries[1].commit), entries[1].commit)
  vim.api.nvim_feedkeys('"ayy', "mx", false)
  MiniTest.expect.equality(vim.fn.getreg("a"), entries[1].commit)
end
T["log revision and path filters survive reload"] = function()
  vim.cmd("GinLog --oneline HEAD -- one")
  vim.cmd.edit()
  local entries = require("gin.log").candidates(vim.api.nvim_get_current_buf(), { 1, 99 })
  MiniTest.expect.equality(#entries, 1)
  MiniTest.expect.equality(first:sub(1, #entries[1].commit), entries[1].commit)
end
T["log show opens the selected commit diff"] = function()
  vim.cmd("GinLog --oneline")
  vim.api.nvim_feedkeys("\r", "mx", false)
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("+second", 1, true) ~= nil, true)
end
T["default and graph formats identify commit headers"] = function()
  for _, command in ipairs({ "GinLog", "GinLog --graph --oneline" }) do
    vim.cmd(command)
    local rows = require("gin.log").candidates(vim.api.nvim_get_current_buf(), { 1, 999 })
    MiniTest.expect.equality(#rows, 2)
    MiniTest.expect.equality(second:sub(1, #rows[1].commit), rows[1].commit)
    MiniTest.expect.equality(first:sub(1, #rows[2].commit), rows[2].commit)
  end
end
T["branch log action opens the selected branch history in a split"] = function()
  H.git(root, "branch", "older", first)
  vim.cmd("GinBranch older")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "log:split", { 1, 1 })
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), 2)
  MiniTest.expect.equality(vim.bo.filetype, "gin-log")
  local rows = require("gin.log").candidates(vim.api.nvim_get_current_buf(), { 1, 999 })
  MiniTest.expect.equality(rows, { { commit = first } })
end
T["cherry-pick applies the selected commit to the current branch"] = function()
  H.git(root, "checkout", "-b", "target", first)
  vim.cmd("GinLog --oneline main")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "cherry-pick", { 1, 1 })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/two"), { "second" })
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^"), first .. "\n")
  MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
end
T["revert creates an inverse commit while preserving history"] = function()
  vim.cmd("GinLog --oneline")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "revert", { 1, 1 })
  MiniTest.expect.equality(vim.fn.filereadable(root .. "/two"), 0)
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^"), second .. "\n")
  MiniTest.expect.equality(
    H.git(root, "rev-parse", "HEAD^{tree}"),
    H.git(root, "rev-parse", first .. "^{tree}")
  )
end
T["revert mainline one removes the merged branch changes"] = function()
  H.git(root, "checkout", "-b", "side", first)
  vim.fn.writefile({ "side" }, root .. "/side")
  H.git(root, "add", "side")
  H.git(root, "commit", "-m", "side change")
  H.git(root, "checkout", "main")
  H.git(root, "merge", "--no-ff", "--no-edit", "side")
  vim.cmd("GinLog --oneline")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "revert:1", { 1, 1 })
  MiniTest.expect.equality(vim.fn.filereadable(root .. "/side"), 0)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/two"), { "second" })
end
for _, spec in ipairs({
  { action = "reset", indexed = false, present = true },
  { action = "reset:soft", indexed = true, present = true },
  { action = "reset:hard", indexed = false, present = false },
  { action = "reset:merge", indexed = false, present = false },
  { action = "reset:keep", indexed = false, present = false },
}) do
  T[spec.action .. " changes HEAD, index and worktree according to its mode"] = function()
    vim.cmd("GinLog --oneline")
    require("gin.action").call(vim.api.nvim_get_current_buf(), spec.action, { 2, 2 })
    MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), first .. "\n")
    MiniTest.expect.equality(H.git(root, "ls-files", "--", "two") ~= "", spec.indexed)
    MiniTest.expect.equality(vim.fn.filereadable(root .. "/two") == 1, spec.present)
    MiniTest.expect.equality(vim.fn.readfile(root .. "/one"), { "first" })
  end
end
T["reset keep rejects overwriting an uncommitted change"] = function()
  vim.fn.writefile({ "local change" }, root .. "/two")
  vim.cmd("GinLog --oneline")
  MiniTest.expect.error(function()
    require("gin.action").call(vim.api.nvim_get_current_buf(), "reset:keep", { 2, 2 })
  end, "git exited")
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), second .. "\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/two"), { "local change" })
end
local function tag_action(action, value)
  local original, callback = vim.ui.input, nil
  vim.ui.input = function(_, done)
    callback = done
  end
  local ok, err =
    pcall(require("gin.action").call, vim.api.nvim_get_current_buf(), action, { 2, 2 })
  vim.ui.input = original
  assert(ok, err)
  assert(callback)
  callback(value)
end
T["lightweight tag points to the selected commit rather than HEAD"] = function()
  vim.cmd("GinLog --oneline")
  tag_action("tag:lightweight", "selected")
  MiniTest.expect.equality(H.git(root, "rev-parse", "selected"), first .. "\n")
  MiniTest.expect.equality(H.git(root, "cat-file", "-t", "selected"), "commit\n")
end
T["force tag updates an existing ref and cancellation is inert"] = function()
  H.git(root, "tag", "selected", second)
  vim.cmd("GinLog --oneline")
  tag_action("tag:lightweight:force", nil)
  MiniTest.expect.equality(H.git(root, "rev-parse", "selected"), second .. "\n")
  tag_action("tag:lightweight:force", "selected")
  MiniTest.expect.equality(H.git(root, "rev-parse", "selected"), first .. "\n")
end
T["fixup commits staged changes with the selected subject"] = function()
  vim.fn.writefile({ "fixed" }, root .. "/one")
  H.git(root, "add", "one")
  vim.cmd("GinLog --oneline")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "fixup", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "log", "-1", "--format=%s"), "fixup! first change\n")
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^"), second .. "\n")
  MiniTest.expect.equality(H.git(root, "show", "HEAD:one"), "fixed\n")
end
T["instant fixup folds staged changes into a root commit"] = function()
  vim.fn.writefile({ "fixed" }, root .. "/one")
  H.git(root, "add", "one")
  vim.cmd("GinLog --oneline")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "fixup:instant-fixup", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "rev-list", "--count", "HEAD"), "2\n")
  MiniTest.expect.equality(H.git(root, "log", "--format=%s"), "second change\nfirst change\n")
  MiniTest.expect.equality(H.git(root, "show", "HEAD^:one"), "fixed\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/two"), { "second" })
  MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
end
T["reflog exposes commits removed from ordinary history and restores them"] = function()
  H.git(root, "reset", "--hard", first)
  vim.cmd.GinReflog()
  MiniTest.expect.equality(vim.bo.filetype, "gin-reflog")
  local rows = require("gin.log").candidates(vim.api.nvim_get_current_buf(), { 1, 999 })
  MiniTest.expect.equality(second:sub(1, #rows[2].commit), rows[2].commit)
  require("gin.action").call(vim.api.nvim_get_current_buf(), "reset:hard", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), second .. "\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/two"), { "second" })
end
T["reflog ref selection and limit survive URI reload"] = function()
  vim.cmd("GinReflog -n1 refs/heads/main")
  vim.cmd.edit()
  local rows = require("gin.log").candidates(vim.api.nvim_get_current_buf(), { 1, 999 })
  MiniTest.expect.equality(#rows, 1)
  MiniTest.expect.equality(second:sub(1, #rows[1].commit), rows[1].commit)
end
return T
