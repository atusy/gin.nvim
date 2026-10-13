local T = MiniTest.new_set()

local function with_name(name, check)
  local previous = vim.api.nvim_get_current_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.api.nvim_set_current_buf(buf)
  local ok, err = pcall(check)
  vim.api.nvim_set_current_buf(previous)
  vim.api.nvim_buf_delete(buf, { force = true })
  assert(ok, err)
end

T["expand supports native filename expressions"] = function()
  local path = vim.fn.tempname() .. " file.lua"
  with_name(path, function()
    MiniTest.expect.equality(require("gin.util").expand("%:p"), path)
    MiniTest.expect.equality(require("gin.util").expand("%:t"), vim.fs.basename(path))
  end)
end
T["legacy expand resolves Gin paths without evaluating their contents"] = function()
  local root = vim.fn.tempname()
  local path = "sub/space ' # 日本語.lua"
  with_name(require("gin.uri").format("ginedit", root, { commitish = "HEAD" }, path), function()
    MiniTest.expect.equality(vim.fn["gin#util#expand"]("%"), root .. "/" .. path)
  end)
  with_name(root .. "/" .. path, function()
    MiniTest.expect.equality(vim.fn["gin#util#expand"]("%:t"), vim.fs.basename(path))
  end)
end
for _, case in ipairs({
  { "ginedit", "sub/file.lua" },
  { "gindiff", vim.json.encode({ "sub/file.lua", "other" }) },
  { "gindiff", "sub/file.lua" },
  { "ginlog", vim.json.encode({ "--oneline", "HEAD", "--", "sub/file.lua" }) },
}) do
  T["expand resolves " .. case[1] .. " " .. case[2] .. " to its first file"] = function()
    local root = vim.fn.tempname()
    local name = require("gin.uri").format(case[1], root, {}, case[2])
    with_name(name, function()
      MiniTest.expect.equality(require("gin.util").expand("%"), root .. "/sub/file.lua")
      local _, args = require("gin.command").parse({ "%" }, {})
      MiniTest.expect.equality(args, { root .. "/sub/file.lua" })
    end)
  end
end
T["expand leaves views without file paths unchanged"] = function()
  for _, case in ipairs({
    { "ginstatus", nil },
    { "gindiff", nil },
    { "gindiff", "[]" },
    { "ginlog", "invalid-json" },
    { "ginlog", vim.json.encode({ "HEAD" }) },
  }) do
    local name = require("gin.uri").format(case[1], vim.fn.tempname(), {}, case[2])
    with_name(name, function()
      MiniTest.expect.equality(require("gin.util").expand("%"), name)
    end)
  end
end
return T
