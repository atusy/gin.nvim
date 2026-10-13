local M = {}
local uri = require("gin.uri")
local action = require("gin.action")

function M.candidates(buf, range)
  local result = {}
  for _, line in
    ipairs(
      vim.api.nvim_buf_get_lines(
        buf,
        math.max(0, range[1] - 1),
        math.min(vim.api.nvim_buf_line_count(buf), range[2]),
        false
      )
    )
  do
    local text = line:gsub("^[ *|\\/+%=<>%-]*", "")
    text = text:gsub("^commit [+%=<>%-]? ?", "")
    local commit = text:match("^(%x+)%f[%X]") or text:match("^(%x+)$")
    if commit and #commit >= 4 then
      result[#result + 1] = { commit = commit }
    end
  end
  return result
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  local args = { "log", "--decorate=short", "--color=never" }
  vim.list_extend(args, parsed.fragment and vim.json.decode(parsed.fragment) or {})
  local output = require("gin.git").run(args, { cwd = parsed.root }).stdout
  require("gin.buffer").replace_output(buf, output, parsed.root, "gin-log", parsed.params)
  vim.bo[buf].buflisted, vim.bo[buf].modeline = false, false
  action.setup(buf)
  for _, opener in ipairs({ "edit", "split", "vsplit", "tabedit" }) do
    action.define(buf, "show:" .. opener, function(target, range)
      for _, row in ipairs(M.candidates(target, range)) do
        require("gin.buffer").open(
          uri.format("gin", parsed.root, {
            filetype = "git",
            diffjump = row.commit,
            difffold = "",
          }, uri.join({ "show", row.commit })),
          { opener = opener }
        )
      end
    end)
  end
  action.alias(buf, "show", "show:edit")
  action.define(buf, "yank:commit", function(target, range)
    local values = {}
    for _, row in ipairs(M.candidates(target, range)) do
      values[#values + 1] = row.commit
    end
    vim.fn.setreg(vim.v.register, table.concat(values, "\n"))
  end)
  local group = vim.api.nvim_create_augroup("gin_log_" .. buf, { clear = true })
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
  if not vim.g.gin_log_disable_default_mappings or vim.g.gin_log_disable_default_mappings == 0 then
    for key, name in pairs({
      a = "choice",
      ["."] = "repeat",
      ["?"] = "help",
      ["<CR>"] = "show",
      yy = "yank:commit",
    }) do
      vim.keymap.set(
        "n",
        key,
        "<Plug>(gin-action-" .. name .. ")",
        { buffer = buf, remap = true, nowait = true }
      )
    end
    vim.keymap.set("x", "y", "<Plug>(gin-action-yank:commit)<Esc>", { buffer = buf, remap = true })
  end
end

function M.open(root, args, options)
  options = options or {}
  return require("gin.buffer").open(
    uri.format("ginlog", root, {
      enc = options.enc or options.encoding,
      ff = options.ff or options.fileformat,
    }, vim.json.encode(args)),
    options
  )
end

function M.command(opts)
  local args = vim.deepcopy(vim.g.gin_log_persistent_args or {})
  vim.list_extend(args, #opts.fargs == 0 and (vim.g.gin_log_default_args or {}) or opts.fargs)
  local options, residue = require("gin.command").parse(
    args,
    { "worktree", "opener", "enc", "encoding", "ff", "fileformat" }
  )
  options.bang, options.smods = opts.bang, opts.smods
  return M.open(require("gin.worktree").current(options.worktree), residue, options)
end

return M
