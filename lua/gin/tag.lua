local M = {}
local uri = require("gin.uri")
local git = require("gin.git")
local action = require("gin.action")

local function candidates(buf, range)
  local rows, selected, seen = vim.b[buf].gin_tags or {}, {}, {}
  for i = math.max(1, range[1]), math.min(#rows, range[2]) do
    if not seen[rows[i].tag] then
      selected[#selected + 1] = rows[i]
      seen[rows[i].tag] = true
    end
  end
  return selected
end

local function output(parsed, progress)
  local args = { "tag", "--list", "--color=never" }
  local format = "%(objectname:short) %(refname:short) %(creatordate:short) %(subject)"
  for _, flag in ipairs(parsed.params.args and vim.json.decode(parsed.params.args) or {}) do
    if flag:sub(1, 9) == "--format=" then
      format = flag:sub(10)
    else
      args[#args + 1] = flag
    end
  end
  -- A per-read boundary keeps NULs in the requested display out of the metadata.
  local boundary = vim.fn.sha256(vim.fn.tempname())
  args[#args + 1] = "--format=%00"
    .. boundary
    .. "%00%(refname:strip=2)%00%(objectname)%00"
    .. format
  args[#args + 1] = "--"
  vim.list_extend(args, parsed.fragment and uri.split(parsed.fragment) or {})
  local rows, lines = {}, {}
  local records = vim.split(
    git.run(args, { cwd = parsed.root, progress = progress }).stdout,
    "\0" .. boundary .. "\0",
    {
      plain = true,
    }
  )
  for i = 2, #records do
    local tag, commit, display = records[i]:match("^([^%z]+)%z([^%z]+)%z(.*)\n$")
    assert(tag and commit and display, "Invalid tag record")
    for _, line in ipairs(vim.split(display, "\n", { plain = true })) do
      rows[#rows + 1] = { tag = tag, commit = commit }
      lines[#lines + 1] = line
    end
  end
  return table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""), rows
end

function M.insert(buf, name)
  local parsed = uri.parse(name)
  local args = {
    "tag",
    "--list",
    "--color=never",
    "--format=%(objectname:short) %(refname:short) %(creatordate:short) %(subject)",
  }
  vim.list_extend(args, parsed.params.args and vim.json.decode(parsed.params.args) or {})
  args[#args + 1] = "--"
  vim.list_extend(args, parsed.fragment and uri.split(parsed.fragment) or {})
  -- Insertions have no action candidates; stream only the requested display format.
  local text = git.run(args, { cwd = parsed.root, progress = "both" }).stdout
  require("gin.buffer").insert_output(buf, name, text)
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  local text, rows = output(parsed, true)
  require("gin.buffer").replace_output(buf, text, parsed.root, "gin-tag", parsed.params)
  vim.bo[buf].buflisted, vim.bo[buf].modeline = false, false
  vim.b[buf].gin_tags = rows
  action.setup(buf, candidates)
  local function run(args)
    require("gin.command").finish(git.run(args, { cwd = parsed.root, progress = "both" }), {}, {})
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
    for _, emojify in ipairs({ false, true }) do
      action.define(
        buf,
        "show:" .. opener .. (emojify and ":emojify" or ""),
        function(target, range)
          for _, row in ipairs(candidates(target, range)) do
            require("gin.buffer").open(
              uri.format("gin", parsed.root, {
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
        (key == "a" or key == "." or key == "<CR>") and { "n", "x" } or "n",
        key,
        "<Plug>(gin-action-" .. name .. ")",
        { buffer = buf, remap = true, nowait = true }
      )
    end
    vim.keymap.set("x", "y", "<Plug>(gin-action-yank:tag)<Esc>", { buffer = buf, remap = true })
  end
end

function M.command(opts)
  local args = require("gin.command").arguments("tag", opts.fargs)
  local options, residue = require("gin.command").parse(
    args,
    { "worktree", "opener", "emojify", "enc", "encoding", "ff", "fileformat" }
  )
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
    uri.format("gintag", root, {
      args = vim.json.encode(flags),
      emojify = options.emojify and "" or nil,
      enc = options.enc or options.encoding,
      ff = options.ff or options.fileformat,
    }, uri.join(patterns)),
    options
  )
end

return M
