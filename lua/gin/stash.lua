local M = {}
local uri = require("gin.uri")
local action = require("gin.action")
local git = require("gin.git")

local function candidates(buf, range)
  local result, rows = {}, vim.b[buf].gin_stashes or {}
  for i = math.max(1, range[1]), math.min(#rows, range[2]) do
    result[#result + 1] = rows[i]
  end
  return result
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  local args = { "stash", "list", "--color=never" }
  vim.list_extend(args, parsed.fragment and vim.json.decode(parsed.fragment) or {})
  args[#args + 1] = "--format=%gd%x00%H%x00%s"
  local rows, lines = {}, {}
  for line in git.run(args, { cwd = parsed.root }).stdout:gmatch("[^\n]+") do
    local fields = vim.split(line, "\0", { plain = true })
    rows[#rows + 1] = { stash = fields[1], commit = fields[2] }
    lines[#lines + 1] = fields[1] .. ": " .. fields[3]
  end
  if parsed.params.emojify ~= nil then
    lines = vim.tbl_map(require("gin.emoji").emojify, lines)
  end
  require("gin.buffer").replace(buf, #lines > 0 and lines or { "" }, parsed.root, "gin-stash")
  vim.bo[buf].buflisted, vim.bo[buf].modeline = false, false
  vim.b[buf].gin_stashes = rows
  action.setup(buf, candidates)
  for _, variant in ipairs({ "apply", "apply:index", "pop", "pop:index", "drop" }) do
    action.define(buf, variant, function(target, range)
      local row = candidates(target, range)[1]
      if not row then
        return
      end
      local command = variant:match("^[^:]+")
      local args = { "stash", command }
      if variant:find(":index", 1, true) then
        args[#args + 1] = "--index"
      end
      args[#args + 1] = row.stash
      require("gin.command").finish(git.run(args, { cwd = parsed.root }), {}, {})
    end)
  end
  for _, opener in ipairs({ "edit", "split", "vsplit", "tabedit" }) do
    for _, emojify in ipairs({ false, true }) do
      action.define(
        buf,
        "show:" .. opener .. (emojify and ":emojify" or ""),
        function(target, range)
          for _, row in ipairs(candidates(target, range)) do
            require("gin.buffer").open(
              uri.format("gin", parsed.root, {
                filetype = "git",
                diffjump = row.commit,
                difffold = "",
                emojify = emojify and "" or nil,
              }, uri.join({ "show", row.commit })),
              { opener = opener }
            )
          end
        end
      )
    end
  end
  action.alias(buf, "show", "show:edit")
  action.alias(buf, "show:emojify", "show:edit:emojify")
  action.define(buf, "yank:stash", function(target, range)
    local values = {}
    for _, row in ipairs(candidates(target, range)) do
      values[#values + 1] = row.stash
    end
    vim.fn.setreg(vim.v.register, table.concat(values, "\n"))
  end)
  local group = vim.api.nvim_create_augroup("gin_stash_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "GinCommandPost",
    callback = function()
      if vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_buf_call(buf, function()
          local view = vim.fn.winsaveview()
          M.read(buf, name)
          vim.fn.winrestview(view)
        end)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })
  if
    not vim.g.gin_stash_disable_default_mappings or vim.g.gin_stash_disable_default_mappings == 0
  then
    for key, name in pairs({
      a = "choice",
      ["."] = "repeat",
      ["?"] = "help",
      ["<CR>"] = "show",
      yy = "yank:stash",
    }) do
      vim.keymap.set(
        "n",
        key,
        "<Plug>(gin-action-" .. name .. ")",
        { buffer = buf, remap = true, nowait = true }
      )
    end
    vim.keymap.set("x", "y", "<Plug>(gin-action-yank:stash)<Esc>", { buffer = buf, remap = true })
  end
end

function M.command(opts)
  local args = vim.deepcopy(vim.g.gin_stash_persistent_args or {})
  vim.list_extend(args, #opts.fargs == 0 and (vim.g.gin_stash_default_args or {}) or opts.fargs)
  local options, residue = require("gin.command").parse(args, { "worktree", "opener", "emojify" })
  options.bang, options.smods = opts.bang, opts.smods
  return require("gin.buffer").open(
    uri.format(
      "ginstash",
      require("gin.worktree").current(options.worktree),
      { emojify = options.emojify and "" or nil },
      vim.json.encode(residue)
    ),
    options
  )
end

return M
