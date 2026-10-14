local M = {}
local git = require("gin.git")
local function encode(path)
  return vim.uri_encode(path, "rfc3986"):gsub("%%2[Ff]", "/")
end

local function containing_remote(root, revision)
  local branches = git.run(
    { "branch", "-r", "--contains", revision, "--format=%(refname:short)" },
    { cwd = root, check = false }
  )
  if branches.code ~= 0 then
    return nil
  end
  local remotes = git.run({ "remote" }, { cwd = root }).stdout
  local first
  for remote in remotes:gmatch("[^\n]+") do
    for branch in branches.stdout:gmatch("[^\n]+") do
      if branch:sub(1, #remote + 1) == remote .. "/" then
        if remote == "origin" then
          return remote
        end
        first = first or remote
      end
    end
  end
  return first
end

function M.url(root, revision, options)
  options = options or {}
  local aliases, setting = options.aliases, "browse aliases"
  if aliases == nil then
    aliases, setting = vim.g.gin_browse_aliases, "g:gin_browse_aliases"
  end
  if aliases == nil then
    aliases = vim.empty_dict()
  end
  local message = setting .. " must be a dictionary of strings"
  assert(type(aliases) == "table" and not vim.islist(aliases), message)
  for host, provider in pairs(aliases) do
    assert(type(host) == "string" and type(provider) == "string", message)
  end
  revision = revision or "HEAD"
  local remote = options.remote
    or containing_remote(root, options.home and "HEAD" or revision)
    or "origin"
  local fetch = vim.trim(git.run({ "remote", "get-url", remote }, { cwd = root }).stdout)
  local scheme, authority, repository = fetch:match("^([%a][%w+.-]*)://([^/]+)/(.+)$")
  local host
  if scheme then
    host = authority:gsub("^.*@", "")
    if scheme:lower() == "http" or scheme:lower() == "https" then
      host = host:lower()
    end
  else
    host, repository = fetch:match("^[^@]+@([^:]+):(.+)$")
  end
  assert(host and repository, "Unsupported remote URL: " .. fetch)
  -- A Git transport port is not part of the hosting-service or web hostname.
  host = host:gsub(":%d+$", "")
  repository = repository:gsub("[?#].*$", ""):gsub("/$", ""):gsub("%.git$", "")
  local provider = aliases[host] or host
  assert(
    vim.tbl_contains({ "github.com", "gitlab.com", "bitbucket.org" }, provider),
    "Unsupported hosting service: " .. provider
  )
  -- The remote path is already URL-encoded; file paths below are still literal.
  local encoded_repository = encode(repository):gsub("%%25(%x%x)", "%%%1")
  local base = "https://" .. host .. "/" .. encoded_repository
  if options.home then
    return base
  end
  local hash =
    vim.trim(git.run({ "rev-parse", "--verify", revision .. "^{commit}" }, { cwd = root }).stdout)
  if options.pr then
    assert(provider ~= "bitbucket.org", "Hosting service has no pull request URL: " .. provider)
    local function request_id(message)
      local pattern = provider == "gitlab.com" and "See merge request [^\r\n]*!(%d+)"
        or "Merge pull request #(%d+)"
      local id = tonumber(message:match(pattern))
      return id ~= 0 and id or nil
    end
    local message = git.run({ "log", "-1", "--format=%B", hash }, { cwd = root }).stdout
    local number = request_id(message)
    if not number then
      local head = git.run(
        { "symbolic-ref", "--quiet", "refs/remotes/" .. remote .. "/HEAD" },
        { cwd = root, check = false }
      )
      local target = head.code == 0 and vim.trim(head.stdout)
        or ("refs/remotes/" .. remote .. "/main")
      local merges = git.run({
        "log",
        "--merges",
        "--format=%B",
        "--reverse",
        "--ancestry-path",
        hash .. "..." .. target,
      }, { cwd = root })
      number = request_id(merges.stdout)
    end
    assert(number, "No pull request found for " .. revision)
    return base .. (provider == "gitlab.com" and "/-/merge_requests/" or "/pull/") .. number
  end
  if options.commit then
    local route = provider == "bitbucket.org" and "/commits/"
      or provider == "gitlab.com" and "/-/commit/"
      or "/commit/"
    return base .. route .. hash
  end
  local ref = vim.trim(git.run({ "rev-parse", "--abbrev-ref", revision }, { cwd = root }).stdout)
  if options.permalink or ref == "HEAD" or ref == "" then
    ref = hash
  end
  local path = options.path or "."
  local range, explicit_pair = options.range, false
  if not range then
    local file, first, last = path:match("^(.-):(%d+):(%d+)$")
    if file then
      path, range, explicit_pair = file, { tonumber(first), tonumber(last) }, true
    else
      file, first = path:match("^(.-):(%d+)$")
      if file then
        path = file
        if tonumber(first) ~= 0 then
          range = { tonumber(first), tonumber(first) }
        end
      end
    end
  end
  if path ~= "." then
    path = require("gin.edit").path(root, path)
  end
  local tree = path == "."
    or vim.trim(
        git.run({ "cat-file", "-t", hash .. ":" .. path }, { cwd = root, check = false }).stdout
      )
      == "tree"
  local route = tree and "tree" or "blob"
  local suffix = ""
  range = not tree and range
  local include_end = range and (explicit_pair or range[2] ~= range[1])
  if provider == "bitbucket.org" then
    route = range and path:match("%.md$") and "annotate" or "src"
    if range then
      suffix = "#lines-" .. range[1] .. (include_end and ":" .. range[2] or "")
    end
  else
    if provider == "gitlab.com" then
      route = "-/" .. route
    end
    if range then
      suffix = "?plain=1#L"
        .. range[1]
        .. (include_end and (provider == "github.com" and "-L" or "-") .. range[2] or "")
    end
  end
  return base
    .. "/"
    .. route
    .. "/"
    .. encode(ref)
    .. "/"
    .. (path == "." and "" or encode(path))
    .. suffix
end

function M.command(opts)
  local args = require("gin.command").arguments("browse", opts.fargs)
  local options, residue = require("gin.command").parse(args, { "worktree", "repository", "yank" })
  local positional, separated = {}, false
  for _, arg in ipairs(residue) do
    local name, value
    if not separated then
      name, value = require("gin.flags").parse(arg)
    end
    if not separated and arg == "--" then
      separated = true
    elseif name then
      if name == "remote" then
        assert(options.remote == nil, "REMOTE in --remote={REMOTE} must be string")
        options.remote = value
      elseif name == "home" or name == "pr" or name == "commit" or name == "permalink" then
        options[name] = true
      elseif name == "no-browser" or name == "n" then
        options.no_browser = true
      end
    else
      positional[#positional + 1] = arg
    end
  end
  assert(#positional <= 2, "GinBrowse expects [revision] [path]")
  local root = require("gin.worktree").current(options.worktree)
  if not options.repository then
    local path = positional[2]
      or (vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) or vim.fn.getcwd())
    path = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
    options.path = path == root and "." or path
    -- The pinned command uses <count> (the last address), so zero means no range.
    if opts.range and opts.range > 0 and opts.line2 ~= 0 then
      options.path = options.path
        .. ":"
        .. opts.line1
        .. (opts.line2 ~= opts.line1 and ":" .. opts.line2 or "")
    end
  end
  local url = M.url(root, positional[1] or "HEAD", options)
  if options.yank then
    vim.fn.setreg(options.yank == true and vim.v.register or options.yank, url)
  end
  if options.no_browser then
    vim.api.nvim_echo({ { url, "None" } }, true, {})
  else
    local _, err = vim.ui.open(url)
    assert(not err, err)
  end
  return url
end

function M.setup(buf, gather, target_field)
  for _, suffix in ipairs({
    "",
    ":yank",
    ":permalink",
    ":permalink:yank",
    ":commit",
    ":commit:yank",
    ":commit:permalink",
    ":commit:permalink:yank",
    ":pr",
    ":pr:yank",
  }) do
    require("gin.action").define(buf, "browse" .. suffix, function(target, range)
      local root = vim.b[target].gin_worktree
      for _, row in ipairs(gather(target, range)) do
        local args = {}
        if suffix:find(":yank", 1, true) then
          args[#args + 1] = "++yank=" .. vim.v.register
        end
        if suffix:find(":permalink", 1, true) then
          args[#args + 1] = "--permalink"
        end
        if suffix:find(":pr", 1, true) then
          args[#args + 1] = "--pr"
        end
        if suffix:find(":commit", 1, true) then
          args[#args + 1] = "--commit"
        end
        if not row.path then
          args[#args + 1] = "++repository"
        end
        args[#args + 1] = target_field and require("gin.candidate").field(row, target_field)
          or row.target
          or row.commit
          or "HEAD"
        if row.path then
          args[#args + 1] = root .. "/" .. row.path
        end
        M.command({ fargs = args, range = 0 })
      end
    end)
  end
end

return M
