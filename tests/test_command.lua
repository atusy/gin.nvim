local H = require("tests.helpers")
local root
local old_cwd = vim.fn.getcwd()
local events
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.cmd.cd(root)
      events = 0
      vim.api.nvim_create_autocmd("User", {
        pattern = "GinCommandPost",
        group = vim.api.nvim_create_augroup("gin_test", { clear = true }),
        callback = function()
          events = events + 1
        end,
      })
      dofile(old_cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(old_cwd)
      H.cleanup(root)
      vim.api.nvim_del_augroup_by_name("gin_test")
    end,
  },
})
T["Gin wait executes a Git command and emits its completion event"] = function()
  vim.fn.writefile({ "literal" }, root .. "/space name")
  vim.cmd([[Gin ++wait add -- space\ name]])
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "space name\n")
  MiniTest.expect.equality(events, 1)
end
T["Gin dispatches asynchronously unless wait is requested"] = function()
  vim.fn.writefile({ "async" }, root .. "/async")
  local process = require("gin.command").execute({ fargs = { "add", "--", "async" }, smods = {} })
  MiniTest.expect.equality(type(process.wait), "function")
  MiniTest.expect.equality(
    vim.wait(5000, function()
      return events == 1
    end),
    true
  )
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "async\n")
end
T["Gin expands current file and respects silent"] = function()
  vim.fn.writefile({ "text" }, root .. "/file")
  vim.cmd.edit(vim.fn.fnameescape(root .. "/file"))
  vim.cmd("silent Gin ++wait add -- %:p")
  MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "file\n")
end
T["failed Gin does not publish a success event"] = function()
  MiniTest.expect.error(function()
    vim.cmd("Gin ++wait not-a-git-command")
  end, "git exited")
  MiniTest.expect.equality(events, 0)
end
T["directory commands use buffer repository and honor local scope"] = function()
  vim.fn.mkdir(root .. "/sub", "p")
  vim.fn.writefile({ "text" }, root .. "/sub/file")
  vim.cmd.cd(old_cwd)
  vim.cmd.edit(vim.fn.fnameescape(root .. "/sub/file"))
  vim.cmd.GinLcd()
  MiniTest.expect.equality(vim.fn.getcwd(), vim.uv.fs_realpath(root))
  MiniTest.expect.equality(vim.fn.haslocaldir(), 1)
end
T["Gin wait returns processed output and rejects processor failures"] = function()
  vim.fn.writefile({ "text" }, root .. "/file")
  local result = require("gin.command").execute({
    fargs = { "++wait", "++processor=tr a-z A-Z", "status", "--short" },
    smods = { silent = true },
  })
  MiniTest.expect.equality(result.stdout, "?? FILE\n")
  MiniTest.expect.equality(events, 1)
  MiniTest.expect.error(function()
    vim.cmd("Gin ++wait ++processor=false status")
  end, "processor exited")
  MiniTest.expect.equality(events, 1)
end
T["asynchronous Gin waits for processor completion before publishing success"] = function()
  vim.fn.writefile({ "text" }, root .. "/file")
  local command = require("gin.command")
  local original, received = command.finish, nil
  command.finish = function(result, options, mods)
    received = result.stdout
    return original(result, options, mods)
  end
  local ok, err = pcall(function()
    command.execute({
      fargs = { "++processor=tr a-z A-Z", "status", "--short" },
      smods = { silent = true },
    })
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return events == 1
      end),
      true
    )
  end)
  command.finish = original
  assert(ok, err)
  MiniTest.expect.equality(received, "?? FILE\n")
end
T["asynchronous processor failures report errors without success events"] = function()
  local original, received = vim.notify, nil
  vim.notify = function(message)
    received = message
  end
  local ok, err = pcall(function()
    require("gin.command").execute({ fargs = { "++processor=false", "status" }, smods = {} })
    MiniTest.expect.equality(
      vim.wait(5000, function()
        return received ~= nil
      end),
      true
    )
  end)
  vim.notify = original
  assert(ok, err)
  MiniTest.expect.equality(received:find("processor exited", 1, true) ~= nil, true)
  MiniTest.expect.equality(events, 0)
