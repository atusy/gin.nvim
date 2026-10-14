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
      for _, kind in ipairs({ "status", "branch", "log", "reflog", "tag", "stash" }) do
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
local function default_maps(buf)
  local result = {}
  for _, mode in ipairs({ "n", "x", "s", "o" }) do
    result[mode] = {}
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
      if
        not map.lhs:find("<Plug>", 1, true) and (map.rhs or ""):find("<Plug>(gin-action-", 1, true)
      then
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
return T
