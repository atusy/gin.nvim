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
for _, command in ipairs({ "GinLog --oneline", "GinReflog" }) do
  T[command .. " detached switch restores the selected historical tree"] = function()
    vim.cmd(command)
    require("gin.action").call(vim.api.nvim_get_current_buf(), "switch:detach", { 2, 2 })
    MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), first .. "\n")
    MiniTest.expect.equality(H.git(root, "branch", "--show-current"), "")
    MiniTest.expect.equality(vim.fn.filereadable(root .. "/two"), 0)
    MiniTest.expect.equality(H.git(root, "rev-parse", "main"), second .. "\n")
  end
end
T["ordinary log switch rejects a commit without changing HEAD"] = function()
  vim.cmd("GinLog --oneline")
  MiniTest.expect.error(function()
    require("gin.action").call(vim.api.nvim_get_current_buf(), "switch", { 2, 2 })
  end, "git exited")
  MiniTest.expect.equality(H.git(root, "branch", "--show-current"), "main\n")
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), second .. "\n")
end
T["log merge uses the selected commit as its target"] = function()
  H.git(root, "checkout", "-b", "target", first)
  vim.cmd("GinLog --oneline main")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "merge:ff-only", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), second .. "\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/two"), { "second" })
end
T["reflog rebase replays current work onto the selected entry"] = function()
  H.git(root, "checkout", "-b", "target", first)
  vim.fn.writefile({ "side" }, root .. "/side")
  H.git(root, "add", "side")
  H.git(root, "commit", "-m", "side change")
  vim.cmd("GinReflog main")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "rebase", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^"), second .. "\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/side"), { "side" })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/two"), { "second" })
end
T["colored log and reflog retain actionable commits across reload"] = function()
  local ns = vim.api.nvim_create_namespace("gin_ansi")
  for _, command in ipairs({ "GinLog", "GinReflog" }) do
    vim.cmd(command .. " --oneline")
    for _ = 1, 2 do
      local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
      MiniTest.expect.equality(#marks > 0, true)
      local candidate = require("gin.log").candidates(0, { 1, 1 })[1]
      MiniTest.expect.equality(vim.trim(H.git(root, "rev-parse", candidate.commit)), second)
      vim.cmd.edit()
    end
    vim.cmd(command .. " --oneline --no-color")
    MiniTest.expect.equality(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}), {})
  end
end
T["interactive rebase edits the selected history through the proxy"] = function()
  vim.cmd("GinLog --oneline")
  local process = require("gin.action").call(vim.api.nvim_get_current_buf(), "rebase:i", { 2, 2 })
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  MiniTest.expect.equality(
    vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t"),
    "git-rebase-todo"
  )
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  MiniTest.expect.equality(lines[1]:match("^pick ") ~= nil, true)
  lines[1] = lines[1]:gsub("^pick ", "drop ")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.cmd.Apply()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return process:is_closing()
    end, 10),
    true
  )
  MiniTest.expect.equality(process:wait(5000).code, 0)
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD"), first .. "\n")
  MiniTest.expect.equality(vim.fn.filereadable(root .. "/two"), 0)
end
T["tag alias creates an annotated tag with the edited message on the selection"] = function()
  vim.cmd("GinLog --oneline")
  local done = false
  local event = vim.api.nvim_create_autocmd("User", {
    pattern = "GinCommandPost",
    once = true,
    callback = function()
      done = true
    end,
  })
  tag_action("tag", "annotated")
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  MiniTest.expect.equality(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t"), "TAG_EDITMSG")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "release notes" })
  vim.cmd.Apply()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return done
    end, 10),
    true
  )
  pcall(vim.api.nvim_del_autocmd, event)
  MiniTest.expect.equality(H.git(root, "cat-file", "-t", "annotated"), "tag\n")
  MiniTest.expect.equality(H.git(root, "rev-parse", "annotated^{}"), first .. "\n")
  MiniTest.expect.equality(
    H.git(root, "for-each-ref", "--format=%(contents)", "refs/tags/annotated"),
    "release notes\n\n"
  )
end
T["signed force tags replace a ref with a verifiable SSH signature"] = function()
  local key = root .. "/.git/signing-key"
  local generated =
    vim.system({ "ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", key }):wait(5000)
  MiniTest.expect.equality(generated.code, 0)
  vim.fn.writefile(
    { "gin@example.invalid " .. vim.fn.readfile(key .. ".pub")[1] },
    root .. "/.git/allowed-signers"
  )
  H.git(root, "config", "gpg.format", "ssh")
  H.git(root, "config", "user.signingkey", key)
  H.git(root, "config", "gpg.ssh.allowedSignersFile", root .. "/.git/allowed-signers")
  H.git(root, "tag", "signed", second)
  vim.cmd("GinLog --oneline")
  local done = false
  local event = vim.api.nvim_create_autocmd("User", {
    pattern = "GinCommandPost",
    once = true,
    callback = function()
      done = true
    end,
  })
  tag_action("tag:sign:force", "signed")
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "signed release" })
  vim.cmd.Apply()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return done
    end, 10),
    true
  )
  pcall(vim.api.nvim_del_autocmd, event)
  MiniTest.expect.equality(H.git(root, "rev-parse", "signed^{}"), first .. "\n")
  H.git(root, "verify-tag", "signed")
end
T["amend fixup edits the message and commits staged content"] = function()
  vim.fn.writefile({ "amended content" }, root .. "/one")
  H.git(root, "add", "one")
  vim.cmd("GinLog --oneline")
  local process =
    require("gin.action").call(vim.api.nvim_get_current_buf(), "fixup:amend", { 2, 2 })
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  vim.api.nvim_buf_set_lines(
    0,
    0,
    -1,
    false,
    { "amend! first change", "", "updated first message" }
  )
  vim.cmd.Apply()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return process:is_closing()
    end, 10),
    true
  )
  MiniTest.expect.equality(process:wait(5000).code, 0)
  MiniTest.expect.equality(
    H.git(root, "log", "-1", "--format=%B"),
    "amend! first change\n\nupdated first message\n\n"
  )
  MiniTest.expect.equality(H.git(root, "show", "HEAD:one"), "amended content\n")
  MiniTest.expect.equality(H.git(root, "rev-parse", "HEAD^"), second .. "\n")
end
T["reword fixup leaves staged changes out of the new commit"] = function()
  vim.fn.writefile({ "still staged" }, root .. "/one")
  H.git(root, "add", "one")
  vim.cmd("GinLog --oneline")
  local process =
    require("gin.action").call(vim.api.nvim_get_current_buf(), "fixup:reword", { 2, 2 })
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  vim.api.nvim_buf_set_lines(
    0,
    0,
    -1,
    false,
    { "amend! first change", "", "reworded first message" }
  )
  vim.cmd.Apply()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return process:is_closing()
    end, 10),
    true
  )
  MiniTest.expect.equality(process:wait(5000).code, 0)
  MiniTest.expect.equality(
    H.git(root, "log", "-1", "--format=%B"),
    "amend! first change\n\nreworded first message\n\n"
  )
  MiniTest.expect.equality(
    H.git(root, "rev-parse", "HEAD^{tree}"),
    H.git(root, "rev-parse", "HEAD^^{tree}")
  )
  MiniTest.expect.equality(H.git(root, "show", "HEAD:one"), "first\n")
  MiniTest.expect.equality(H.git(root, "show", ":one"), "still staged\n")
end
return T
