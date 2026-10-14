local H = require("tests.helpers")
local root
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.writefile({ "one", "two", "three" }, root .. "/file")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      H.git(root, "tag", "release")
      vim.fn.writefile({ "changed" }, root .. "/file")
      H.git(root, "stash", "push", "-m", "saved")
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.cmd("filetype plugin on")
      for _, kind in ipairs({
        "status",
        "branch",
        "log",
        "reflog",
        "tag",
        "stash",
        "diff",
        "buffer",
        "blame",
      }) do
        vim.g["gin_" .. kind .. "_disable_default_mappings"] = nil
      end
      vim.cmd.enew({ bang = true })
      vim.cmd("setlocal foldmethod< foldenable< foldlevel<")
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
for _, command in ipairs({ "GinStatus", "GinLog", "GinReflog", "GinTag", "GinStash" }) do
  for _, input in ipairs({ "<CR>", "V<CR>" }) do
    T[command .. " " .. input .. " reveals the destination inside a fold"] = function()
      vim.cmd(command)
      local list = vim.api.nvim_get_current_buf()
      local name = command == "GinStatus" and "edit" or "show"
      local target = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(target, 0, -1, false, { "one", "two", "three" })
      require("gin.action").define(list, name, function()
        vim.api.nvim_set_current_buf(target)
        vim.wo.foldmethod = "manual"
        vim.wo.foldenable = true
        vim.cmd("1,3fold")
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        MiniTest.expect.equality(vim.fn.foldclosed(2), 1)
      end)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(input, true, false, true), "mx", false)
      MiniTest.expect.equality(vim.api.nvim_get_current_buf(), target)
      MiniTest.expect.equality(vim.fn.foldclosed(2), -1)
      vim.bo[target].modified = false
      vim.api.nvim_buf_call(list, function()
        for _, mode in ipairs({ "n", "x" }) do
          MiniTest.expect.equality(
            vim.fn.maparg("<CR>", mode),
            "<Plug>(gin-action-" .. name .. ")zv"
          )
        end
      end)
    end
  end
end
for _, kind in ipairs({ "branch", "status", "log", "reflog", "tag", "stash" }) do
  T[kind .. " action registrations match the pinned initialization oracle"] = function()
    local oracle =
      vim.json.decode(table.concat(vim.fn.readfile(cwd .. "/tests/audit/action-oracle.json"), "\n"))
    local lock = vim.json.decode(table.concat(vim.fn.readfile(cwd .. "/deps-lock.json"), "\n"))
    MiniTest.expect.equality(oracle.commit, lock["vim-gin"].commit)
    vim.cmd("Gin" .. kind:sub(1, 1):upper() .. kind:sub(2))
    local expected = {}
    local attributes = { "buffer", "noremap", "silent", "expr", "nowait", "script" }
    for name, alias in pairs(oracle[kind]) do
      local options = oracle.mapping_options[alias == vim.NIL and "action" or "alias"]
      MiniTest.expect.equality(options.mode, nil)
      expected[name] = { alias = alias }
      for _, attribute in ipairs(attributes) do
        expected[name][attribute] = options[attribute] and 1 or 0
      end
      expected[name].buffer = options.buffer and vim.api.nvim_get_current_buf() or 0
    end
    for _, mode in ipairs({ "n", "x", "s", "o", "i", "c", "t", "l" }) do
      local mappings = {}
      for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
        local name = map.lhs:match("^<Plug>%(gin%-action%-(.*)%)$")
        if name then
          mappings[name] =
            { alias = (map.rhs or ""):match("^<Plug>%(gin%-action%-(.*)%)$") or vim.NIL }
          for _, attribute in ipairs(attributes) do
            mappings[name][attribute] = map[attribute]
          end
        end
      end
      MiniTest.expect.equality(
        mappings,
        vim.tbl_contains({ "n", "x", "s", "o" }, mode) and expected or {}
      )
    end
  end
end

local function default_maps(buf, prefix)
  prefix = prefix or "<Plug>(gin-action-"
  local result = {}
  for _, mode in ipairs({ "n", "x", "s", "o" }) do
    result[mode] = {}
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
      if not map.lhs:find("<Plug>", 1, true) and (map.rhs or ""):find(prefix, 1, true) then
        result[mode][map.lhs] = {
          rhs = map.rhs,
          noremap = map.noremap,
          nowait = map.nowait,
          silent = map.silent,
        }
      end
    end
  end
  return result
