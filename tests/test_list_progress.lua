local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.writefile({ "progress-payload" }, root .. "/progress-payload")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "progress-payload")
      H.git(root, "tag", "progress-payload")
      H.git(root, "branch", "progress-payload")
      vim.fn.writefile({ "stashed" }, root .. "/progress-payload")
      H.git(root, "stash", "push", "-m", "progress-payload")
      vim.fn.writefile({ "changed" }, root .. "/progress-payload")
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})

for _, kind in ipairs({ "Diff", "Log", "Reflog", "Branch", "Tag", "Stash", "Status" }) do
  T[kind .. " displays stderr without echoing listing contents"] = function()
    local trace, echo = vim.env.GIT_TRACE, vim.api.nvim_echo
    local more, height = vim.o.more, vim.o.cmdheight
    local output = {}
    vim.env.GIT_TRACE = "1"
    vim.api.nvim_echo = function(chunks)
      output[#output + 1] = chunks[1][1]
    end
    local ok, err = pcall(vim.cmd, "Gin" .. kind)
    vim.env.GIT_TRACE, vim.api.nvim_echo = trace, echo
    assert(ok, err)
    local progress = table.concat(output, "\n")
    MiniTest.expect.equality(progress:find("built-in: git " .. kind:lower(), 1, true) ~= nil, true)
    MiniTest.expect.equality(progress:find("progress-payload", 1, true), nil)
    local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    MiniTest.expect.equality(content:find("progress-payload", 1, true) ~= nil, true)
    MiniTest.expect.equality({ vim.o.more, vim.o.cmdheight }, { more, height })
  end
end
for _, kind in ipairs({ "Diff", "Log", "Reflog", "Tag", "Stash" }) do
  T["reading " .. kind .. " streams both channels without private metadata"] = function()
    vim.cmd("Gin" .. kind)
    local name = vim.api.nvim_buf_get_name(0)
    vim.cmd.enew()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
    local trace, echo = vim.env.GIT_TRACE, vim.api.nvim_echo
    local output = {}
    vim.env.GIT_TRACE = "1"
    vim.api.nvim_echo = function(chunks)
      output[#output + 1] = chunks[1][1]
    end
    local ok, err = pcall(vim.api.nvim_cmd, {
      cmd = "read",
      range = { 1 },
      args = { vim.fn.fnameescape(name) },
    }, {})
    vim.env.GIT_TRACE, vim.api.nvim_echo = trace, echo
    assert(ok, err)
    local progress = table.concat(output, "\n")
    MiniTest.expect.equality(progress:find("built-in: git " .. kind:lower(), 1, true) ~= nil, true)
    MiniTest.expect.equality(progress:find("progress-payload", 1, true) ~= nil, true)
    MiniTest.expect.equality(progress:find("\0", 1, true), nil)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    MiniTest.expect.equality({ lines[1], lines[#lines] }, { "before", "after" })
    local content = table.concat(lines, "\n")
    MiniTest.expect.equality(content:find("progress-payload", 1, true) ~= nil, true)
    MiniTest.expect.equality(content:find("trace:", 1, true), nil)
  end
end
return T
