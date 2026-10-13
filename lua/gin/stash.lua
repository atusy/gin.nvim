local M = {}
local uri = require("gin.uri")
local action = require("gin.action")
local git = require("gin.git")

local function candidates(buf, range)
  local result, rows, seen = {}, vim.b[buf].gin_stashes or {}, {}
  for i = math.max(1, range[1]), math.min(#rows, range[2]) do
    if not seen[rows[i].stash] then
      result[#result + 1] = rows[i]
      seen[rows[i].stash] = true
    end
  end
  return result
end

function M.insert(buf, name)
  local parsed = uri.parse(name)
  local args = { "stash", "list", "--color=never" }
  vim.list_extend(args, parsed.fragment and vim.json.decode(parsed.fragment) or {})
  local text = git.run(args, { cwd = parsed.root, progress = "both" }).stdout
  require("gin.buffer").insert_output(buf, name, text)
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  local args = { "stash", "list", "--color=never" }
  local format = "%gd: %s"
  for _, arg in ipairs(parsed.fragment and vim.json.decode(parsed.fragment) or {}) do
    if arg:sub(1, 9) == "--format=" then
      format = arg:sub(10)
    else
      args[#args + 1] = arg
    end
  end
  local boundary = vim.fn.sha256(vim.fn.tempname())
  args[#args + 1] = "--format=%x00" .. boundary .. "%x00%gd%x00%H%x00" .. format
  local rows, lines = {}, {}
  local records = vim.split(
    git.run(args, { cwd = parsed.root, progress = true }).stdout,
    "\0" .. boundary .. "\0",
    {
      plain = true,
    }
  )
  for i = 2, #records do
    local stash, commit, display = records[i]:match("^([^%z]+)%z([^%z]+)%z(.*)\n$")
    assert(stash and commit and display, "Invalid stash record")
    for _, line in ipairs(vim.split(display, "\n", { plain = true })) do
      rows[#rows + 1] = { stash = stash, commit = commit }
      lines[#lines + 1] = line
    end
  end
  require("gin.buffer").replace_output(
    buf,
    table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""),
    parsed.root,
    "gin-stash",
    parsed.params
  )
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
        (key == "a" or key == "." or key == "<CR>") and { "n", "x" } or "n",
        key,
        "<Plug>(gin-action-" .. name .. ")",
        { buffer = buf, remap = true, nowait = true }
      )
    end
    vim.keymap.set("x", "y", "<Plug>(gin-action-yank:stash)<Esc>", { buffer = buf, remap = true })
  end
end

function M.command(opts)
  local args = require("gin.command").arguments("stash", opts.fargs)
  local options, residue = require("gin.command").parse(
    args,
    { "worktree", "opener", "emojify", "enc", "encoding", "ff", "fileformat" }
  )
  options.bang, options.smods = opts.bang, opts.smods
  return require("gin.buffer").open(
    uri.format("ginstash", require("gin.worktree").current(options.worktree), {
      emojify = options.emojify and "" or nil,
      enc = options.enc or options.encoding,
      ff = options.ff or options.fileformat,
    }, vim.json.encode(residue)),
    options
  )
end

return M
