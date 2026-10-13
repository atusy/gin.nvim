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
T["GinBuffer opens Git output in an immutable scratch buffer"] = function()
  vim.fn.writefile({ "hello" }, root .. "/file")
  vim.cmd("GinBuffer status --short")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "?? file" })
  MiniTest.expect.equality(vim.bo.buftype, "nofile")
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.bo.filetype, "gin-buffer")
  MiniTest.expect.equality(require("gin.worktree").current(), vim.uv.fs_realpath(root))
end
T["GinBuffer reload preserves special arguments"] = function()
  vim.fn.writefile({ "hello" }, root .. "/space # name")
  vim.cmd([[GinBuffer ls-files --others -- space\ #\ name]])
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "space # name" })
  vim.cmd("edit")
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "space # name" })
end
T["GinBuffer respects a split modifier"] = function()
  local windows = #vim.api.nvim_tabpage_list_wins(0)
  vim.cmd("botright GinBuffer ++opener=vsplit status --short")
  MiniTest.expect.equality(#vim.api.nvim_tabpage_list_wins(0), windows + 1)
  vim.cmd.close()
end
T["reading a GinBuffer URI inserts at the address and preserves buffer options"] = function()
  vim.fn.writefile({ "hello" }, root .. "/file")
  vim.cmd("GinBuffer ls-files --others")
  local name = vim.api.nvim_buf_get_name(0)
  vim.cmd.enew()
  vim.bo.filetype = "lua"
  vim.bo.fileformat = "dos"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "last" })
  local events = 0
  local id = vim.api.nvim_create_autocmd("FileReadPost", {
    pattern = "gin://*",
    callback = function()
      events = events + 1
    end,
  })
  vim.api.nvim_cmd({ cmd = "read", range = { 1 }, args = { vim.fn.fnameescape(name) } }, {})
  vim.api.nvim_del_autocmd(id)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "first", "file", "last" })
  MiniTest.expect.equality(vim.api.nvim_buf_get_mark(0, "["), { 2, 0 })
  MiniTest.expect.equality(vim.api.nvim_buf_get_mark(0, "]"), { 2, 0 })
  MiniTest.expect.equality(
    { vim.bo.filetype, vim.bo.fileformat, vim.bo.buftype, vim.bo.modified },
    { "lua", "dos", "", true }
  )
  MiniTest.expect.equality(events, 1)
end
T["reading empty Git output inserts no blank line"] = function()
  local name = require("gin.uri").format("gin", vim.uv.fs_realpath(root), {}, "status --short")
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "keep" })
  vim.api.nvim_cmd({ cmd = "read", args = { vim.fn.fnameescape(name) } }, {})
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "keep" })
end
T["read honors encoding without changing the destination encoding"] = function()
  vim.fn.writefile({ "caf" .. string.char(233) }, root .. "/latin1")
  H.git(root, "add", "latin1")
  local name = require("gin.uri").format("gin", vim.uv.fs_realpath(root), {}, "show :latin1")
  vim.cmd.enew()
  vim.bo.fileencoding = "utf-8"
  vim.cmd("read ++enc=latin1 " .. vim.fn.fnameescape(name))
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "café" })
  MiniTest.expect.equality(vim.bo.fileencoding, "utf-8")
end
T["failed reads preserve content and do not emit FileReadPost"] = function()
  local name = require("gin.uri").format("gin", vim.uv.fs_realpath(root), {}, "show :missing")
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "keep" })
  local events = 0
  local id = vim.api.nvim_create_autocmd("FileReadPost", {
    pattern = "gin://*",
    callback = function()
      events = events + 1
    end,
  })
  local ok = pcall(vim.cmd, "read " .. vim.fn.fnameescape(name))
  vim.api.nvim_del_autocmd(id)
  MiniTest.expect.equality(ok, false)
  MiniTest.expect.equality(events, 0)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "keep" })
end
T["GinBuffer decoding options survive reload"] = function()
  vim.fn.writefile({ "caf" .. string.char(233) .. "\r" }, root .. "/latin1")
  H.git(root, "add", "latin1")
  vim.cmd("GinBuffer ++enc=latin1 ++ff=dos show :latin1")
  for _ = 1, 2 do
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "café" })
    MiniTest.expect.equality(vim.bo.fileformat, "dos")
    MiniTest.expect.equality(vim.bo.fileencoding, "latin1")
    vim.cmd.edit()
  end
end
T["GinBuffer processor survives reload and addressed reads"] = function()
  vim.fn.writefile({ "hello" }, root .. "/file")
  vim.cmd([[GinBuffer ++processor=tr\ a-z\ A-Z status --short]])
  local name = vim.api.nvim_buf_get_name(0)
  vim.cmd.edit()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "?? FILE" })
  vim.cmd.enew()
  vim.cmd("read " .. vim.fn.fnameescape(name))
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "?? FILE" })
end
return T
