local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.writefile({ "base" }, root .. "/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "before")
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd("silent! only!")
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})

local function commit()
  H.git(root, "commit", "--allow-empty", "-m", "after")
end
local cases = {
  { "Log", "--oneline", commit },
  { "Reflog", "--oneline", commit },
  {
    "Branch",
    "",
    function()
      H.git(root, "branch", "after")
    end,
  },
  {
    "Tag",
    "",
    function()
      H.git(root, "tag", "after")
    end,
  },
  {
    "Stash",
    "",
    function()
      vim.fn.writefile({ "after" }, root .. "/file")
      H.git(root, "stash", "push", "-m", "after")
    end,
  },
  {
    "Status",
    "",
    function()
      vim.fn.writefile({ "after" }, root .. "/after")
    end,
  },
}
for _, case in ipairs(cases) do
  T["command events defer hidden " .. case[1] .. " refresh until entry"] = function()
    vim.cmd("Gin" .. case[1] .. " " .. case[2])
    local buf = vim.api.nvim_get_current_buf()
    local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.bo.bufhidden = "hide"
    vim.cmd.enew()
    case[3]()
    require("gin.command").post()
    H.drain()
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false), before)
    vim.api.nvim_set_current_buf(buf)
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    MiniTest.expect.equality(text:find("after", 1, true) ~= nil, true)
  end
  T["command events schedule visible " .. case[1] .. " refresh without stealing focus"] = function()
    vim.cmd("Gin" .. case[1] .. " " .. case[2])
    local buf = vim.api.nvim_get_current_buf()
    local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.cmd.vnew()
    local win = vim.api.nvim_get_current_win()
    case[3]()
    require("gin.command").post()
    MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false), before)
    H.drain()
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    MiniTest.expect.equality(text:find("after", 1, true) ~= nil, true)
    MiniTest.expect.equality(vim.api.nvim_get_current_win(), win)
  end
end

T["file writes defer hidden Status refresh until entry"] = function()
  vim.cmd.GinStatus()
  local buf = vim.api.nvim_get_current_buf()
  local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.bo.bufhidden = "hide"
  vim.cmd.edit(root .. "/file")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "after" })
  vim.cmd.write()
  H.drain()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false), before)
  vim.api.nvim_set_current_buf(buf)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 1, -1, false), { " M file" })
end

return T
