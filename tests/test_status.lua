local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.cmd.cd(root)
      dofile(old_cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
    end,
  },
})
T["GinStatus lists the branch and untracked paths in sorted order"] = function()
  vim.fn.writefile({ "z" }, root .. "/z")
  vim.fn.writefile({ "a" }, root .. "/a")
  vim.cmd.GinStatus()
  MiniTest.expect.equality(vim.bo.filetype, "gin-status")
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "## No commits yet on main", "?? a", "?? z" }
  )
end
T["stage and unstage target the selected path from a subdirectory"] = function()
  vim.fn.mkdir(root .. "/sub", "p")
  vim.fn.writefile({ "hello" }, root .. "/sub/space name")
  vim.cmd.cd(root .. "/sub")
  vim.cmd.GinStatus()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Plug>(gin-action-stage)", true, false, true),
    "mx",
    false
  )
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "sub/space name\n")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { 'A  "sub/space name"' })
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Plug>(gin-action-unstage)", true, false, true),
    "mx",
    false
  )
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/space name"), { "hello" })
end
T["staging supports newlines, pathspec magic and leading dashes"] = function()
  local paths = { "line\nbreak", "[literal]", "-dash" }
  for _, path in ipairs(paths) do
    vim.fn.writefile({ "content" }, root .. "/" .. path)
  end
  vim.cmd.GinStatus()
  require("gin.status").action(vim.api.nvim_get_current_buf(), "stage", { 2, 4 })
  local actual = vim.split(H.git(root, "ls-files", "-z"), "\0", { plain = true, trimempty = true })
  table.sort(paths)
  MiniTest.expect.equality(actual, paths)
end
T["unstaging the branch header leaves staged files alone"] = function()
  vim.fn.writefile({ "content" }, root .. "/file")
  H.git(root, "add", "file")
  vim.cmd.GinStatus()
  require("gin.status").action(vim.api.nvim_get_current_buf(), "unstage", { 1, 1 })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "file\n")
end
T["stage records deleted files in the index"] = function()
  vim.fn.writefile({ "content" }, root .. "/file")
  H.git(root, "add", "file")
  H.git(root, "commit", "-m", "initial")
  vim.fn.delete(root .. "/file")
  vim.cmd.GinStatus()
  require("gin.status").action(vim.api.nvim_get_current_buf(), "stage", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-status"), "D\tfile\n")
end
T["unstage restores both sides of a staged rename"] = function()
  vim.fn.writefile({ "content" }, root .. "/before")
  H.git(root, "add", "before")
  H.git(root, "commit", "-m", "initial")
  H.git(root, "mv", "before", "after")
  vim.cmd.GinStatus()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "R  before -> after" })
  require("gin.status").action(vim.api.nvim_get_current_buf(), "unstage", { 2, 2 })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/after"), { "content" })
end
T["status path filtering survives reload"] = function()
  vim.fn.writefile({ "content" }, root .. "/one")
  vim.fn.writefile({ "content" }, root .. "/two")
  vim.cmd("GinStatus -- one")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "?? one" })
end
T["visual stage mapping changes only the selected range"] = function()
  for _, path in ipairs({ "a", "b", "c" }) do
    vim.fn.writefile({ "content" }, root .. "/" .. path)
  end
  vim.cmd.GinStatus()
  vim.api.nvim_feedkeys("ggjVj<<", "mx", false)
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "a\nb\n")
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
end
T["Gin command completion refreshes the status view"] = function()
  vim.fn.writefile({ "content" }, root .. "/file")
  vim.cmd.GinStatus()
  vim.cmd("Gin ++wait add -- file")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "A  file" })
end
T["chosen status actions remain repeatable after refresh"] = function()
  for _, path in ipairs({ "one", "two" }) do
    vim.fn.writefile({ "content" }, root .. "/" .. path)
  end
  vim.cmd.GinStatus()
  local action = require("gin.action")
  local input = vim.ui.input
  vim.ui.input = function(_, callback)
    callback("stage")
  end
  local ok, err = pcall(action.call, vim.api.nvim_get_current_buf(), "choice", { 2, 2 })
  vim.ui.input = input
  assert(ok, err)
  action.call(vim.api.nvim_get_current_buf(), "repeat", { 3, 3 })
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "one\ntwo\n")
end
return T
