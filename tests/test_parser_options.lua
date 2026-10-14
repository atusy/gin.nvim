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
      H.drain()
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
for _, case in ipairs({
  { "log", "GinLog --format=pick:%H", [[^pick:(\w+)$]], "yank:commit" },
  { "reflog", "GinReflog --format=pick:%H", [[^pick:(\w+)$]], "yank:commit" },
  {
    "tag",
    "GinTag --format=pick:%(objectname):chosen",
    [[^pick:(\w+):(.+)$]],
    "yank:tag",
    "chosen",
  },
  {
    "stash",
    "GinStash --format=pick:stash@{42}",
    [[^pick:(stash@\{(\d+)\})$]],
    "yank:stash",
    "stash@{42}",
  },
}) do
  T[case[1] .. " actions consume custom captures from displayed lines"] = function()
    vim.cmd(case[2])
    vim.g["gin_" .. case[1] .. "_parse_pattern"] = case[3]
    require("gin.action").call(vim.api.nvim_get_current_buf(), case[4], { 1, 1 })
    MiniTest.expect.equality(
      vim.fn.getreg('"'),
      case[5] or vim.trim(H.git(root, "rev-parse", "HEAD"))
    )
  end
end
for _, case in ipairs({
  { "log", "GinLog", "yank:commit" },
  { "reflog", "GinReflog", "yank:commit" },
  { "tag", "GinTag", "delete" },
  { "stash", "GinStash", "drop" },
}) do
  T[case[1] .. " does not fall back after custom errors or no-match"] = function()
    vim.cmd(case[2])
    local buf = vim.api.nvim_get_current_buf()
    local refs = H.git(root, "show-ref")
    local setting = "gin_" .. case[1] .. "_parse_pattern"
    vim.fn.setreg('"', "untouched")
    vim.g[setting] = "("
    MiniTest.expect.error(function()
      require("gin.action").call(buf, case[3], { 1, 1 })
    end)
    MiniTest.expect.equality(vim.fn.getreg('"'), "untouched")
    MiniTest.expect.equality(H.git(root, "show-ref"), refs)
    vim.g[setting] = "^(never-matches-this-row)$"
    require("gin.action").call(buf, case[3], { 1, 1 })
    H.drain()
    MiniTest.expect.equality(H.git(root, "show-ref"), refs)
    MiniTest.expect.equality(H.git(root, "status", "--porcelain"), "")
    if case[3] == "yank:commit" then
      MiniTest.expect.equality(vim.fn.getreg('"'), "")
    end
  end
end
T["tag deletion uses the custom tag instead of row metadata"] = function()
  H.git(root, "tag", "victim")
  vim.cmd("GinTag --format=%(objectname):victim keep")
  vim.g.gin_tag_parse_pattern = [[^(\w+):(.+)$]]
  require("gin.action").call(vim.api.nvim_get_current_buf(), "delete", { 1, 1 })
  H.drain()
  MiniTest.expect.equality(H.git(root, "tag", "--list"), "keep\n")
end
T["stash drop uses the custom reference instead of row metadata"] = function()
  vim.fn.writefile({ "second" }, root .. "/file")
  H.git(root, "stash", "push", "-m", "second")
  local newest = vim.trim(H.git(root, "rev-parse", "stash@{0}"))
  vim.cmd("GinStash --format=pick:stash@{1}")
  vim.g.gin_stash_parse_pattern = [[^pick:(stash@\{(\d+)\})$]]
  require("gin.action").call(vim.api.nvim_get_current_buf(), "drop", { 1, 1 })
  H.drain()
  MiniTest.expect.equality(H.git(root, "stash", "list", "--format=%H"), newest .. "\n")
end
T["custom parsing preserves blank filtering, duplicate rows and missing captures"] = function()
  vim.cmd("GinLog")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "", "β😀", "β😀" })
  vim.bo[buf].modifiable = false
  vim.g.gin_log_parse_pattern = [[^(\S+)$]]
  MiniTest.expect.equality(require("gin.log").candidates(buf, { 1, 3 }), {
    { commit = "β😀" },
    { commit = "β😀" },
  })
  vim.g.gin_log_parse_pattern = ""
  MiniTest.expect.equality(require("gin.log").candidates(buf, { 1, 3 }), { {}, {} })
  require("gin.action").call(buf, "yank:commit", { 1, 3 })
  MiniTest.expect.equality(vim.fn.getreg('"'), "\n")
  local echoed = vim.api.nvim_exec2(
    "lua require('gin.action').call(vim.api.nvim_get_current_buf(), 'echo', {1, 3})",
    { output = true }
  ).output
  MiniTest.expect.equality(echoed, "[\n  {},\n  {}\n]")
end
T["stash custom index follows decimal prefix parsing"] = function()
  vim.cmd("GinStash --format=ref:idx")
  local buf = vim.api.nvim_get_current_buf()
  vim.g.gin_stash_parse_pattern = [[^(ref):(idx)$]]
  local result = require("gin.candidate").custom(buf, { 1, 1 }, "stash")
  MiniTest.expect.equality(result[1].stashRef, "ref")
  MiniTest.expect.equality(result[1].index, vim.NIL)
  local echoed = vim.api.nvim_exec2(
    "lua require('gin.action').call(vim.api.nvim_get_current_buf(), 'echo', {1, 1})",
    { output = true }
  ).output
  MiniTest.expect.equality(echoed:find('"index": null', 1, true) ~= nil, true)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ref:　-12tail" })
  vim.bo[buf].modifiable = false
  vim.g.gin_stash_parse_pattern = [[^(ref):(.*)$]]
  MiniTest.expect.equality(require("gin.candidate").custom(buf, { 1, 1 }, "stash"), {
    { stashRef = "ref", commit = "ref", index = -12 },
  })
end
for _, case in ipairs({
  { "log", "GinLog", "reset:hard" },
  { "reflog", "GinReflog", "reset:hard" },
  { "tag", "GinTag", "delete" },
  { "stash", "GinStash", "drop" },
}) do
  T[case[1] .. " refuses mutation when the required custom capture is absent"] = function()
    vim.cmd(case[2])
    local refs = H.git(root, "show-ref")
    vim.fn.writefile({ "local changes" }, root .. "/file")
    local status = H.git(root, "status", "--porcelain")
    vim.g["gin_" .. case[1] .. "_parse_pattern"] = ".*"
    MiniTest.expect.error(function()
      require("gin.action").call(vim.api.nvim_get_current_buf(), case[3], { 1, 1 })
    end)
    MiniTest.expect.error(function()
      require("gin.action").call(vim.api.nvim_get_current_buf(), "browse:commit:yank", { 1, 1 })
    end, "Missing custom parser capture")
    H.drain()
    MiniTest.expect.equality(H.git(root, "show-ref"), refs)
    MiniTest.expect.equality(H.git(root, "status", "--porcelain"), status)
    MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "local changes" })
  end
end
return T
