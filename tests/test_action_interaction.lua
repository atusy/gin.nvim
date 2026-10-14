local H = require("tests.helpers")
local child = MiniTest.new_child_neovim()
local root
local project = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      for _, name in ipairs({ "a", "b", "c" }) do
        vim.fn.writefile({ name }, root .. "/" .. name)
      end
      child.start({ "-u", "NONE" })
      child.lua("vim.opt.rtp:prepend(...)", { project })
      child.cmd("runtime plugin/gin.lua")
      child.cmd("runtime plugin/gin-status.lua")
      child.cmd("filetype plugin on")
      child.api.nvim_set_current_dir(root)
      child.cmd("GinStatus")
      child.lua([[
        _G.action_posts = 0
        vim.api.nvim_create_autocmd("User", {
          pattern = "GinCommandPost",
          callback = function() _G.action_posts = _G.action_posts + 1 end,
        })
      ]])
    end,
    post_case = function()
      child.stop()
      H.cleanup(root)
    end,
  },
})
local function wait_for_status(posts, lines)
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return child.lua_get(
        [[(function(posts, lines)
      return _G.action_posts == posts and vim.bo.filetype == "gin-status"
        and vim.deep_equal(vim.api.nvim_buf_get_lines(0, 1, -1, false), lines)
    end)(...)]],
        { posts, lines }
      )
    end, 10),
    true
  )
end
T["typed visual choice stages its range and repeat uses the new cursor"] = function()
  child.type_keys("2GVja", "stag<Tab><CR>")
  wait_for_status(1, { "A  a", "A  b", "?? c" })
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), "a\0b\0")
  MiniTest.expect.equality(child.b.denops_action_previous, "stage")
  MiniTest.expect.equality(
    child.api.nvim_buf_get_lines(0, 1, -1, false),
    { "A  a", "A  b", "?? c" }
  )
  child.type_keys("<Esc>G.")
  wait_for_status(2, { "A  a", "A  b", "A  c" })
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), "a\0b\0c\0")
  for _, name in ipairs({ "a", "b", "c" }) do
    MiniTest.expect.equality(H.git(root, "show", ":" .. name), name .. "\n")
    MiniTest.expect.equality(vim.fn.readfile(root .. "/" .. name), { name })
  end
end
T["cancelling native choice preserves the previous action and Git index"] = function()
  child.b.denops_action_previous = "stage"
  child.type_keys("2Ga", "<C-c>")
  MiniTest.expect.equality(child.b.denops_action_previous, "stage")
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), "")
  child.type_keys("G.")
  wait_for_status(1, { "?? a", "?? b", "A  c" })
  MiniTest.expect.equality(H.git(root, "ls-files", "-z"), "c\0")
end
return T
