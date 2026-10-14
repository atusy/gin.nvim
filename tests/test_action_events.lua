local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.writefile({ "base" }, root .. "/file")
      H.git(root, "add", "file")
      H.git(root, "commit", "-m", "initial")
      H.git(root, "branch", "topic")
      H.git(root, "tag", "release")
      vim.fn.writefile({ "saved" }, root .. "/file")
      H.git(root, "stash", "push", "-m", "saved")
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
local specs = {
  {
    command = "GinStatus",
    action = "add",
    verify = function()
      MiniTest.expect.equality(H.git(root, "show", ":new-file"), "new\n")
    end,
  },
  {
    command = "GinBranch topic",
    action = "delete",
    verify = function()
      MiniTest.expect.equality(H.git(root, "branch", "--list", "topic"), "")
    end,
  },
  {
    command = "GinTag release",
    action = "delete",
    verify = function()
      MiniTest.expect.equality(H.git(root, "tag", "--list", "release"), "")
    end,
  },
  {
    command = "GinStash",
    action = "drop",
    verify = function()
      MiniTest.expect.equality(H.git(root, "stash", "list"), "")
    end,
  },
}
for _, command in ipairs({ "GinLog --oneline", "GinReflog" }) do
  specs[#specs + 1] = {
    command = command,
    action = "tag:lightweight",
    verify = function()
      MiniTest.expect.equality(
        H.git(root, "rev-parse", "created"),
        H.git(root, "rev-parse", "HEAD")
      )
    end,
  }
end
for _, spec in ipairs(specs) do
  for _, suppress in ipairs({ false, true }) do
    T[spec.command .. " completion suppression=" .. tostring(suppress)] = function()
      vim.fn.writefile({ "new" }, root .. "/new-file")
      vim.cmd(spec.command)
      H.drain()
      local count = 0
      local autocmd = vim.api.nvim_create_autocmd("User", {
        pattern = "GinCommandPost",
        callback = function()
          count = count + 1
        end,
      })
      local ignored, input = vim.o.eventignore, vim.ui.input
      vim.ui.input = function(_, callback)
        callback("created")
      end
      local ok, err = pcall(function()
        vim.o.eventignore = suppress and "all" or ""
        local line = spec.command == "GinStatus" and 2 or 1
        require("gin.action").call(vim.api.nvim_get_current_buf(), spec.action, { line, line })
        vim.o.eventignore = ignored
        H.drain()
        MiniTest.expect.equality(count, suppress and 0 or 1)
        spec.verify()
      end)
      vim.o.eventignore, vim.ui.input = ignored, input
      vim.api.nvim_del_autocmd(autocmd)
      assert(ok, err)
    end
  end
end
return T
