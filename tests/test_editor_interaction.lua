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
}) do
  T["keyboard input commits through " .. case[1]] = function()
    child.type_keys(":silent Gin commit<CR>")
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return child.lua_get("vim.b.gin_editor_request ~= nil")
      end, 10),
      true
    )
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
return T
