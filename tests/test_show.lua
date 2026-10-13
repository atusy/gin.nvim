local H = require("tests.helpers")
local root, commit
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.writefile({ "content" }, root .. "/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", ":sparkles: selected")
      commit = vim.trim(H.git(root, "rev-parse", "HEAD"))
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd("silent! tabonly!")
      vim.cmd("silent! only!")
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
for _, view in ipairs({ "GinLog --oneline", "GinReflog --oneline", "GinTag", "GinStash" }) do
  for _, opener in ipairs({ "", "edit", "split", "vsplit", "tabedit" }) do
    T[view .. " show emojify opener=" .. opener] = function()
      if view == "GinTag" then
        H.git(root, "tag", "selected")
      elseif view == "GinStash" then
        vim.fn.writefile({ "changed" }, root .. "/file")
        H.git(root, "stash", "push", "-m", ":sparkles: selected")
        commit = vim.trim(H.git(root, "rev-parse", "stash"))
      end
      vim.cmd(view)
      local action = "show:" .. (opener ~= "" and (opener .. ":") or "") .. "emojify"
      require("gin.action").call(vim.api.nvim_get_current_buf(), action, { 1, 1 })
      MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), opener == "tabedit" and 2 or 1)
      MiniTest.expect.equality(
        #vim.api.nvim_tabpage_list_wins(0),
        (opener == "split" or opener == "vsplit") and 2 or 1
      )
      for _ = 1, 2 do
        local output = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
        MiniTest.expect.equality(output:find(commit, 1, true) ~= nil, true)
        MiniTest.expect.equality(output:find("✨ selected", 1, true) ~= nil, true)
        MiniTest.expect.equality(output:find(":sparkles:", 1, true), nil)
        vim.cmd.edit()
      end
    end
  end
end
return T
