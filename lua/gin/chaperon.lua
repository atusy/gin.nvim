local M = {}
local mapping = require("gin.diff_mapping")

function M.strip_conflicts(lines)
  local result, inside = {}, false
  for _, line in ipairs(lines) do
    if line:sub(1, 8) == "<<<<<<< " then
      inside = true
    elseif line:sub(1, 8) == ">>>>>>> " then
      inside = false
    elseif not inside then
      result[#result + 1] = line
    end
  end
  return result
end

function M.open(root, path, options)
  options = options or {}
  local edit = require("gin.edit")
  path = edit.path(root, path)
  local worktree = require("gin.buffer").open(root .. "/" .. path, options)
  local worktree_win = vim.fn.bufwinid(worktree)
  local windows = { worktree_win }
  local theirs, ours
  if not options["no-theirs"] then
    theirs = edit.open(root, path, {
      commitish = ":3",
      opener = "vsplit",
      smods = { split = "topleft" },
      enc = options.enc,
      ff = options.ff,
    })
    windows[#windows + 1] = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(worktree_win)
  end
  if not options["no-ours"] then
    ours = edit.open(root, path, {
      commitish = ":2",
      opener = "vsplit",
      smods = { split = "botright" },
      enc = options.enc,
      ff = options.ff,
    })
    windows[#windows + 1] = vim.api.nvim_get_current_win()
  end
  local original = vim.api.nvim_buf_get_lines(worktree, 0, -1, false)
  local stripped = M.strip_conflicts(original)
  if not vim.deep_equal(original, stripped) then
    vim.api.nvim_buf_set_lines(worktree, 0, -1, false, stripped)
  end
  mapping.reset(worktree)
  local disabled = vim.g.gin_chaperon_disable_default_mappings
  disabled = disabled ~= nil and disabled ~= false and disabled ~= 0
  if theirs then
    mapping.reset(theirs)
    mapping.bind(theirs, "diffput", "diffput", worktree, "dp", disabled)
    mapping.bind(worktree, "diffget-l", "diffget", theirs, "dol", disabled)
    mapping.alias(worktree, "diffget-l", disabled)
  end
  if ours then
    mapping.reset(ours)
    mapping.bind(ours, "diffput", "diffput", worktree, "dp", disabled)
    mapping.bind(worktree, "diffget-r", "diffget", ours, "dor", disabled)
    mapping.alias(worktree, "diffget-r", disabled)
  end
  for _, win in ipairs(windows) do
    vim.api.nvim_win_call(win, function()
      vim.cmd.diffthis()
    end)
  end
  vim.api.nvim_set_current_win(worktree_win)
  return { worktree = worktree, theirs = theirs, ours = ours }
end

function M.command(opts)
  local args = vim.deepcopy(vim.g.gin_chaperon_persistent_args or {})
  vim.list_extend(args, #opts.fargs == 0 and (vim.g.gin_chaperon_default_args or {}) or opts.fargs)
  local options, residue = require("gin.command").parse(
    args,
    { "worktree", "opener", "no-ours", "no-theirs", "enc", "encoding", "ff", "fileformat" }
  )
  assert(#residue <= 1, "GinChaperon expects at most one path")
  local path = residue[1]
  if not path then
    local _, expanded = require("gin.command").parse({ "%:p" }, {})
    path = expanded[1]
  end
  assert(path and path ~= "", "GinChaperon requires a file")
  options.enc, options.ff = options.enc or options.encoding, options.ff or options.fileformat
  options.bang, options.smods = opts.bang, opts.smods
  return M.open(
    require("gin.worktree").current(options.worktree),
    vim.fn.fnamemodify(path, ":p"),
    options
  )
end

return M
