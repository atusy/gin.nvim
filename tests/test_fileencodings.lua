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
local control = vim.fn.nr2char(128)
local cases = {
  { "latin1", "utf-8,latin1", "caf" .. string.char(233) .. "\n", "café", "latin1" },
  { "shift_jis", "utf-8,sjis", string.char(147, 250, 150, 123) .. "\n", "日本", "sjis" },
  { "euc_jp", "utf-8,euc-jp", string.char(143, 162, 175) .. "\n", "˘", "euc-jp" },
  { "big5", "utf-8,big5", string.char(136, 98) .. "\n", "Ê̄", "big5" },
  { "euc_kr", "utf-8,euc-kr", string.char(199, 209, 177, 219) .. "\n", "한글", "euc-kr" },
  { "gbk", "utf-8,gbk", string.char(129, 48, 129, 48) .. "\n", control, "cp936" },
  { "gb18030", "utf-8,gb18030", string.char(129, 48, 129, 48) .. "\n", control, "gb18030" },
  {
    "iso_first",
    "iso-2022-jp,utf-8",
    string.char(27, 36, 66, 36, 34, 27, 40, 66) .. "\n",
    "あ",
    "iso-2022-jp",
  },
  {
    "utf8_first",
    "utf-8,iso-2022-jp",
    string.char(27, 36, 66, 36, 34, 27, 40, 66) .. "\n",
    string.char(27, 36, 66, 36, 34, 27, 40, 66),
    "utf-8",
  },
  { "unknown", "made-up,utf-8", "ok\n", "ok", "utf-8" },
  { "fallback", "utf-8", string.char(255) .. "\n", "�", "" },
  { "empty", "", string.char(255) .. "\n", "�", "" },
  { "utf16", "utf-8,utf-16le", string.char(255, 254, 65, 0, 10, 0), "A", "utf-16le" },
  { "utf8_bom", "ucs-bom,utf-8", string.char(239, 187, 191) .. "bom\n", "bom", "utf-8" },
}
for _, command in ipairs({ "GinBuffer show :file", "GinEdit file" }) do
  for _, case in ipairs(cases) do
    T[command .. " selects encoding for " .. case[1]] = function()
      stage(case[3])
      vim.o.fileencodings = case[2]
      vim.o.fileformats = "unix"
      vim.cmd(command)
      MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { case[4] })
      MiniTest.expect.equality(vim.bo.fileencoding, case[5])
      MiniTest.expect.equality(
        require("gin.git").run({ "show", ":file" }, { cwd = root }).stdout,
        case[3]
      )
    end
  end
end
for _, scheme in ipairs({ "gin", "ginedit" }) do
  T[scheme .. " addressed reads decode automatically without changing destination encoding"] = function()
    stage("caf" .. string.char(233) .. "\n")
    vim.o.fileencodings = "utf-8,latin1"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
    vim.bo.fileencoding = "utf-8"
    local fragment = scheme == "gin" and "show :file" or "file"
    local name = require("gin.uri").format(scheme, root, {}, fragment)
    vim.api.nvim_cmd({ cmd = "read", range = { 1 }, args = { vim.fn.fnameescape(name) } }, {})
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(0, 0, -1, false),
      { "before", "café", "after" }
    )
    MiniTest.expect.equality(vim.bo.fileencoding, "utf-8")
  end
end
T["GinEdit writes automatically detected Latin-1 back without changing bytes"] = function()
  local data = "caf" .. string.char(233) .. "\n"
  stage(data)
  vim.o.fileencodings = "utf-8,latin1"
  vim.o.fileformats = "unix"
  vim.cmd("GinEdit file")
  vim.cmd.write()
  MiniTest.expect.equality(require("gin.git").run({ "show", ":file" }, { cwd = root }).stdout, data)
end
for _, command in ipairs({ "GinBuffer ++enc=utf-8 show :file", "GinEdit ++enc=utf-8 file" }) do
  T[command .. " overrides fileencodings"] = function()
    stage("café\n")
    vim.o.fileencodings = "latin1"
    vim.cmd(command)
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "café" })
    MiniTest.expect.equality(vim.bo.fileencoding, "utf-8")
  end
end
T["GinEdit retains detected UTF-16 BOM through an index write"] = function()
  local data = string.char(255, 254, 65, 0, 10, 0)
  stage(data)
  vim.o.fileencodings = "utf-8,utf-16le"
  vim.o.fileformats = "unix"
  vim.cmd("GinEdit file")
  MiniTest.expect.equality(vim.bo.bomb, true)
  vim.cmd.write()
  MiniTest.expect.equality(require("gin.git").run({ "show", ":file" }, { cwd = root }).stdout, data)
end
return T
