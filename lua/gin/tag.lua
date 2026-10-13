local M = {}
local uri = require("gin.uri")
local git = require("gin.git")
local action = require("gin.action")

local function candidates(buf, range)
  local rows, selected = vim.b[buf].gin_tags or {}, {}
  for i = math.max(1, range[1]), math.min(#rows, range[2]) do
    selected[#selected + 1] = rows[i]
  end
  return selected
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  local args = { "tag", "--list", "--color=never" }
  vim.list_extend(args, parsed.params.args and vim.json.decode(parsed.params.args) or {})
  args[#args + 1] = "--format=%(refname:strip=2)%00%(objectname)%00%(subject)"
  args[#args + 1] = "--"
  vim.list_extend(args, parsed.fragment and uri.split(parsed.fragment) or {})
  local rows, lines = {}, {}
  for line in git.run(args, { cwd = parsed.root }).stdout:gmatch("[^\n]+") do
    local fields = vim.split(line, "\0", { plain = true })
    rows[#rows + 1] = { tag = fields[1], commit = fields[2] }
    lines[#lines + 1] = fields[2]:sub(1, 7) .. " " .. fields[1] .. " " .. fields[3]
  end
  require("gin.buffer").replace(buf, #lines > 0 and lines or { "" }, parsed.root, "gin-tag")
  vim.bo[buf].buflisted, vim.bo[buf].modeline = false, false
  vim.b[buf].gin_tags = rows
  action.setup(buf, candidates)
  local function run(args)
    require("gin.command").finish(git.run(args, { cwd = parsed.root }), {}, {})
  end
  action.define(buf, "delete", function(target, range)
    local selected = candidates(target, range)
    if #selected == 0 then
      return
    end
    local args = { "tag", "-d", "--" }
    for _, row in ipairs(selected) do
      args[#args + 1] = row.tag
    end
    run(args)
  end)
  for _, detach in ipairs({ false, true }) do
    action.define(buf, detach and "switch:detach" or "switch", function(target, range)
      local row = candidates(target, range)[1]
      if row then
        local args = { "switch" }
        if detach then
          args[#args + 1] = "--detach"
        end
        vim.list_extend(args, { "--", row.tag })
        run(args)
      end
    end)
  end
  for _, opener in ipairs({ "edit", "split", "vsplit", "tabedit" }) do
    action.define(buf, "show:" .. opener, function(target, range)
      for _, row in ipairs(candidates(target, range)) do
        require("gin.buffer").open(
          uri.format(
            "gin",
            parsed.root,
            { filetype = "git", diffjump = row.commit, difffold = "" },
            uri.join({ "show", row.commit })
          ),
          { opener = opener }
        )
      end
    end)
  end
  action.alias(buf, "show", "show:edit")
  for _, field in ipairs({ "tag", "commit" }) do
    action.define(buf, "yank:" .. field, function(target, range)
      local values = {}
      for _, row in ipairs(candidates(target, range)) do
        values[#values + 1] = row[field]
      end
      vim.fn.setreg(vim.v.register, table.concat(values, "\n"))
    end)
  end
  local group = vim.api.nvim_create_augroup("gin_tag_" .. buf, { clear = true })
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
  if not vim.g.gin_tag_disable_default_mappings or vim.g.gin_tag_disable_default_mappings == 0 then
    for key, name in pairs({
      a = "choice",
      ["."] = "repeat",
      ["?"] = "help",
      ["<CR>"] = "show",
      yy = "yank:tag",
    }) do
      vim.keymap.set(
        "n",
        key,
        "<Plug>(gin-action-" .. name .. ")",
        { buffer = buf, remap = true, nowait = true }
      )
    end
    vim.keymap.set("x", "y", "<Plug>(gin-action-yank:tag)<Esc>", { buffer = buf, remap = true })
  end
end

function M.command(opts)
  local args = vim.deepcopy(vim.g.gin_tag_persistent_args or {})
  vim.list_extend(args, #opts.fargs == 0 and (vim.g.gin_tag_default_args or {}) or opts.fargs)
  local options, residue = require("gin.command").parse(args, { "worktree", "opener" })
  local flags, patterns, paths = {}, {}, false
  for _, value in ipairs(residue) do
    if value == "--" and not paths then
      paths = true
    elseif not paths and value:sub(1, 1) == "-" then
      flags[#flags + 1] = value
    else
      patterns[#patterns + 1] = value
    end
  end
  local root = require("gin.worktree").current(options.worktree)
  options.bang, options.smods = opts.bang, opts.smods
  return require("gin.buffer").open(
    uri.format("gintag", root, { args = vim.json.encode(flags) }, uri.join(patterns)),
    options
  )
end

return M
