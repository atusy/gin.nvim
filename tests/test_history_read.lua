local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.writefile({ "base" }, root .. "/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", ":sparkles: initial")
      vim.fn.writefile({ "stashed" }, root .. "/file")
      H.git(root, "stash", "push", "-m", ":sparkles: saved")
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

for _, case in ipairs({
  { command = "GinLog", scheme = "ginlog", expected = "✨ initial" },
  { command = "GinReflog", scheme = "ginreflog", expected = "✨ initial" },
  { command = "GinStash", scheme = "ginstash", expected = "On main: ✨ saved" },
}) do
  T[case.command .. " URI reads preserve custom output and destination options"] = function()
    vim.cmd(case.command .. " ++emojify --format=%s -1")
    local name = vim.api.nvim_buf_get_name(0)
    vim.cmd.enew()
    vim.bo.filetype, vim.bo.fileformat = "lua", "dos"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "last" })
    local events = 0
    local id = vim.api.nvim_create_autocmd("FileReadPost", {
      pattern = case.scheme .. "://*",
      callback = function()
        events = events + 1
      end,
    })
    local ok, err = pcall(vim.cmd, "1read " .. vim.fn.fnameescape(name))
    vim.api.nvim_del_autocmd(id)
    assert(ok, err)
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
      "first",
      case.expected,
      "last",
    })
    MiniTest.expect.equality(vim.api.nvim_buf_get_mark(0, "["), { 2, 0 })
    MiniTest.expect.equality(vim.api.nvim_buf_get_mark(0, "]"), { 2, 0 })
    MiniTest.expect.equality(
      { vim.bo.filetype, vim.bo.fileformat, vim.bo.buftype, vim.bo.modified },
      { "lua", "dos", "", true }
    )
    MiniTest.expect.equality(vim.fn.maparg("<Plug>(gin-action-show)", "n"), "")
    MiniTest.expect.equality(vim.b.gin_stashes, nil)
    MiniTest.expect.equality(events, 1)
  end
  T[case.command .. " URI reads honor explicit encoding"] = function()
    local name = require("gin.uri").format(
      case.scheme,
      vim.uv.fs_realpath(root),
      {},
      vim.json.encode({ "--format=%x63%x61%x66%xe9", "-1" })
    )
    vim.bo.fileencoding = "utf-8"
    vim.cmd("read ++enc=latin1 " .. vim.fn.fnameescape(name))
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "café" })
    MiniTest.expect.equality(vim.bo.fileencoding, "utf-8")
  end
  for _, failing in ipairs({ false, true }) do
    T[case.command .. " reads preserve content on " .. (failing and "failure" or "empty output")] = function()
      local name = require("gin.uri").format(
        case.scheme,
        vim.uv.fs_realpath(root),
        {},
        vim.json.encode({ failing and "--invalid-gin-flag" or "-0" })
      )
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "keep" })
      local events = 0
      local id = vim.api.nvim_create_autocmd("FileReadPost", {
        pattern = case.scheme .. "://*",
        callback = function()
          events = events + 1
        end,
      })
      local ok = pcall(vim.cmd, "read " .. vim.fn.fnameescape(name))
      vim.api.nvim_del_autocmd(id)
      MiniTest.expect.equality(ok, not failing)
      MiniTest.expect.equality(events, failing and 0 or 1)
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "keep" })
    end
  end
end
return T