end

for _, spec in ipairs({
  { option = "++ff=unix", expected = "first\r\nsecond\r" },
  { option = "++fileformat=unix", expected = "first\r\nsecond\r" },
  { option = "++ff=dos", expected = "first\nsecond" },
  { option = "++ff=mac", expected = "first\n\nsecond\n" },
  { option = "", expected = "first\nsecond" },
}) do
  for _, wait in ipairs({ false, true }) do
    T["command output decoding " .. spec.option .. " wait=" .. tostring(wait)] = function()
      vim.fn.writefile({ "first\r", "second\r" }, root .. "/file")
      H.git(root, "add", "file")
      local echo = vim.api.nvim_echo
      local output
      vim.api.nvim_echo = function(chunks)
        output = chunks[1][1]
      end
      local ok, err = pcall(function()
        local args = { "show", ":file" }
        if spec.option ~= "" then
          table.insert(args, 1, spec.option)
        end
        if wait then
          table.insert(args, 1, "++wait")
        end
        require("gin.command").execute({ fargs = args, smods = {} })
        MiniTest.expect.equality(
          vim.wait(5000, function()
            return events == 1
          end, 10),
          true
        )
        MiniTest.expect.equality(output, spec.expected)
      end)
      vim.api.nvim_echo = echo
      assert(ok, err)
    end
  end
end

for _, view in ipairs({ "GinDiff", "GinLog --oneline" }) do
  for _, absolute in ipairs({ false, true }) do
    T["filename expansion from " .. view .. " absolute=" .. tostring(absolute)] = function()
      vim.fn.writefile({ "base" }, root .. "/one space")
      vim.fn.writefile({ "base" }, root .. "/two")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      vim.fn.writefile({ "changed" }, root .. "/one space")
      vim.fn.writefile({ "changed" }, root .. "/two")
      local path = absolute and (root .. "/one space") or "one space"
      vim.cmd(view .. " -- " .. vim.fn.fnameescape(path) .. " two")
      vim.cmd("Gin ++wait add -- %")
      MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "one space\n")
      MiniTest.expect.equality(H.git(root, "show", ":one space"), "changed\n")
      MiniTest.expect.equality(H.git(root, "show", ":two"), "base\n")
    end
  end
end

for _, view in ipairs({ "GinDiff", "GinLog --oneline" }) do
  T[view .. " keeps repository-relative filters and alternate filename expansion"] = function()
    vim.fn.writefile({ "root base" }, root .. "/file")
    H.git(root, "add", "file")
    H.git(root, "commit", "-m", "root file")
    local first = vim.trim(H.git(root, "rev-parse", "HEAD"))
    vim.fn.mkdir(root .. "/sub", "p")
    vim.fn.writefile({ "sub base" }, root .. "/sub/file")
    H.git(root, "add", "sub/file")
    H.git(root, "commit", "-m", "sub file")
    vim.fn.writefile({ "root changed" }, root .. "/file")
    vim.fn.writefile({ "sub changed" }, root .. "/sub/file")
    vim.cmd.cd(root .. "/sub")
    vim.cmd(view .. " -- file")
    vim.cmd.edit()
    if view == "GinDiff" then
      local output = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
      MiniTest.expect.equality(output:find("+root changed", 1, true) ~= nil, true)
      MiniTest.expect.equality(output:find("sub changed", 1, true), nil)
    else
      local rows = require("gin.log").candidates(0, { 1, 99 })
      MiniTest.expect.equality(#rows, 1)
      MiniTest.expect.equality(rows[1].commit, first:sub(1, #rows[1].commit))
    end
    vim.cmd.enew()
    vim.cmd("Gin ++wait add -- #")
    MiniTest.expect.equality(H.git(root, "diff", "--cached", "--name-only"), "file\n")
    MiniTest.expect.equality(H.git(root, "show", ":file"), "root changed\n")
    MiniTest.expect.equality(H.git(root, "show", ":sub/file"), "sub base\n")
    MiniTest.expect.equality(vim.fn.readfile(root .. "/sub/file"), { "sub changed" })
  end
end
return T
