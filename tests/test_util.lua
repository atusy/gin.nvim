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
T["legacy log expansion accepts a plain path fragment"] = function()
  local root = vim.fn.tempname()
  local path = "sub/space 日本語.lua"
  with_name("ginlog://" .. root .. ";commitish=HEAD#" .. path, function()
    MiniTest.expect.equality(vim.fn["gin#util#expand"]("%"), root .. "/" .. path)
    local _, args = require("gin.command").parse({ "%" }, {})
    MiniTest.expect.equality(args, { root .. "/" .. path })
  end)
end
T["legacy file URI expansion shares JSON fragment semantics"] = function()
  local root = vim.fn.tempname()
  for _, scheme in ipairs({ "ginedit", "gindiff", "ginlog" }) do
    for _, case in ipairs({
      { ' ["sub/file.lua","other"]', "sub/file.lua" },
      { "[]", false },
      { "[null]", false },
      { "[false]", false },
      { "[0]", false },
      { '[""]', false },
      { "[12]", "[12]" },
      { "[{}]", "[{}]" },
      { "{}", "{}" },
      { "null", "null" },
      { "12", "12" },
      { '"text"', "t" },
      { '"日本語"', "日" },
      { '""', false },
      { '["/absolute/file"]', "absolute/file" },
    }) do
      local name = scheme .. "://" .. root .. ";commitish=HEAD#" .. case[1]
      with_name(name, function()
        MiniTest.expect.equality(
          vim.fn["gin#util#expand"]("%"),
          case[2] and root .. "/" .. case[2] or name
        )
      end)
    end
  end
end
T["file URI expansion preserves literal environment variable names"] = function()
  local variable = "GIN_TEST_LITERAL_PATH"
  local previous = vim.env[variable]
  vim.env[variable] = "unexpected-expansion"
  local ok, err = pcall(function()
    local root = vim.fn.tempname() .. "/$" .. variable
    local path = "sub/$" .. variable .. ".lua"
    for _, scheme in ipairs({ "ginedit", "gindiff", "ginlog" }) do
      local fragment = scheme == "ginedit" and path
        or vim.json.encode(scheme == "ginlog" and { "--", path } or { path })
      for _, name in ipairs({
        require("gin.uri").format(scheme, root, {}, fragment),
        scheme .. "://" .. root .. ";commitish=HEAD#" .. vim.json.encode({ path }),
      }) do
        with_name(name, function()
          MiniTest.expect.equality(vim.fn["gin#util#expand"]("%"), root .. "/" .. path)
        end)
      end
    end
  end)
  vim.env[variable] = previous
  assert(ok, err)
end
T["file URI normalization keeps literal tilde roots and POSIX backslashes"] = function()
  if vim.fn.has("win32") == 1 then
    return
  end
  for _, root in ipairs({ "~", "~literal", "~/repo" }) do
    local path = "sub/./temporary/../file\\name.lua"
    for _, scheme in ipairs({ "ginedit", "gindiff", "ginlog" }) do
      local fragment = scheme == "ginedit" and path
        or vim.json.encode(scheme == "ginlog" and { "--", path } or { path })
      for _, name in ipairs({
        require("gin.uri").format(scheme, root, {}, fragment),
        scheme .. "://" .. root .. ";commitish=HEAD#" .. vim.json.encode({ path }),
      }) do
        with_name(name, function()
          MiniTest.expect.equality(vim.fn["gin#util#expand"]("%"), root .. "/sub/file\\name.lua")
        end)
      end
    end
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
