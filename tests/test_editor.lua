local H = require("tests.helpers")
local cwd = vim.fn.getcwd()
local root
local input = vim.fn.input
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      vim.cmd("filetype plugin on")
      root = H.repo()
      H.git(root, "config", "user.name", "Gin Test")
      H.git(root, "config", "user.email", "gin@example.invalid")
      H.git(root, "config", "core.editor", "false")
      vim.fn.writefile({ "content" }, root .. "/file")
      H.git(root, "add", ".")
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.g.gin_proxy_apply_without_confirm = nil
      vim.fn.input = input
      vim.cmd("silent! tabonly!")
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
T["Gin commit waits for Apply and records the edited message"] = function()
  local completed = false
  local event = vim.api.nvim_create_autocmd("User", {
    pattern = "GinCommandPost",
    once = true,
    callback = function()
      completed = true
    end,
  })
  local process =
    require("gin.command").execute({ fargs = { "commit" }, smods = { silent = true } })
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  MiniTest.expect.equality(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t"), "COMMIT_EDITMSG")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "message from Neovim" })
  vim.cmd.Apply()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return completed
    end, 10),
    true
  )
  MiniTest.expect.equality(process:wait(5000).code, 0)
  pcall(vim.api.nvim_del_autocmd, event)
  MiniTest.expect.equality(H.git(root, "log", "-1", "--format=%s"), "message from Neovim\n")
  MiniTest.expect.equality(H.git(root, "show", "HEAD:file"), "content\n")
end
T["Gin wait services editor requests before returning the commit result"] = function()
  local timer = vim.uv.new_timer()
  timer:start(
    10,
    10,
    vim.schedule_wrap(function()
      if vim.b.gin_editor_request then
        timer:stop()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "message while waiting" })
        vim.cmd.Apply()
      end
    end)
  )
  local ok, result = pcall(require("gin.command").execute, {
    fargs = { "++wait", "commit" },
    smods = { silent = true },
  })
  timer:stop()
  timer:close()
  MiniTest.expect.equality(ok, true)
  MiniTest.expect.equality(result.code, 0)
  MiniTest.expect.equality(H.git(root, "log", "-1", "--format=%s"), "message while waiting\n")
  MiniTest.expect.equality(H.git(root, "show", "HEAD:file"), "content\n")
end
T["synchronous editor failure preserves the index without a success event"] = function()
  local previous = vim.g.gin_proxy_disable_editor
  vim.g.gin_proxy_disable_editor = 1
  local events = 0
  local id = vim.api.nvim_create_autocmd("User", {
    pattern = "GinCommandPost",
    callback = function()
      events = events + 1
    end,
  })
  local ok, err = pcall(require("gin.command").execute, {
    fargs = { "++wait", "commit" },
    smods = { silent = true },
  })
  vim.g.gin_proxy_disable_editor = previous
  vim.api.nvim_del_autocmd(id)
  MiniTest.expect.equality(ok, false)
  MiniTest.expect.equality(tostring(err):find("false", 1, true) ~= nil, true)
  MiniTest.expect.equality(events, 0)
  MiniTest.expect.equality(require("gin.git").run({ "rev-parse", "--verify", "HEAD" }, {
    cwd = root,
    check = false,
  }).code ~= 0, true)
  MiniTest.expect.equality(H.git(root, "show", ":file"), "content\n")
end
T["Cancel rejects the commit and leaves staged content intact"] = function()
  local process = require("gin.command").execute({
    fargs = { "commit" },
    smods = { silent = true, emsg_silent = true },
  })
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "do not commit" })
  vim.cmd.Cancel()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return process:is_closing()
    end, 10),
    true
  )
  MiniTest.expect.equality(process:wait(5000).code ~= 0, true)
  MiniTest.expect.equality(
    require("gin.git").run({ "rev-parse", "--verify", "HEAD" }, { cwd = root, check = false }).code
      ~= 0,
    true
  )
  MiniTest.expect.equality(H.git(root, "show", ":file"), "content\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/.git/COMMIT_EDITMSG"), {})
end
T["quit applies a Git editor when confirmation is disabled"] = function()
  vim.g.gin_proxy_apply_without_confirm = 1
  local process = require("gin.command").execute({
    fargs = { "commit" },
    smods = { silent = true, emsg_silent = true },
  })
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "applied on quit" })
  vim.cmd.quit()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return process:is_closing()
    end, 10),
    true
  )
  MiniTest.expect.equality(process:wait(5000).code, 0)
  MiniTest.expect.equality(H.git(root, "log", "-1", "--format=%s"), "applied on quit\n")
end
T["declining quit confirmation cancels Git and preserves staged content"] = function()
  local prompts = {}
  vim.fn.input = function(options)
    prompts[#prompts + 1] = options
    return "no"
  end
  local process = require("gin.command").execute({
    fargs = { "commit" },
    smods = { silent = true, emsg_silent = true },
  })
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "declined" })
  vim.cmd.quit()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return process:is_closing()
    end, 10),
    true
  )
  MiniTest.expect.equality(process:wait(5000).code ~= 0, true)
  MiniTest.expect.equality(#prompts, 1)
  MiniTest.expect.equality(prompts[1].cancelreturn, "no")
  MiniTest.expect.equality(H.git(root, "show", ":file"), "content\n")
  MiniTest.expect.equality(vim.fn.readfile(root .. "/.git/COMMIT_EDITMSG"), {})
end
T["accepting the default quit answer writes and commits the message"] = function()
  local prompted = false
  vim.fn.input = function()
    prompted = true
    return ""
  end
  local process = require("gin.command").execute({
    fargs = { "commit" },
    smods = { silent = true, emsg_silent = true },
  })
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "confirmed on quit" })
  vim.cmd.quit()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return process:is_closing()
    end, 10),
    true
  )
  MiniTest.expect.equality(process:wait(5000).code, 0)
  MiniTest.expect.equality(prompted, true)
  MiniTest.expect.equality(H.git(root, "log", "-1", "--format=%s"), "confirmed on quit\n")
end
T["Accept uses the commit filetype alias and releases Git"] = function()
  vim.g.gin_proxy_apply_without_confirm = 1
  local process = require("gin.command").execute({
    fargs = { "commit" },
    smods = { silent = true, emsg_silent = true },
  })
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  MiniTest.expect.equality(vim.bo.filetype, "gitcommit")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "accepted through alias" })
  vim.cmd.Accept()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return process:is_closing()
    end, 10),
    true
  )
  MiniTest.expect.equality(process:wait(5000).code, 0)
  MiniTest.expect.equality(H.git(root, "log", "-1", "--format=%s"), "accepted through alias\n")
end
T["failed Apply keeps the editor request usable for a successful retry"] = function()
  local process = require("gin.command").execute({
    fargs = { "commit" },
    smods = { silent = true, emsg_silent = true },
  })
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return vim.b.gin_editor_request ~= nil
    end, 10),
    true
  )
  local request = vim.b.gin_editor_request
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "retried message" })
  vim.bo.readonly = true
  MiniTest.expect.error(function()
    vim.cmd.Apply()
  end, "E45")
  MiniTest.expect.equality(vim.b.gin_editor_request, request)
  MiniTest.expect.equality(vim.bo.modified, true)
  MiniTest.expect.equality(process:is_closing(), false)
  vim.bo.readonly = false
  vim.cmd.Apply()
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return process:is_closing()
    end, 10),
    true
  )
  MiniTest.expect.equality(process:wait(5000).code, 0)
  MiniTest.expect.equality(H.git(root, "log", "-1", "--format=%s"), "retried message\n")
end
return T
