local H = require("tests.helpers")
local cwd = vim.fn.getcwd()
local root
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
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
return T
