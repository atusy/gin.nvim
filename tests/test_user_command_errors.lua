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
T["GinEdit reports Git failure without nested callback context"] = function()
  local H = require("tests.helpers")
  local root, cwd = H.repo(), vim.fn.getcwd()
  local echo, message = vim.api.nvim_echo, nil
  local expected = vim.system({ "git", "-C", root, "show", ":missing" }):wait()
  assert(expected.code ~= 0)
  vim.api.nvim_echo = function(chunks)
    if chunks[1][2] == "ErrorMsg" then
      message = chunks[1][1]
    end
  end
  local ok, err = pcall(function()
    vim.cmd.cd(root)
    vim.cmd("GinEdit missing")
  end)
  vim.api.nvim_echo = echo
  vim.cmd.cd(cwd)
  H.cleanup(root)
  assert(ok, err)
  MiniTest.expect.equality(
    message,
    "[gin]: git exited " .. expected.code .. ": " .. expected.stderr
  )
end
local literal = "first\nstack traceback:\n\tuser.lua:42: diagnostic text"
for _, case in ipairs({
  { "direct multiline diagnostic", literal, literal },
  { "literal numeric diagnostic prefix", "revision:42: missing", "revision:42: missing" },
  { "Lua chunk diagnostic", '[string "custom"]:2: bad input', "bad input" },
  { "callback text without API context", "Lua callback: " .. literal, "Lua callback: " .. literal },
  {
    "current callback context",
    "nvim_exec2()[1]: Lua callback: " .. literal .. "\nstack traceback:\n\t[C]: in function error",
    literal,
  },
  {
    "0.10 callback context",
    "vim/_editor.lua:0: nvim_exec2(): Error executing lua callback: "
      .. literal
      .. "\nstack traceback:\n\t[C]: in function error",
    literal,
  },
}) do
  T["friendly errors preserve " .. case[1]] = function()
    local echo, message = vim.api.nvim_echo, nil
    vim.api.nvim_echo = function(chunks)
      message = chunks[1][1]
    end
    local ok, err = pcall(require("gin.command").friendly, function()
      error(case[2], 0)
    end, {})
    vim.api.nvim_echo = echo
    assert(ok, err)
    MiniTest.expect.equality(message, "[gin]: " .. case[3])
  end
end
return T
