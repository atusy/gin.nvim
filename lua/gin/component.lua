local M = {}
local git = require("gin.git")
local values = { branch = "", upstream = "", ahead = 0, behind = 0, root = "" }
local initialized, pending = false, false
local requested = {}
local generation, notification = 0, 0

local function publish(result, version)
  if version ~= generation then
    return
  end
  local changed = requested.branch
      and (result.branch ~= values.branch or result.upstream ~= values.upstream)
    or requested.traffic and (result.ahead ~= values.ahead or result.behind ~= values.behind)
    or requested.worktree and result.root ~= values.root
  values = result
  if not changed then
    return
  end
  notification = notification + 1
  local ticket = notification
  vim.defer_fn(function()
    if ticket == notification then
      vim.api.nvim_exec_autocmds("User", { pattern = "GinComponentPost", modeline = false })
    end
  end, 100)
end

local function report_error(message, kind)
  if vim.o.verbose > 0 and (not kind or requested[kind]) then
    vim.notify(message, vim.log.levels.ERROR)
  end
end

local function run(args, cwd, version, callback)
  local function complete(result)
    vim.schedule(function()
      if version == generation then
        callback(result)
      end
    end)
  end
  local ok, err = pcall(git.start, args, { cwd = cwd }, complete)
  if not ok then
    complete({ code = -1, stdout = "", stderr = "", spawn_error = tostring(err) })
  end
end

function M.refresh()
  generation = generation + 1
  local version = generation
  local cwd = vim.fn.getcwd()
  local anchor = vim.b.gin_worktree or vim.api.nvim_buf_get_name(0)
  local dirs = require("gin.worktree").candidates(anchor)
  if not vim.tbl_contains(dirs, cwd) then
    dirs[#dirs + 1] = cwd
  end
  local function discover(index)
    run({ "rev-parse", "--show-toplevel" }, dirs[index], version, function(found)
      if found.spawn_error then
        report_error(found.spawn_error)
        return
      end
      if found.code ~= 0 then
        if dirs[index + 1] then
          discover(index + 1)
        else
          publish({ branch = "", upstream = "", ahead = 0, behind = 0, root = "" }, version)
        end
        return
      end
      local root = found.stdout:gsub("\n$", "")
      root = vim.uv.fs_realpath(root) or root
      local result = vim.tbl_extend("force", values, { root = root })
      local function traffic()
        run(
          { "rev-list", "--left-right", "--count", "HEAD...@{u}" },
          root,
          version,
          function(counts)
            if counts.code == 0 then
              local ahead, behind = counts.stdout:match("(%d+)%s+(%d+)")
              result.ahead, result.behind = tonumber(ahead) or 0, tonumber(behind) or 0
            else
              report_error(
                counts.spawn_error or git.error_message(counts, "git component traffic"),
                "traffic"
              )
            end
            publish(result, version)
          end
        )
      end
      run(
        { "rev-parse", "--abbrev-ref", "--symbolic-full-name", "HEAD", "@{u}" },
        root,
        version,
        function(branch)
          if branch.code == 0 then
            local lines = vim.split(vim.trim(branch.stdout), "\n", { plain = true })
            result.branch, result.upstream = lines[1] or "", lines[2] or ""
            traffic()
          else
            run({ "branch", "--show-current" }, root, version, function(current)
              if current.code == 0 then
                result.branch, result.upstream = vim.trim(current.stdout), ""
                result.ahead, result.behind = 0, 0
                traffic()
              else
                report_error(
                  current.spawn_error or git.error_message(current, "git component branch"),
                  "branch"
                )
                traffic()
              end
            end)
          end
        end
      )
    end)
  end
  discover(1)
end

local function schedule()
  -- Invalidate in-flight output immediately, before the scheduled refresh runs.
  generation = generation + 1
  if pending then
    return
  end
  pending = true
  vim.schedule(function()
    pending = false
    M.refresh()
  end)
end

function M.get(kind, style)
  if not requested[kind] then
    requested[kind] = true
    if initialized then
      schedule()
    end
  end
  if not initialized then
    initialized = true
    local group = vim.api.nvim_create_augroup("gin_components", { clear = true })
    vim.api.nvim_create_autocmd(
      { "BufEnter", "DirChanged" },
      { group = group, callback = schedule }
    )
    vim.api.nvim_create_autocmd(
      "User",
      { group = group, pattern = "GinCommandPost", callback = schedule }
    )
    schedule()
  end
  if kind == "worktree" then
    return style == "name" and (values.root ~= "" and vim.fs.basename(values.root) or "")
      or values.root
  elseif kind == "branch" then
    return values.branch
      .. (
        values.upstream ~= "" and (style == "unicode" and " → " or " -> ") .. values.upstream
        or ""
      )
  end
  return (values.ahead > 0 and (style == "unicode" and "↑" or "^") .. values.ahead or "")
    .. (values.behind > 0 and (style == "unicode" and "↓" or "v") .. values.behind or "")
end

return M
