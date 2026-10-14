local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local formats, format = vim.o.fileformats, vim.go.fileformat
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
      dofile(cwd .. "/plugin/gin-edit.lua")
    end,
    post_case = function()
      vim.o.fileformats = formats
      vim.go.fileformat = format
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
for _, command in ipairs({ "GinBuffer show :file", "GinEdit file" }) do
  for _, case in ipairs({
    { "unix", "one\r\ntwo\r\n", { "one\r", "two\r" }, "unix" },
    { "mac", "one\rtwo\r", { "one", "two" }, "mac" },
    { "mac,unix", "one\ntwo\n", { "one", "two" }, "unix" },
    { "mac,unix", "one", { "one" }, "mac" },
    { "", "one\rtwo\r", { "one", "two" }, "mac" },
  }) do
    T[command .. " detects format using fileformats=" .. case[1] .. " input=" .. vim.inspect(
      case[2]
    )] = function()
      local file = assert(io.open(root .. "/file", "wb"))
      file:write(case[2])
      file:close()
      H.git(root, "add", "file")
      vim.o.fileformats = case[1]
      vim.go.fileformat = "mac"
      vim.cmd(command)
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), case[3])
      MiniTest.expect.equality(vim.bo.fileformat, case[4])
      MiniTest.expect.equality(
        require("gin.git").run({ "show", ":file" }, { cwd = root }).stdout,
        case[2]
      )
    end
  end
end
T["empty fileformats falls back to the output buffer rather than the current buffer"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.o.fileformats = ""
  vim.bo.fileformat = "unix"
  vim.bo[buf].fileformat = "mac"
  require("gin.buffer").replace_output(buf, "one\rtwo\r", root, "gin-buffer", {})
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "one", "two" })
  MiniTest.expect.equality(vim.bo[buf].fileformat, "mac")
  MiniTest.expect.equality(vim.bo.fileformat, "unix")
end
return T
