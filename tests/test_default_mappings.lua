local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.writefile({ "one", "two", "three" }, root .. "/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      H.git(root, "tag", "release")
      vim.fn.writefile({ "changed" }, root .. "/file")
      H.git(root, "stash", "push", "-m", "saved")
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd("setlocal foldmethod< foldenable< foldlevel<")
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
for _, command in ipairs({ "GinStatus", "GinLog", "GinReflog", "GinTag", "GinStash" }) do
  for _, input in ipairs({ "<CR>", "V<CR>" }) do
    T[command .. " " .. input .. " reveals the destination inside a fold"] = function()
      vim.cmd(command)
      local list = vim.api.nvim_get_current_buf()
      local name = command == "GinStatus" and "edit" or "show"
      local target = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(target, 0, -1, false, { "one", "two", "three" })
      require("gin.action").define(list, name, function()
        vim.api.nvim_set_current_buf(target)
        vim.wo.foldmethod = "manual"
        vim.wo.foldenable = true
        vim.cmd("1,3fold")
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        MiniTest.expect.equality(vim.fn.foldclosed(2), 1)
      end)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(input, true, false, true), "mx", false)
      MiniTest.expect.equality(vim.api.nvim_get_current_buf(), target)
      MiniTest.expect.equality(vim.fn.foldclosed(2), -1)
      vim.bo[target].modified = false
      vim.api.nvim_buf_call(list, function()
        for _, mode in ipairs({ "n", "x" }) do
          MiniTest.expect.equality(
            vim.fn.maparg("<CR>", mode),
            "<Plug>(gin-action-" .. name .. ")zv"
          )
        end
      end)
    end
  end
end
return T
