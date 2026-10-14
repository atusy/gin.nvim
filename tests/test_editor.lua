local H = require("tests.helpers")
local cwd = vim.fn.getcwd()
local root, hidden, listen_address
local input = vim.fn.input
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      listen_address = vim.env.NVIM_LISTEN_ADDRESS
      hidden = vim.o.hidden
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
      vim.env.NVIM_LISTEN_ADDRESS = listen_address
      vim.o.hidden = hidden
      vim.g.gin_proxy_apply_without_confirm = nil
      vim.g.gin_proxy_editor_opener = nil
      vim.fn.input = input
      vim.cmd("silent! tabonly!")
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
for _, value in ipairs({ false, 0, vim.NIL, {}, "unsupported" }) do
  T["invalid editor opener " .. vim.inspect(value) .. " releases Git without opening a window"] = function()
    vim.g.gin_proxy_editor_opener = value
    local windows, tabs = vim.api.nvim_list_wins(), vim.api.nvim_list_tabpages()
    local process = require("gin.command").execute({
      fargs = { "commit" },
      smods = { silent = true, emsg_silent = true },
    })
    local finished = vim.wait(3000, function()
      return process:is_closing()
    end, 10)
    -- Release an incorrectly opened editor before asserting the failure.
    if not finished and vim.b.gin_editor_request then
      vim.cmd.Cancel()
      assert(vim.wait(3000, function()
        return process:is_closing()
      end, 10))
    end
    MiniTest.expect.equality(finished, true)
    local result = process:wait(3000)
    MiniTest.expect.equality(result.code ~= 0, true)
    local message = type(value) == "string" and "Unsupported Gin opener"
      or "g:gin_proxy_editor_opener must be a string"
    MiniTest.expect.equality(result.stderr:find(message, 1, true) ~= nil, true)
    MiniTest.expect.equality(vim.api.nvim_list_wins(), windows)
    MiniTest.expect.equality(vim.api.nvim_list_tabpages(), tabs)
    MiniTest.expect.equality(H.git(root, "show", ":file"), "content\n")
    MiniTest.expect.equality(H.git(root, "diff", "--name-only", "--cached"), "file\n")
  end
end
T["edit opener failure preserves unsaved work and releases Git"] = function()
  vim.g.gin_proxy_editor_opener = "edit"
  vim.o.hidden = false
  vim.cmd.edit(root .. "/file")
  local buf = vim.api.nvim_get_current_buf()
  local windows, tabs = vim.api.nvim_list_wins(), vim.api.nvim_list_tabpages()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved work" })
  local process = require("gin.command").execute({
    fargs = { "commit" },
    smods = { silent = true, emsg_silent = true },
  })
  local finished = vim.wait(3000, function()
    return process:is_closing()
  end, 10)
  if not finished and vim.b.gin_editor_request then
    vim.cmd.Cancel()
    assert(vim.wait(3000, function()
      return process:is_closing()
    end, 10))
  end
  MiniTest.expect.equality(finished, true)
  local result = process:wait(3000)
  MiniTest.expect.equality(result.code ~= 0, true)
  MiniTest.expect.equality(result.stderr:find("E37", 1, true) ~= nil, true)
  MiniTest.expect.equality(vim.api.nvim_get_current_buf(), buf)
  MiniTest.expect.equality(vim.api.nvim_list_wins(), windows)
  MiniTest.expect.equality(vim.api.nvim_list_tabpages(), tabs)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "unsaved work" })
  MiniTest.expect.equality(vim.bo[buf].modified, true)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/file"), { "content" })
  MiniTest.expect.equality(H.git(root, "show", ":file"), "content\n")
  MiniTest.expect.equality(H.git(root, "diff", "--name-only", "--cached"), "file\n")
end
T["opening an editor request suppresses file-read messages"] = function()
  local path = root .. "/message"
  vim.fn.writefile({ "draft" }, path)
  local script = string.format(
    [[
    vim.opt.rtp:prepend(%s)
    vim.opt.shortmess:remove("F")
    local editor = require("gin.editor")
    local id = editor.request(%s)
    assert(vim.wait(1000, function() return vim.b.gin_editor_request == id end, 10))
    vim.cmd.Cancel()
    assert(editor.poll(id).accepted == false)
    vim.cmd.qa({ bang = true })
  ]],
    vim.inspect(cwd),
    vim.inspect(path)
  )
  local script_path = root .. "/probe.lua"
  vim.fn.writefile(vim.split(script, "\n", { plain = true }), script_path)
  local result =
    vim.system({ vim.v.progpath, "--headless", "--clean", "-l", script_path }):wait(5000)
  MiniTest.expect.equality(result.code, 0)
  MiniTest.expect.equality({ result.stdout, result.stderr }, { "", "" })
end
for _, inherited in ipairs({ false, true }) do
  T["Git commit waits for Apply and records the edited message (explicit listener=" .. tostring(
    inherited
  ) .. ")"] = function()
    if inherited then
      vim.env.NVIM_LISTEN_ADDRESS = require("gin.editor").environment().GIN_EDITOR_ADDRESS
    end
    local completed = false
    local event = vim.api.nvim_create_autocmd("User", {
      pattern = "GinCommandPost",
      once = true,
      callback = function()
        completed = true
      end,
    })
    local process
    if inherited then
      local env = require("gin.editor").environment()
      env.NVIM_LISTEN_ADDRESS = vim.env.NVIM_LISTEN_ADDRESS
      process = require("gin.git").start({ "commit" }, { cwd = root, env = env }, function()
        completed = true
      end)
    else
      process = require("gin.command").execute({ fargs = { "commit" }, smods = { silent = true } })
    end
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return vim.b.gin_editor_request ~= nil
      end, 10),
      true
    )
    MiniTest.expect.equality(
      vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t"),
      "COMMIT_EDITMSG"
    )
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
    if inherited then
      MiniTest.expect.equality(
        vim.env.NVIM_LISTEN_ADDRESS,
        require("gin.editor").environment().GIN_EDITOR_ADDRESS
      )
    end
  end
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
T["synchronous progress commands service editor requests before returning"] = function()
  local timer = vim.uv.new_timer()
  timer:start(
    10,
    10,
    vim.schedule_wrap(function()
      if vim.b.gin_editor_request then
        timer:stop()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "synchronous proxy commit" })
        vim.cmd.Apply()
      end
    end)
  )
  local ok, result = pcall(require("gin.git").run, { "commit" }, {
    cwd = root,
    progress = true,
    timeout = 5000,
  })
  timer:stop()
  timer:close()
  assert(ok, result)
  MiniTest.expect.equality(result.code, 0)
  MiniTest.expect.equality(H.git(root, "log", "-1", "--format=%s"), "synchronous proxy commit\n")
  MiniTest.expect.equality(H.git(root, "show", "HEAD:file"), "content\n")
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
for _, case in ipairs({
  { "unset" },
  { "false", false },
  { "zero", 0 },
  { "null", vim.NIL },
  { "string zero", "0" },
  { "empty string", "" },
  { "nonnumeric string", "true" },
}) do
  T["declining quit confirmation with " .. case[1] .. " cancels Git and preserves staged content"] = function()
    vim.g.gin_proxy_apply_without_confirm = case[2]
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
