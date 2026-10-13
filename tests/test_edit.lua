local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.mkdir(root .. "/sub", "p")
      vim.fn.writefile({ "committed" }, root .. "/sub/file.lua")
      H.git(root, "add", "sub/file.lua")
      H.git(root, "commit", "-m", "initial")
      vim.fn.writefile({ "index" }, root .. "/sub/file.lua")
      H.git(root, "add", "sub/file.lua")
      vim.fn.writefile({ "working" }, root .. "/sub/file.lua")
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
T["GinEdit reads an immutable revision using repository-relative paths"] = function()
  vim.cmd("GinEdit HEAD sub/file.lua")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "committed" })
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.bo.buftype, "nowrite")
  MiniTest.expect.equality(vim.bo.filetype, "lua")
end
T["writing GinEdit changes only the index from a subdirectory"] = function()
  vim.cmd("GinEdit sub/file.lua")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "index" })
  MiniTest.expect.equality(vim.bo.buftype, "acwrite")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "edited index" })
  vim.cmd.write()
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "edited index\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "working" })
  MiniTest.expect.equality(vim.bo.modified, false)
end
T["index writes preserve executable mode when the working file is missing"] = function()
  H.git(root, "update-index", "--chmod=+x", "sub/file.lua")
  vim.cmd("GinEdit sub/file.lua")
  vim.fn.delete(root .. "/sub/file.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "executable" })
  vim.cmd.write()
  MiniTest.expect.equality(H.git(root, "ls-files", "--stage", "sub/file.lua"):sub(1, 6), "100755")
  MiniTest.expect.equality(vim.uv.fs_stat(root .. "/sub/file.lua"), nil)
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "executable\n")
end
T["failed index writes keep edits marked modified and preserve both files"] = function()
  vim.cmd("GinEdit sub/file.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
  vim.fn.writefile({ "locked" }, root .. "/.git/index.lock")
  MiniTest.expect.error(function()
    vim.cmd.write()
  end, "git exited")
  MiniTest.expect.equality(vim.bo.modified, true)
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "index\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "working" })
end
T["index writes honor clean filters for the repository path"] = function()
  vim.fn.writefile({ "sub/file.lua filter=upper" }, root .. "/.gitattributes")
  H.git(root, "config", "filter.upper.clean", "tr a-z A-Z")
  vim.cmd("GinEdit sub/file.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "filtered" })
  vim.cmd.write()
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "FILTERED\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file.lua"), { "working" })
end
T["BOM and CRLF survive an index write"] = function()
  local bytes = "\239\187\191first\r\nsecond\r\n"
  local file = assert(io.open(root .. "/sub/file.lua", "wb"))
  file:write(bytes)
  file:close()
  H.git(root, "add", "sub/file.lua")
  vim.cmd("GinEdit sub/file.lua")
  MiniTest.expect.equality(vim.bo.bomb, true)
  MiniTest.expect.equality(vim.bo.fileformat, "dos")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "first", "second" })
  vim.cmd.write()
  MiniTest.expect.equality(
    require("gin.git").run({ "show", ":sub/file.lua" }, { cwd = root }).stdout,
    bytes
  )
end
T["noeol content survives a write with fixendofline disabled"] = function()
  vim.fn.writefile({ "no newline" }, root .. "/sub/file.lua", "b")
  H.git(root, "add", "sub/file.lua")
  vim.cmd("GinEdit sub/file.lua")
  MiniTest.expect.equality(vim.bo.endofline, false)
  vim.bo.fixendofline = false
  vim.cmd.write()
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "no newline")
end
T["writing an empty index buffer keeps the blob empty"] = function()
  vim.fn.writefile({}, root .. "/sub/file.lua")
  H.git(root, "add", "sub/file.lua")
  vim.cmd("GinEdit sub/file.lua")
  vim.cmd.write()
  MiniTest.expect.equality(H.git(root, "show", ":sub/file.lua"), "")
end
return T
