local M = {}
local git = require("gin.git")
local uri = require("gin.uri")
local buffer = require("gin.buffer")

-- Use line porcelain so filename/previous metadata belongs to each line,
-- including when the same commit contributed lines from different paths.
function M.parse(output)
  local result = { commits = {}, lines = {} }
  local entry, metadata
  for line in (output .. "\n"):gmatch("([^\n]*)\n") do
    if line:sub(1, 1) == "\t" and entry then
      entry.content = line:sub(2)
      entry.metadata = metadata
      result.commits[entry.commitSha] = metadata
      result.lines[#result.lines + 1] = entry
      entry = nil
    elseif entry then
      local key, value = line:match("^(%S+)%s?(.*)$")
      if key then
        metadata[key] = value
      end
    else
      local sha, original, final, count = line:match("^(%x+) (%d+) (%d+)%s*(%d*)$")
      if sha then
        entry = {
          commitSha = sha,
          originalLineNumber = tonumber(original),
          lineNumber = tonumber(final),
          numLinesInGroup = tonumber(count) or 1,
        }
        metadata = {}
      end
    end
  end
  return result
end

local function relative_time(timestamp)
  local now = os.time()
  local diff = now - tonumber(timestamp)
  local seconds = math.abs(diff)
  if seconds < 60 then
    return "just now"
  end
  local value, unit
  if seconds < 3600 then
    value, unit = math.floor(seconds / 60), "minute"
  elseif seconds < 86400 then
    value, unit = math.floor(seconds / 3600), "hour"
  elseif seconds < 604800 then
    value, unit = math.floor(seconds / 86400), "day"
  elseif seconds < 2592000 then
    value, unit = math.floor(seconds / 604800), "week"
  else
    local earlier = os.date("*t", math.min(now, tonumber(timestamp)))
    local later = os.date("*t", math.max(now, tonumber(timestamp)))
    if seconds < 31536000 then
      value, unit = (later.year - earlier.year) * 12 + later.month - earlier.month, "month"
      if later.day < earlier.day then
        value = value - 1
      end
    else
      value, unit = later.year - earlier.year, "year"
      if
        later.month < earlier.month or (later.month == earlier.month and later.day < earlier.day)
      then
        value = value - 1
      end
    end
    value = math.max(1, value)
  end
  local text = value .. " " .. unit .. (value == 1 and "" or "s")
  return diff < 0 and "in " .. text or text .. " ago"
end

function M.update_detail(buf, lnum)
  local detail = vim.b[buf].gin_blame_detail_bufnr
  if not detail or not vim.api.nvim_buf_is_loaded(detail) then
    return
  end
  local parsed = uri.parse(vim.api.nvim_buf_get_name(buf))
  local line = (vim.b[buf].gin_blame_line_map or {})[lnum]
  local commit = lnum == 1 and (parsed.params.commitish or "HEAD")
    or (type(line) == "table" and line.commitSha)
  if not commit or vim.b[detail].gin_blame_detail_last_commit == commit then
    return
  end
  local output =
    git.run({ "show", "--no-patch", "--format=fuller", commit, "--" }, { cwd = parsed.root }).stdout
  buffer.replace(detail, buffer.lines(output), parsed.root, "git")
  vim.bo[detail].buftype = "nowrite"
  vim.b[detail].gin_blame_detail_last_commit = commit
end

function M.read(buf, name)
  local parsed = uri.parse(name)
  local path =
    require("gin.edit").path(parsed.root, assert(parsed.fragment, "GinBlame requires a path"))
  local output = git.run(
    { "blame", "--line-porcelain", parsed.params.commitish or "HEAD", "--", path },
    { cwd = parsed.root }
  ).stdout
  local result = M.parse(output)
  local content, navlines, map, reverse = {}, {}, {}, {}
  local previous
  local width = #tostring(#result.lines)
  for _, line in ipairs(result.lines) do
    local label = string.format("%" .. width .. "d", line.lineNumber)
    if line.commitSha ~= previous then
      content[#content + 1], navlines[#navlines + 1] = "", ""
      label = label
        .. " "
        .. relative_time(line.metadata["author-time"])
        .. "\t"
        .. line.metadata.author
        .. "\t"
        .. line.metadata.summary
    end
    content[#content + 1], navlines[#navlines + 1] = line.content, label
    map[#content], reverse[line.lineNumber] = line, #content
    previous = line.commitSha
  end
  local ft = vim.filetype.match({ filename = path, buf = buf })
  buffer.replace(buf, content, parsed.root, ft and ft .. ".gin-blame" or "gin-blame")
  local filewin = vim.api.nvim_get_current_win()
  local navname = uri.format("ginblamenav", parsed.root, parsed.params, path)
  local detailname = uri.format("ginblamedetail", parsed.root, parsed.params, path)
  local detail = vim.fn.bufnr(detailname)
  if detail == -1 or vim.fn.bufwinid(detail) == -1 then
    detail = buffer.open(detailname, { opener = "split", smods = { split = "topleft" } })
    vim.api.nvim_win_set_height(0, 10)
    vim.wo.winfixheight = true
  end
  vim.b[detail].gin_blame_detail_last_commit = nil
  buffer.replace(
    detail,
    buffer.lines(
      git.run(
        { "show", "--no-patch", "--format=fuller", parsed.params.commitish or "HEAD", "--" },
        { cwd = parsed.root }
      ).stdout
    ),
    parsed.root,
    "git"
  )
  vim.api.nvim_set_current_win(filewin)
  local nav = vim.fn.bufnr(navname)
  if nav == -1 or vim.fn.bufwinid(nav) == -1 then
    nav = buffer.open(navname, { opener = "vsplit", smods = { split = "leftabove" } })
    vim.api.nvim_win_set_width(0, 60)
  else
    vim.api.nvim_set_current_win(vim.fn.bufwinid(nav))
  end
  buffer.replace(nav, navlines, parsed.root, "gin-blame-nav")
  for _, target in ipairs({ buf, nav, detail }) do
    vim.bo[target].buftype = "nowrite"
    vim.b[target].gin_blame_file_bufnr = buf
    vim.b[target].gin_blame_nav_bufnr = nav
    vim.b[target].gin_blame_detail_bufnr = detail
    local win = vim.fn.bufwinid(target)
    vim.wo[win].number, vim.wo[win].relativenumber = false, false
    vim.wo[win].wrap, vim.wo[win].signcolumn = false, "no"
    local group = vim.api.nvim_create_augroup("gin_blame_detail_" .. target, { clear = true })
    vim.api.nvim_create_autocmd("BufUnload", {
      group = group,
      buffer = target,
      callback = function()
        -- Reload unloads the buffer temporarily. Check after the operation has
        -- finished, when buffer/window deletion is also safe outside textlock.
        vim.schedule(function()
          if vim.api.nvim_buf_is_loaded(target) then
            return
          end
          for _, paired in ipairs({ buf, nav, detail }) do
            if paired ~= target and vim.api.nvim_buf_is_valid(paired) then
              vim.api.nvim_buf_delete(paired, { force = true })
            end
          end
        end)
      end,
    })
    vim.api.nvim_create_autocmd("BufWipeout", {
      group = group,
      buffer = target,
      once = true,
      callback = function()
        vim.api.nvim_del_augroup_by_id(group)
      end,
    })
    if target ~= detail then
      vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        buffer = target,
        callback = function()
          M.update_detail(target, vim.api.nvim_win_get_cursor(0)[1])
        end,
      })
      vim.b[target].gin_blame_result = result
      vim.b[target].gin_blame_line_map = map
      vim.b[target].gin_blame_file_line_to_physical = reverse
      vim.wo[win].scrollbind, vim.wo[win].cursorbind, vim.wo[win].cursorline = true, true, true
    end
  end
end

function M.read_nav(buf)
  local file = vim.b[buf].gin_blame_file_bufnr
  assert(file and vim.api.nvim_buf_is_valid(file), "GinBlame file buffer is missing")
  local win = vim.fn.bufwinid(file)
  assert(win ~= -1, "GinBlame file window is missing")
  vim.api.nvim_win_call(win, function()
    M.read(file, vim.api.nvim_buf_get_name(file))
  end)
end

function M.command(opts)
  local options, args = require("gin.command").parse(opts.fargs, { "worktree", "opener" })
  assert(#args == 1 or #args == 2, "GinBlame expects [commitish] path")
  local root = require("gin.worktree").current(options.worktree)
  local path = require("gin.edit").path(root, vim.fn.fnamemodify(args[#args], ":p"))
  local name = uri.format("ginblame", root, { commitish = #args == 2 and args[1] or nil }, path)
  return buffer.open(
    name,
    { opener = options.opener or "tabedit", bang = opts.bang, smods = opts.smods }
  )
end

return M
