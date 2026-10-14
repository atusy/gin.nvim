local H = require("tests.helpers")
local child = MiniTest.new_child_neovim()
local root
local project = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      H.git(root, "config", "user.name", "Gin Test")
      H.git(root, "config", "user.email", "gin@example.invalid")
      H.git(root, "config", "core.editor", "false")
      vim.fn.writefile({ "content" }, root .. "/file")
      H.git(root, "add", ".")
      child.start({ "-u", "NONE" })
      child.lua([[vim.opt.rtp:prepend(...)]], { project })
      child.cmd("runtime plugin/gin.lua")
      child.cmd("filetype plugin on")
      child.api.nvim_set_current_dir(root)
      child.lua([[
        _G.gin_test_completed = false
        vim.api.nvim_create_autocmd("User", {
          pattern = "GinCommandPost",
          callback = function() _G.gin_test_completed = true end,
        })
      ]])
    end,
    post_case = function()
      child.stop()
      H.cleanup(root)
    end,
  },
})
for _, case in ipairs({
  { "Apply", ":Apply<CR>" },
  { "write and quit with confirmation", ":wq<CR>yes<CR>" },
  { "Apply in the current window", ":Apply<CR>", "edit" },
  { "Apply in a horizontal split", ":Apply<CR>", "split" },
  { "Apply in a vertical split", ":Apply<CR>", "vsplit" },
  { "Apply in a preview window", ":Apply<CR>", "pedit" },
}) do
  T["keyboard input commits through " .. case[1]] = function()
    child.g.gin_proxy_editor_opener = case[3] or "tabedit"
    local original = child.api.nvim_get_current_win()
    child.type_keys(":silent Gin commit<CR>")
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return child.lua_get([[(function()
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.b[buf].gin_editor_request then return true end
          end
          return false
        end)()]])
      end, 10),
      true
    )
    local opener = case[3] or "tabedit"
    MiniTest.expect.equality(child.fn.tabpagenr("$"), opener == "tabedit" and 2 or 1)
    MiniTest.expect.equality(
      #child.api.nvim_tabpage_list_wins(0),
      (opener == "tabedit" or opener == "edit") and 1 or 2
    )
    if opener == "pedit" then
      MiniTest.expect.equality(child.api.nvim_get_current_win(), original)
      child.type_keys("<C-w>P")
      MiniTest.expect.equality(child.wo.previewwindow, true)
    elseif opener == "split" or opener == "vsplit" then
      MiniTest.expect.equality(child.fn.winlayout()[1], opener == "split" and "col" or "row")
    elseif opener == "edit" then
      MiniTest.expect.equality(child.api.nvim_get_current_win(), original)
    end
    MiniTest.expect.equality(
      child.fn.fnamemodify(child.api.nvim_buf_get_name(0), ":t"),
      "COMMIT_EDITMSG"
    )
    child.type_keys("gg0i", "commit typed through the editor", "<Esc>", case[2])
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return child.lua_get("_G.gin_test_completed")
      end, 10),
      true
    )
    MiniTest.expect.equality(
      H.git(root, "log", "-1", "--format=%s"),
      "commit typed through the editor\n"
    )
    MiniTest.expect.equality(H.git(root, "show", "HEAD:file"), "content\n")
  end
end
for _, case in ipairs({
  { "Cancel", ":Cancel<CR>" },
  { "quit with rejection", ":q<CR>no<CR>" },
}) do
  T["keyboard input cancels through " .. case[1] .. " without changing the index"] = function()
    child.lua([[
      local git = require("gin.git")
      local start = git.start
      git.start = function(args, options, callback)
        if args[1] ~= "commit" then
          return start(args, options, callback)
        end
        return start(args, options, function(result)
          _G.gin_test_exit = result.code
          callback(result)
        end)
      end
    ]])
    child.type_keys(":silent! Gin commit<CR>")
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return child.lua_get("vim.b.gin_editor_request ~= nil")
      end, 10),
      true
    )
    child.type_keys("gg0i", "discard this draft", "<Esc>", case[2])
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return child.lua_get("_G.gin_test_exit ~= nil")
      end, 10),
      true
    )
    MiniTest.expect.equality(child.lua_get("_G.gin_test_exit ~= 0"), true)
    MiniTest.expect.equality(H.git(root, "rev-list", "--all"), "")
    MiniTest.expect.equality(H.git(root, "show", ":file"), "content\n")
    MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "content" })
  end
end
return T
