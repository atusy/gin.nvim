local M = {}

local function bind(buf, name, command, target, default, disabled)
  vim.keymap.set({ "n", "x" }, "<Plug>(gin-" .. name .. ")", function()
    local range = vim.fn.mode() ~= "n" and require("gin.action").range() or nil
    vim.api.nvim_cmd({ cmd = command, args = { tostring(target) }, range = range }, {})
    vim.cmd.diffupdate()
  end, { buffer = buf, silent = true })
  if not disabled then
    vim.keymap.set(
      { "n", "x" },
      default,
      "<Plug>(gin-" .. name .. ")",
      { buffer = buf, remap = true }
    )
  end
end

local function alias(buf, to, disabled)
  vim.keymap.set(
    { "n", "x" },
    "<Plug>(gin-diffget)",
    "<Plug>(gin-" .. to .. ")",
    { buffer = buf, remap = true }
  )
  if not disabled then
    vim.keymap.set({ "n", "x" }, "do", "<Plug>(gin-diffget)", { buffer = buf, remap = true })
  end
end

function M.open(root, path, options)
  options = options or {}
  local edit = require("gin.edit")
  path = edit.path(root, path)
  local index = edit.open(root, path, options)
  local index_win = vim.fn.bufwinid(index)
  local windows = { index_win }
  local head, worktree
  if not options["no-head"] then
    head = edit.open(root, path, {
      commitish = "HEAD",
      opener = "vsplit",
      smods = { split = "topleft" },
      enc = options.enc,
      ff = options.ff,
    })
    windows[#windows + 1] = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(index_win)
  end
  if not options["no-worktree"] then
    worktree = require("gin.buffer").open(
      root .. "/" .. path,
      { opener = "vsplit", smods = { split = "botright" } }
    )
    windows[#windows + 1] = vim.api.nvim_get_current_win()
  end
  local disabled = vim.g.gin_patch_disable_default_mappings
  disabled = disabled ~= nil and disabled ~= false and disabled ~= 0
  if head then
    bind(head, "diffput", "diffput", index, "dp", disabled)
    bind(index, "diffget-l", "diffget", head, "dol", disabled)
    alias(index, "diffget-l", disabled)
  end
  if worktree then
    bind(worktree, "diffput", "diffput", index, "dp", disabled)
    bind(worktree, "diffget", "diffget", index, "do", disabled)
    bind(index, "diffput", "diffput", worktree, "dp", disabled)
    bind(index, "diffget-r", "diffget", worktree, "dor", disabled)
    alias(index, "diffget-r", disabled)
  end
  for _, win in ipairs(windows) do
    vim.api.nvim_win_call(win, function()
      vim.cmd.diffthis()
    end)
  end
  vim.api.nvim_set_current_win(index_win)
  return { index = index, head = head, worktree = worktree }
end

function M.command(opts)
  local args = vim.deepcopy(vim.g.gin_patch_persistent_args or {})
  vim.list_extend(args, #opts.fargs == 0 and (vim.g.gin_patch_default_args or {}) or opts.fargs)
  local options, residue = require("gin.command").parse(
    args,
    { "worktree", "opener", "no-head", "no-worktree", "enc", "encoding", "ff", "fileformat" }
  )
  assert(#residue <= 1, "GinPatch expects at most one path")
  local path = residue[1]
  if not path then
    local _, expanded = require("gin.command").parse({ "%:p" }, {})
    path = expanded[1]
  end
  assert(path and path ~= "", "GinPatch requires a file")
  path = vim.fn.fnamemodify(path, ":p")
  options.enc, options.ff = options.enc or options.encoding, options.ff or options.fileformat
  options.bang, options.smods = opts.bang, opts.smods
  return M.open(require("gin.worktree").current(options.worktree), path, options)
end

return M
