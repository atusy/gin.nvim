local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local kinds = { "log", "reflog", "tag", "stash" }
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.writefile({ "base" }, root .. "/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      H.git(root, "tag", "keep")
      vim.fn.writefile({ "saved" }, root .. "/file")
      H.git(root, "stash", "push", "-m", "keep")
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      for _, kind in ipairs(kinds) do
        vim.g["gin_" .. kind .. "_parse_pattern"] = nil
      end
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
for _, case in ipairs({
  { "log", "GinLog --format=%H", "yank:commit" },
  { "reflog", "GinReflog --format=%H", "yank:commit" },
  { "tag", "GinTag", "delete" },
  { "stash", "GinStash", "drop" },
}) do
  T[case[1] .. " validates custom parser types before acting on candidates"] = function()
    vim.cmd(case[2])
    local refs = H.git(root, "show-ref")
    local register = vim.fn.getreg('"')
    local setting = "gin_" .. case[1] .. "_parse_pattern"
    for _, value in ipairs({ 1, true, {} }) do
      vim.g[setting] = value
      MiniTest.expect.error(function()
        require("gin.action").call(vim.api.nvim_get_current_buf(), case[3], { 1, 1 })
      end, "g:" .. setting .. " must be string")
      MiniTest.expect.equality(H.git(root, "show-ref"), refs)
      MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
      MiniTest.expect.equality(vim.fn.getreg('"'), register)
    end
  end
end
return T
