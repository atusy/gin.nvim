local M = {}
local git = require("gin.git")
local function encode(path)
  return vim.uri_encode(path, "rfc3986"):gsub("%%2[Ff]", "/")
end

function M.url(root, revision, options)
  options = options or {}
  revision = revision or "HEAD"
  local remote = options.remote or "origin"
  local fetch = vim.trim(git.run({ "remote", "get-url", remote }, { cwd = root }).stdout)
  local host, repository = fetch:match("^%w+://[^/]-@([^/]+)/(.+)$")
  if not host then
    host, repository = fetch:match("^%w+://([^/]+)/(.+)$")
  end
  if not host then
    host, repository = fetch:match("^[^@]+@([^:]+):(.+)$")
  end
  assert(host and repository, "Unsupported remote URL: " .. fetch)
  repository = repository:gsub("%.git$", ""):gsub("/$", "")
  local provider = (options.aliases or vim.g.gin_browse_aliases or {})[host] or host
  assert(
    vim.tbl_contains({ "github.com", "gitlab.com", "bitbucket.org" }, provider),
    "Unsupported hosting service: " .. provider
  )
  local base = "https://" .. host .. "/" .. encode(repository)
  if options.home then
    return base
  end
  local hash =
    vim.trim(git.run({ "rev-parse", "--verify", revision .. "^{commit}" }, { cwd = root }).stdout)
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
  local range = not tree and options.range
  if provider == "bitbucket.org" then
    route = range and path:match("%.md$") and "annotate" or "src"
    if range then
      suffix = "#lines-" .. range[1] .. (range[2] ~= range[1] and ":" .. range[2] or "")
    end
  else
    if provider == "gitlab.com" then
      route = "-/" .. route
    end
    if range then
      suffix = "?plain=1#L"
        .. range[1]
        .. (range[2] ~= range[1] and (provider == "github.com" and "-L" or "-") .. range[2] or "")
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
  local args = vim.deepcopy(vim.g.gin_browse_persistent_args or {})
  vim.list_extend(args, #opts.fargs == 0 and (vim.g.gin_browse_default_args or {}) or opts.fargs)
  local options, residue = require("gin.command").parse(args, { "worktree", "repository", "yank" })
  local positional = {}
  for _, arg in ipairs(residue) do
    local remote = arg:match("^%-%-remote=(.+)$")
    if remote then
      options.remote = remote
    elseif arg == "--home" then
      options.home = true
    elseif arg == "--commit" then
      options.commit = true
    elseif arg == "--permalink" then
      options.permalink = true
    elseif arg == "--no-browser" or arg == "-n" then
      options.no_browser = true
    else
      assert(arg:sub(1, 1) ~= "-", "Unsupported GinBrowse flag: " .. arg)
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
    if opts.range and opts.range > 0 then
      options.range = { opts.line1, opts.line2 }
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

return M
