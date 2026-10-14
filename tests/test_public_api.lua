local T = MiniTest.new_set()

local function arity(args)
  local required, variadic = 0, false
  for arg in args:gmatch("[^,%s]+") do
    if arg == "..." then
      variadic = true
    else
      required = required + 1
    end
  end
  return { required = required, variadic = variadic }
end

T["public autoload signatures match the pinned source"] = function()
  local expected = {}
  for _, path in ipairs(vim.fn.glob(".deps/vim-gin/autoload/gin/**/*.vim", false, true)) do
    for _, line in ipairs(vim.fn.readfile(path)) do
      local name, args = line:match("^function!?%s+(gin#[^%(]+)%(([^%)]*)%)")
      if name and not name:find("^gin#internal#") then
        expected[name] = arity(args)
      end
    end
  end
  MiniTest.expect.equality(vim.tbl_count(expected), 13)
  for _, path in ipairs(vim.fn.glob("autoload/gin/**/*.vim", false, true)) do
    vim.cmd.source(path)
  end
  for name, signature in pairs(expected) do
    MiniTest.expect.equality(vim.fn.exists("*" .. name), 1)
    local definition = vim.fn.execute("function " .. name)
    local args = assert(definition:match("function%s+[^%(]+%(([^%)]*)%)"), definition)
    MiniTest.expect.equality({ name, arity(args) }, { name, signature })
  end
end

return T
