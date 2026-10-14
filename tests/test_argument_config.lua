local T = MiniTest.new_set()
local commands = {}
for _, path in ipairs(vim.fn.glob(".deps/vim-gin/denops/gin/command/*/main.ts", false, true)) do
  local source = table.concat(vim.fn.readfile(path), "\n")
  local setting = source:match('fillCmdArgs%(%s*denops,%s*args,%s*"([^"]+)"%s*%)')
  if setting then
    local kind = assert(path:match("/command/([^/]+)/main%.ts$"))
    commands["Gin" .. kind:sub(1, 1):upper() .. kind:sub(2)] = setting
  end
end

T["pinned argument configuration covers twelve commands"] = function()
  MiniTest.expect.equality(vim.tbl_count(commands), 12)
  MiniTest.expect.equality(commands.GinBlame, "edit")
end

for command, kind in pairs(commands) do
  for _, suffix in ipairs({ "default", "persistent" }) do
    local name = "gin_" .. kind .. "_" .. suffix .. "_args"
    T[command .. " validates " .. name .. " before parsing explicit arguments"] = function()
      local previous = vim.g[name]
      local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
      vim.g[name] = "not a list"
      local ok, err = pcall(function()
        require("tests.helpers").command_error(function()
          -- If configuration is skipped, parsing fails without opening a view.
          vim.cmd(command .. " ++audit-invalid-option")
        end, "g:" .. name .. " must be a list of strings")
        MiniTest.expect.equality(vim.api.nvim_get_current_buf(), buf)
        MiniTest.expect.equality(vim.api.nvim_get_current_win(), win)
      end)
      vim.g[name] = previous
      assert(ok, err)
    end
  end
end

return T
