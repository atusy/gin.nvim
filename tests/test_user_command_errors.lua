local T = MiniTest.new_set()
local commands = {
  "Blame",
  "Branch",
  "Browse",
  "Buffer",
  "Chaperon",
  "Diff",
  "Edit",
  "Log",
  "Patch",
  "Reflog",
  "Stash",
  "Status",
  "Tag",
}
for _, kind in ipairs(commands) do
  for _, modifier in ipairs({ "", "silent ", "silent! " }) do
    T[kind .. " reports invalid options under " .. modifier] = function()
      local echo, messages, events = vim.api.nvim_echo, {}, 0
      local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
      local windows = vim.api.nvim_tabpage_list_wins(0)
      local autocmd = vim.api.nvim_create_autocmd("User", {
        pattern = "GinCommandPost",
        callback = function()
          events = events + 1
        end,
      })
      vim.api.nvim_echo = function(chunks, history)
        messages[#messages + 1] = { chunks = chunks, history = history }
      end
      local ok, err = pcall(vim.cmd, modifier .. "Gin" .. kind .. " ++unknown=value")
      vim.api.nvim_echo = echo
      require("tests.helpers").drain()
      vim.api.nvim_del_autocmd(autocmd)
      assert(ok, err)
      local suppressed = modifier == "silent! " and kind ~= "Browse"
      MiniTest.expect.equality(#messages, suppressed and 0 or 1)
      if not suppressed then
        MiniTest.expect.equality(messages[1], {
          chunks = { { "[gin]: Unknown Gin option: ++unknown", "ErrorMsg" } },
          history = false,
        })
      end
      MiniTest.expect.equality(events, 0)
      MiniTest.expect.equality(vim.api.nvim_get_current_buf(), buf)
      MiniTest.expect.equality(vim.api.nvim_get_current_win(), win)
      MiniTest.expect.equality(vim.api.nvim_tabpage_list_wins(0), windows)
    end
  end
  T[kind .. " internal command API retains errors"] = function()
    local module = kind == "Reflog" and "log" or kind:lower()
    MiniTest.expect.error(function()
      require("gin." .. module).command({ fargs = { "++unknown=value" }, smods = {} })
    end, "Unknown Gin option")
  end
end
return T
