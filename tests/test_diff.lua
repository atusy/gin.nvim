local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.mkdir(root .. "/sub", "p")
      vim.fn.writefile({ "base" }, root .. "/sub/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      vim.fn.writefile({ "index" }, root .. "/sub/file")
      H.git(root, "add", ".")
      vim.fn.writefile({ "working" }, root .. "/sub/file")
      vim.cmd.cd(root .. "/sub")
      dofile(old_cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
    end,
  },
})
T["GinDiff compares the selected working file to the index"] = function()
  vim.cmd("GinDiff -- sub/file")
  MiniTest.expect.equality(vim.bo.filetype, "gin-diff")
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("-index\n+working", 1, true) ~= nil, true)
  MiniTest.expect.equality(vim.bo.modifiable, false)
end
T["GinDiff cached comparison survives URI reload"] = function()
  vim.cmd("GinDiff --cached -U0 -- sub/file")
  vim.cmd.edit()
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("-base\n+index", 1, true) ~= nil, true)
end
T["GinDiff compares an explicit revision range"] = function()
  H.git(root, "commit", "-m", "second")
  vim.cmd("GinDiff HEAD^..HEAD -- sub/file")
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("-base\n+index", 1, true) ~= nil, true)
  MiniTest.expect.equality(content:find("working", 1, true), nil)
end
T["status smart diff selects the cached changes when both sides differ"] = function()
  vim.cmd.GinStatus()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys("dd", "mx", false)
  MiniTest.expect.equality(vim.bo.filetype, "gin-diff")
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("-base\n+index", 1, true) ~= nil, true)
end
T["smart diff uses the working tree when the index is unchanged"] = function()
  H.git(root, "reset", "--quiet", "--", "sub/file")
  vim.cmd.GinStatus()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "diff:smart", { 2, 2 })
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("-base\n+working", 1, true) ~= nil, true)
end
local function jump(line, keys)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local row = assert(
    vim.tbl_contains(lines, line)
      and vim.fn.match(lines, "^" .. vim.fn.escape(line, "\\.*[]~$") .. "$") + 1
  )
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  vim.api.nvim_feedkeys(keys or "\r", "mx", false)
end
T["smart jump opens the working file for added lines"] = function()
  vim.cmd("GinDiff -- sub/file")
  jump("+working")
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/sub/file")
  MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0), { 1, 0 })
end
T["smart jump opens the index for removed working lines"] = function()
  vim.cmd("GinDiff -- sub/file")
  jump("-index")
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "index")
end
T["cached jumps select HEAD and index respectively"] = function()
  vim.cmd("GinDiff --cached -- sub/file")
  local diff = vim.api.nvim_get_current_buf()
  jump("-base")
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "base")
  vim.api.nvim_set_current_buf(diff)
  jump("+index")
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "index")
end
T["revision jumps use the corresponding revision"] = function()
  H.git(root, "commit", "-m", "second")
  vim.cmd("GinDiff HEAD^..HEAD -- sub/file")
  jump("+index")
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "index")
end
T["jump offsets ignore removed lines and no-newline markers"] = function()
  local parse = require("gin.diffjump").parse
  local lines = {
    "--- a/file",
    "+++ b/file",
    "@@ -4,2 +4,2 @@",
    "-old",
    "\\ No newline at end of file",
    "+new",
    " context",
  }
  MiniTest.expect.equality(parse(lines, 7, "new"), { path = "file", lnum = 5 })
  MiniTest.expect.equality(parse(lines, 7, "old"), { path = "file", lnum = 5 })
  MiniTest.expect.equality(parse(lines, 3, "new"), nil)
end
T["jump decodes Git quoted paths"] = function()
  local path = "sub/tab\t日本語"
  vim.fn.writefile({ "old" }, root .. "/" .. path)
  H.git(root, "add", "--", path)
  vim.fn.writefile({ "new" }, root .. "/" .. path)
  require("gin.diff").open(vim.uv.fs_realpath(root), { paths = { path } })
  jump("+new")
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/" .. path)
end
T["three-dot old jump resolves the common ancestor"] = function()
  H.git(root, "commit", "-m", "second")
  vim.cmd("GinDiff HEAD^...HEAD -- sub/file")
  jump("-base")
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.api.nvim_get_current_line(), "base")
end
T["reverse diff swaps the working and index jump targets"] = function()
  vim.cmd("GinDiff -R -- sub/file")
  jump("-working")
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root) .. "/sub/file")
end
T["diff folds summarize file changes and rebuild on reload"] = function()
  vim.cmd("GinDiff -- sub/file")
  MiniTest.expect.equality(vim.wo.foldmethod, "manual")
  MiniTest.expect.equality(vim.fn.foldlevel(3), 1)
  vim.cmd("normal! zM")
  MiniTest.expect.equality(vim.fn.foldtextresult(3), "[.] sub/file (+1 -1)")
  H.git(root, "checkout", "--", "sub/file")
  vim.cmd.edit()
  MiniTest.expect.equality(vim.fn.foldlevel(1), 0)
end
T["fold sections distinguish file headers from removed content"] = function()
  local sections = require("gin.difffold").sections({
    "diff --git a/one b/one",
    "--- a/one",
    "+++ b/one",
    "@@ -1 +1 @@",
    "--- removed",
    "+++ added",
    "diff --git a/two b/two",
    "--- a/two",
    "+++ /dev/null",
    "@@ -1 +0,0 @@",
    "-old",
  })
  MiniTest.expect.equality(sections, { { first = 2, last = 6 }, { first = 8, last = 11 } })
end
return T