end
T["blame default mapping attributes match both pinned ftplugins"] = function()
  for _, kind in ipairs({ "blame", "blame-nav" }) do
    for _, disabled in ipairs({ 0, 1 }) do
      vim.g.gin_blame_disable_default_mappings = disabled
      local maps = {}
      for _, runtime in ipairs({ { "/.deps/vim-gin/", "vim" }, { "/", "lua" } }) do
        local buf = vim.api.nvim_create_buf(false, true)
        local fixed = vim.wo.winfixbuf
        vim.api.nvim_buf_call(buf, function()
          vim.cmd.source(cwd .. runtime[1] .. "ftplugin/gin-" .. kind .. "." .. runtime[2])
        end)
        maps[#maps + 1] = default_maps(buf, "<Plug>(gin-blame-")
        vim.wo.winfixbuf = fixed
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      MiniTest.expect.equality(maps[2], maps[1])
    end
  end
end
for _, kind in ipairs({ "status", "branch", "log", "reflog", "tag", "stash" }) do
  for _, disabled in ipairs({ 0, 1 }) do
    T[kind .. " default mappings match the pinned ftplugin with disable=" .. disabled] = function()
      vim.g["gin_" .. kind .. "_disable_default_mappings"] = disabled
      local expected_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_call(expected_buf, function()
        vim.cmd.source(cwd .. "/.deps/vim-gin/ftplugin/gin-" .. kind .. ".vim")
      end)
      local expected = default_maps(expected_buf)
      vim.api.nvim_buf_delete(expected_buf, { force = true })
      vim.cmd("Gin" .. kind:sub(1, 1):upper() .. kind:sub(2))
      MiniTest.expect.equality(default_maps(vim.api.nvim_get_current_buf()), expected)
      vim.cmd.edit()
      H.drain()
      MiniTest.expect.equality(default_maps(vim.api.nvim_get_current_buf()), expected)
    end
  end
end
for _, kind in ipairs({ "status", "branch", "log", "reflog", "tag", "stash" }) do
  T[kind .. " reload preserves a user default-key override"] = function()
    vim.cmd("Gin" .. kind:sub(1, 1):upper() .. kind:sub(2))
    local buf = vim.api.nvim_get_current_buf()
    local default = vim.fn.maparg("yy", "n")
    local rhs = "<Cmd>let g:gin_test_mapping = 1<CR>"
    vim.keymap.set("n", "yy", rhs, { buffer = buf })
    vim.cmd.edit()
    H.drain()
    MiniTest.expect.equality(vim.fn.maparg("yy", "n"), rhs)
    vim.keymap.del("n", "yy", { buffer = buf })
    vim.cmd.edit()
    H.drain()
    MiniTest.expect.equality(vim.fn.maparg("yy", "n"), "")
    vim.bo[buf].filetype = "text"
    vim.cmd.edit()
    H.drain()
    MiniTest.expect.equality(vim.fn.maparg("yy", "n"), default)
  end
end
for _, kind in ipairs({ "status", "branch", "log", "reflog", "tag", "stash" }) do
  T[kind .. " honors default-key overrides from FileType hooks"] = function()
    local rhs = "<Cmd>let g:gin_test_mapping = 2<CR>"
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "gin-" .. kind,
      once = true,
      callback = function(event)
        vim.keymap.set("n", "yy", rhs, { buffer = event.buf })
      end,
    })
    vim.cmd("Gin" .. kind:sub(1, 1):upper() .. kind:sub(2))
    MiniTest.expect.equality(vim.fn.maparg("yy", "n"), rhs)
    vim.cmd.edit()
    H.drain()
    MiniTest.expect.equality(vim.fn.maparg("yy", "n"), rhs)
  end
end
for _, kind in ipairs({ "status", "branch", "log", "reflog", "tag", "stash" }) do
  T[kind .. " does not install default keys with filetype plugins disabled"] = function()
    vim.cmd("filetype plugin off")
    vim.cmd("Gin" .. kind:sub(1, 1):upper() .. kind:sub(2))
    MiniTest.expect.equality(
      default_maps(vim.api.nvim_get_current_buf()),
      { n = {}, x = {}, s = {}, o = {} }
    )
    MiniTest.expect.equality(vim.fn.maparg("<Plug>(gin-action-choice)", "n", false, true).buffer, 1)
  end
end
for _, case in ipairs({
  { "diff", "GinDiff -- file" },
  { "buffer", "GinBuffer ++diffjump=HEAD diff HEAD -- file" },
}) do
  for _, disabled in ipairs({ 0, 1 }) do
    T[case[1] .. " jump mappings match the pinned ftplugin with disable=" .. disabled] = function()
      vim.g["gin_" .. case[1] .. "_disable_default_mappings"] = disabled
      local expected_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_call(expected_buf, function()
        vim.cmd.source(cwd .. "/.deps/vim-gin/ftplugin/gin-" .. case[1] .. ".vim")
      end)
      local expected = default_maps(expected_buf, "<Plug>(gin-diffjump-")
      vim.api.nvim_buf_delete(expected_buf, { force = true })
      vim.cmd(case[2])
      MiniTest.expect.equality(
        default_maps(vim.api.nvim_get_current_buf(), "<Plug>(gin-diffjump-"),
        expected
      )
    end
  end
  T[case[1] .. " jump defaults respect filetype plugin off"] = function()
    vim.cmd("filetype plugin off")
    vim.cmd(case[2])
    MiniTest.expect.equality(
      default_maps(vim.api.nvim_get_current_buf(), "<Plug>(gin-diffjump-"),
      { n = {}, x = {}, s = {}, o = {} }
    )
    MiniTest.expect.equality(
      vim.fn.maparg("<Plug>(gin-diffjump-smart)", "n", false, true).buffer,
      1
    )
  end
  T[case[1] .. " jump defaults follow ftplugin order and preserve overrides"] = function()
    vim.fn.writefile({ "changed" }, root .. "/file")
    local rhs = "<Cmd>let g:gin_test_mapping = 3<CR>"
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "gin-" .. case[1],
      once = true,
      callback = function(event)
        vim.keymap.set("n", "<CR>", rhs, { buffer = event.buf })
      end,
    })
    vim.cmd(case[2])
    MiniTest.expect.equality(vim.fn.maparg("<CR>", "n"), rhs)
    vim.cmd.edit()
    H.drain()
    MiniTest.expect.equality(vim.fn.maparg("<CR>", "n"), rhs)
  end
end
return T
