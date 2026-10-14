local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local formats, encodings = vim.o.fileformats, vim.o.fileencodings
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
      vim.o.fileencodings = encodings
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})

local function stage(data)
  local file = assert(io.open(root .. "/file", "wb"))
  file:write(data)
  file:close()
  H.git(root, "add", "file")
end

local cases = {
  { "invalid lead", { 255, 65 }, "�A" },
  { "incomplete prefix", { 226, 130 }, "�" },
  { "invalid continuation", { 226, 65 }, "�A" },
  { "surrogate", { 237, 160, 128 }, "���" },
  { "overlong", { 192, 175 }, "��" },
  { "beyond Unicode", { 244, 144, 128, 128 }, "����" },
  { "astral scalar", { 240, 159, 152, 128 }, "😀" },
  { "BOM and invalid byte", { 239, 187, 191, 255 }, "�" },
  { "NUL and invalid byte", { 0, 255 }, "\0�" },
  { "partial prefix before ASCII", { 226, 130, 65 }, "�A" },
  { "stray continuations", { 128, 129 }, "��" },
  { "literal replacement", { 239, 191, 189 }, "�" },
  { "valid boundary", { 194, 128 }, vim.fn.nr2char(128) },
}
for _, command in ipairs({ "GinBuffer", "GinEdit" }) do
  for _, encoding in ipairs({ "utf-8", "utf8" }) do
    for _, case in ipairs(cases) do
      T[command .. " ++enc=" .. encoding .. " handles " .. case[1]] = function()
        local data = string.char(unpack(case[2]))
        stage(data)
        vim.o.fileencodings = "latin1"
        vim.o.fileformats = "unix"
        local suffix = command == "GinBuffer" and " show :file" or " file"
        vim.cmd(command .. " ++enc=" .. encoding .. suffix)
        MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { case[3] })
        MiniTest.expect.equality(vim.bo.fileencoding, "utf-8")
        MiniTest.expect.equality(
          require("gin.git").run({ "show", ":file" }, { cwd = root }).stdout,
          data
        )
      end
    end
  end
end
for _, scheme in ipairs({ "gin", "ginedit" }) do
  T[scheme .. " addressed reads replace malformed explicit UTF-8"] = function()
    stage(string.char(226, 130) .. "\n")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
    vim.bo.fileencoding = "latin1"
    local fragment = scheme == "gin" and "show :file" or "file"
    local name = require("gin.uri").format(scheme, root, {}, fragment)
    vim.cmd("1read ++enc=utf-8 " .. vim.fn.fnameescape(name))
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(0, 0, -1, false),
      { "before", "�", "after" }
    )
    MiniTest.expect.equality(vim.bo.fileencoding, "latin1")
  end
end
return T
