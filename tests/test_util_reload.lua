local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.only({ bang = true })
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
local function drain()
  local done = false
  vim.schedule(function()
    done = true
  end)
  assert(vim.wait(1000, function()
    return done
  end, 10))
end

T["reload defaults to the current Git view and runs asynchronously"] = function()
  vim.fn.writefile({ "a" }, root .. "/a")
  vim.cmd.GinStatus()
  vim.fn.writefile({ "b" }, root .. "/b")
  require("gin.util").reload()
  MiniTest.expect.equality(vim.api.nvim_buf_line_count(0), 2)
  drain()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 1, -1, false), { "?? a", "?? b" })
end
T["reload refreshes another visible buffer without changing focus"] = function()
  vim.fn.writefile({ "before" }, root .. "/file")
  vim.cmd.edit(root .. "/file")
  local target = vim.api.nvim_get_current_buf()
  vim.cmd.vnew()
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  vim.fn.writefile({ "after" }, root .. "/file")
  require("gin.util").reload(target)
  drain()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(target, 0, -1, false), { "after" })
  MiniTest.expect.equality(
    { vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf() },
    { win, buf }
  )
end
T["hidden reload requests coalesce and execute once on entry"] = function()
  vim.fn.writefile({ "before" }, root .. "/file")
  vim.cmd.edit(root .. "/file")
  local target = vim.api.nvim_get_current_buf()
  vim.bo.bufhidden = "hide"
  vim.bo.autoread = false
  vim.cmd.enew()
  local other = vim.api.nvim_get_current_buf()
  vim.fn.writefile({ "after" }, root .. "/file")
  require("gin.util").reload(target)
  require("gin.util").reload(target)
  drain()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(target, 0, -1, false), { "before" })
  vim.api.nvim_set_current_buf(target)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(target, 0, -1, false), { "after" })
  vim.api.nvim_set_current_buf(other)
  vim.fn.writefile({ "later" }, root .. "/file")
  vim.api.nvim_create_autocmd("FileChangedShell", {
    buffer = target,
    once = true,
    callback = function()
      vim.v.fcs_choice = ""
    end,
  })
  vim.api.nvim_set_current_buf(target)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(target, 0, -1, false), { "after" })
end
T["reload reports modified buffers without discarding edits"] = function()
  vim.fn.writefile({ "before" }, root .. "/file")
  vim.cmd.edit(root .. "/file")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
  local original = vim.notify
  local messages = {}
  vim.notify = function(message, level)
    messages[#messages + 1] = { message, level }
  end
  require("gin.util").reload()
  drain()
  vim.notify = original
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "unsaved" })
  MiniTest.expect.equality(vim.bo.modified, true)
  MiniTest.expect.equality(#messages, 1)
  MiniTest.expect.equality(messages[1][2], vim.log.levels.ERROR)
  MiniTest.expect.equality(messages[1][1]:find("E37", 1, true) ~= nil, true)
end
T["reload ignores a buffer wiped before the scheduled request"] = function()
  local target = vim.api.nvim_create_buf(false, true)
  require("gin.util").reload(target)
  vim.api.nvim_buf_delete(target, { force = true })
  drain()
  MiniTest.expect.equality(vim.api.nvim_buf_is_valid(target), false)
end
return T
