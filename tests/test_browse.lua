local H = require("tests.helpers")
local root, hash
local cwd = vim.fn.getcwd()
local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      root = H.repo()
      vim.fn.mkdir(root .. "/sub", "p")
      vim.fn.writefile({ "one", "two" }, root .. "/sub/space # file.md")
      H.git(root, "add", ".")
      H.git(root, "commit", "-m", "initial")
      hash = vim.trim(H.git(root, "rev-parse", "HEAD"))
      H.git(root, "remote", "add", "origin", "git@github.com:owner/repo.git")
      vim.cmd.cd(root)
      dofile(cwd .. "/plugin/gin.lua")
    end,
    post_case = function()
      vim.g.gin_browse_persistent_args = nil
      vim.g.gin_browse_aliases = nil
      vim.cmd.enew({ bang = true })
      vim.cmd.cd(cwd)
      H.cleanup(root)
    end,
  },
})
for _, value in ipairs({
  false,
  vim.NIL,
  0,
  "github.com",
  {},
  { "github.com" },
  { unused = false },
  { unused = vim.NIL },
  { unused = {} },
}) do
  T["browse rejects invalid aliases " .. vim.inspect(value) .. " before yanking or opening"] = function()
    vim.g.gin_browse_aliases = value
    local opened, open = {}, vim.ui.open
    local register = vim.fn.getreginfo("a")
    vim.fn.setreg("a", "keep me")
    vim.ui.open = function(url)
      opened[#opened + 1] = url
    end
    local ok, err = pcall(function()
      MiniTest.expect.error(function()
        vim.cmd("GinBrowse ++yank=a --home")
      end, "g:gin_browse_aliases must be a dictionary of strings")
      MiniTest.expect.equality(vim.fn.getreg("a"), "keep me")
      MiniTest.expect.equality(opened, {})
    end)
    vim.ui.open = open
    vim.fn.setreg("a", register)
    assert(ok, err)
  end
end
T["browse accepts an explicit empty alias dictionary"] = function()
  vim.g.gin_browse_aliases = vim.empty_dict()
  MiniTest.expect.equality(
    require("gin.browse").url(root, "HEAD", { home = true }),
    "https://github.com/owner/repo"
  )
end
for _, case in ipairs({
  { "github.com", "blob", "?plain=1#L1-L2" },
  { "gitlab.com", "-/blob", "?plain=1#L1-2" },
  { "bitbucket.org", "annotate", "#lines-1:2" },
}) do
  T[case[1] .. " aliases retain the custom host and select provider routes"] = function()
    H.git(root, "remote", "set-url", "origin", "git@code.example.invalid:owner/repo.git")
    vim.g.gin_browse_aliases = { ["code.example.invalid"] = case[1] }
    MiniTest.expect.equality(
      require("gin.browse").url(root, "HEAD", { home = true }),
      "https://code.example.invalid/owner/repo"
    )
    local url = require("gin.browse").url(root, "HEAD", {
      path = "sub/space # file.md",
      range = { 1, 2 },
      permalink = true,
    })
    MiniTest.expect.equality(
      url,
      "https://code.example.invalid/owner/repo/"
        .. case[2]
        .. "/"
        .. hash
        .. "/sub/space%20%23%20file.md"
        .. case[3]
    )
  end
end
for _, remote in ipairs({
  "https://github.com/own%65r/repo%2Dname.git",
  "ssh://git@github.com/own%65r/repo%2Dname.git",
  "git@github.com:own%65r/repo%2Dname.git",
}) do
  T["browse preserves existing remote percent escapes " .. remote] = function()
    H.git(root, "remote", "set-url", "origin", remote)
    local base = "https://github.com/own%65r/repo%2Dname"
    MiniTest.expect.equality(require("gin.browse").url(root, "HEAD", { home = true }), base)
    MiniTest.expect.equality(
      require("gin.browse").url(root, "HEAD", { path = "sub/space # file.md", permalink = true }),
      base .. "/blob/" .. hash .. "/sub/space%20%23%20file.md"
    )
    MiniTest.expect.equality(H.git(root, "remote", "get-url", "origin"), remote .. "\n")
  end
end
T["browse still escapes literal percent bytes in Git filenames"] = function()
  local path = "sub/file%20name.md"
  vim.fn.writefile({ "percent filename" }, root .. "/" .. path)
  H.git(root, "add", "--", path)
  H.git(root, "commit", "-m", "percent filename")
  H.git(root, "remote", "set-url", "origin", "https://github.com/owner/repo%2520name.git")
  MiniTest.expect.equality(
    require("gin.browse").url(root, "HEAD", { path = path }),
    "https://github.com/owner/repo%2520name/blob/main/sub/file%2520name.md"
  )
end
for _, remote in ipairs({
  "HTTPS://GitHub.COM/owner/repo.git",
  "https://github.com/owner/repo.git/",
  "https://github.com/owner/repo.git?transport=value",
  "https://github.com/owner/repo.git#anchor",
  "https://reader:unused@github.com/owner/repo.git?transport=value#anchor",
  "ssh://git@github.com:2222/owner/repo.git?transport=value#anchor",
  "git+ssh://git@github.com/owner/repo.git",
}) do
  T["browse normalizes remote URL components " .. remote] = function()
    H.git(root, "remote", "set-url", "origin", remote)
    local base = "https://github.com/owner/repo"
    MiniTest.expect.equality(require("gin.browse").url(root, "HEAD", { home = true }), base)
    MiniTest.expect.equality(
      require("gin.browse").url(root, "HEAD", { commit = true }),
      base .. "/commit/" .. hash
    )
    MiniTest.expect.equality(H.git(root, "remote", "get-url", "origin"), remote .. "\n")
  end
end
T["browse builds encoded file ranges and immutable permalinks"] = function()
  local url = require("gin.browse").url(
    root,
    "HEAD",
    { path = "sub/space # file.md", range = { 1, 2 }, permalink = true }
  )
  MiniTest.expect.equality(
    url,
    "https://github.com/owner/repo/blob/" .. hash .. "/sub/space%20%23%20file.md?plain=1#L1-L2"
  )
end
T["browse supports home and commit routes across hosting services"] = function()
  for _, spec in ipairs({
    { "https://gitlab.com/group/sub/repo.git", "https://gitlab.com/group/sub/repo", "/-/commit/" },
    { "ssh://git@bitbucket.org/owner/repo.git", "https://bitbucket.org/owner/repo", "/commits/" },
  }) do
    H.git(root, "remote", "set-url", "origin", spec[1])
    MiniTest.expect.equality(require("gin.browse").url(root, "HEAD", { home = true }), spec[2])
    MiniTest.expect.equality(
      require("gin.browse").url(root, "HEAD", { commit = true }),
      spec[2] .. spec[3] .. hash
    )
  end
end
for _, case in ipairs({
  { "github.com", "github.com", "/blob/" },
  { "gitlab.com", "gitlab.com", "/-/blob/" },
  { "bitbucket.org", "bitbucket.org", "/src/" },
  { "git.example.invalid", "gitlab.com", "/-/blob/" },
}) do
  T["browse resolves SSH ports independently of the web host " .. case[1]] = function()
    local remote = "ssh://git@" .. case[1] .. ":2222/owner/repo.git"
    H.git(root, "remote", "set-url", "origin", remote)
    if case[1] ~= case[2] then
      vim.g.gin_browse_aliases = { [case[1]] = case[2] }
    end
    local base = "https://" .. case[1] .. "/owner/repo"
    MiniTest.expect.equality(require("gin.browse").url(root, "HEAD", { home = true }), base)
    MiniTest.expect.equality(
      require("gin.browse").url(root, "HEAD", { path = "sub/space # file.md", permalink = true }),
      base .. case[3] .. hash .. "/sub/space%20%23%20file.md"
    )
    MiniTest.expect.equality(H.git(root, "remote", "get-url", "origin"), remote .. "\n")
  end
end
for _, outcome in ipairs({ "success", "missing handler", "spawn failure" }) do
  T["GinBrowse dispatches its URL through the native opener: " .. outcome] = function()
    local open, system, executable = vim.ui.open, vim.system, vim.fn.executable
    local urls, launches = {}, {}
    local expected = "https://github.com/owner/repo/commit/" .. hash
    vim.ui.open = function(url)
      urls[#urls + 1] = url
      if outcome == "missing handler" then
        return nil, "browser handler unavailable"
      end
      return open(url)
    end
    vim.fn.executable = function(name)
      if
        vim.tbl_contains({ "xdg-open", "wslview", "rundll32", "explorer.exe", "lemonade" }, name)
      then
        return 1
      end
      return executable(name)
    end
    vim.system = function(command, options, callback)
      if command[1] == "git" then
        return system(command, options, callback)
      end
      launches[#launches + 1] = { command = command, options = options }
      if outcome == "spawn failure" then
        error("browser spawn failure", 0)
      end
      return {}
    end
    local ok, err = pcall(function()
      local function browse()
        vim.cmd("GinBrowse --commit ++yank=a HEAD")
      end
      if outcome == "success" then
        browse()
      else
        MiniTest.expect.error(
          browse,
          outcome == "missing handler" and "browser handler unavailable" or "browser spawn failure"
        )
      end
      MiniTest.expect.equality(urls, { expected })
      MiniTest.expect.equality(vim.fn.getreg("a"), expected)
      MiniTest.expect.equality(#launches, outcome == "missing handler" and 0 or 1)
      if #launches > 0 then
        local command = launches[1].command
        MiniTest.expect.equality(command[#command], expected)
        MiniTest.expect.equality(launches[1].options.detach, true)
      end
    end)
    vim.ui.open, vim.system, vim.fn.executable = open, system, executable
    assert(ok, err)
  end
end
T["GinBrowse bare yank options use the unnamed register"] = function()
  for _, option in ipairs({ "++yank", "++yank=" }) do
    vim.fn.setreg('"', "unchanged")
    vim.cmd("GinBrowse --home --no-browser " .. option)
    MiniTest.expect.equality(vim.fn.getreg('"'), "https://github.com/owner/repo")
  end
end
T["GinBrowse no-browser yanks a current-file URL with a range"] = function()
  vim.cmd.edit(vim.fn.fnameescape(root .. "/sub/space # file.md"))
  vim.cmd("1,2GinBrowse --no-browser ++yank=a")
  MiniTest.expect.equality(
    vim.fn.getreg("a"),
    "https://github.com/owner/repo/blob/main/sub/space%20%23%20file.md?plain=1#L1-L2"
  )
end
T["GinBrowse separates literal dash and plus-prefixed paths from flags"] = function()
  for _, path in ipairs({ "-note.md", "++repository" }) do
    vim.fn.writefile({ "content" }, root .. "/" .. path)
    H.git(root, "add", "--", path)
    H.git(root, "commit", "-m", "add literal path")
    vim.cmd("GinBrowse --no-browser ++yank=a HEAD -- " .. path)
    MiniTest.expect.equality(
      vim.fn.getreg("a"),
      "https://github.com/owner/repo/blob/main/" .. vim.uri_encode(path, "rfc3986")
    )
  end
end
T["GinBrowse uses flag presence and ignores unused parsed flags"] = function()
  for _, flags in ipairs({
    "--home=false --unused=value -nattached",
    "--home --home --no-browser=false",
  }) do
    vim.cmd("GinBrowse ++yank=a " .. flags)
    MiniTest.expect.equality(vim.fn.getreg("a"), "https://github.com/owner/repo")
  end
end
T["GinBrowse rejects repeated remote flags before opening or yanking"] = function()
  local open, opened = vim.ui.open, false
  vim.ui.open = function()
    opened = true
  end
  vim.fn.setreg("a", "unchanged")
  local ok, err = pcall(function()
    MiniTest.expect.error(function()
      vim.cmd("GinBrowse ++yank=a --remote=origin --remote=origin --home")
    end, "REMOTE in %-%-remote={REMOTE} must be string")
    MiniTest.expect.equality(vim.fn.getreg("a"), "unchanged")
    MiniTest.expect.equality(opened, false)
  end)
  vim.ui.open = open
  assert(ok, err)
end
for _, host in ipairs({ "github.com", "gitlab.com", "bitbucket.org" }) do
  T["GinBrowse accepts path line suffixes for " .. host] = function()
    H.git(root, "remote", "set-url", "origin", "https://" .. host .. "/owner/repo.git")
    local base = "https://" .. host .. "/owner/repo/"
    local route = host == "github.com" and "blob/"
      or host == "gitlab.com" and "-/blob/"
      or "annotate/"
    local path = "sub/space%20%23%20file.md"
    for _, case in ipairs({
      { ":0", "", "" },
      { ":1", "?plain=1#L1", "#lines-1" },
      { ":01:002", host == "github.com" and "?plain=1#L1-L2" or "?plain=1#L1-2", "#lines-1:2" },
      { ":1:2", host == "github.com" and "?plain=1#L1-L2" or "?plain=1#L1-2", "#lines-1:2" },
      { ":2:2", host == "github.com" and "?plain=1#L2-L2" or "?plain=1#L2-2", "#lines-2:2" },
    }) do
      require("gin.browse").command({
        fargs = { "--no-browser", "++yank=a", "HEAD", "sub/space # file.md" .. case[1] },
        range = 0,
      })
      MiniTest.expect.equality(
        vim.fn.getreg("a"),
        base
          .. (host == "bitbucket.org" and case[1] == ":0" and "src/" or route)
          .. "main/"
          .. path
          .. (host == "bitbucket.org" and case[3] or case[2])
      )
    end
    local tree = host == "github.com" and "tree/" or host == "gitlab.com" and "-/tree/" or "src/"
    MiniTest.expect.equality(
      require("gin.browse").url(root, "HEAD", { path = "sub:1:2" }),
      base .. tree .. "main/sub"
    )
  end
end
T["GinBrowse zero address omits the line fragment"] = function()
  vim.cmd.edit(vim.fn.fnameescape(root .. "/sub/space # file.md"))
  vim.cmd("0GinBrowse --no-browser ++yank=a")
  MiniTest.expect.equality(
    vim.fn.getreg("a"),
    "https://github.com/owner/repo/blob/main/sub/space%20%23%20file.md"
  )
end
T["browse selects a containing remote and prefers origin when both contain"] = function()
  H.git(root, "remote", "add", "upstream", "https://github.com/upstream/repo.git")
  H.git(root, "update-ref", "refs/remotes/upstream/main", hash)
  MiniTest.expect.equality(
    require("gin.browse").url(root, "HEAD", { home = true }),
    "https://github.com/upstream/repo"
  )
  H.git(root, "update-ref", "refs/remotes/origin/main", hash)
  MiniTest.expect.equality(
    require("gin.browse").url(root, "HEAD", { home = true }),
    "https://github.com/owner/repo"
  )
  MiniTest.expect.equality(
    require("gin.browse").url(root, "HEAD", { home = true, remote = "upstream" }),
    "https://github.com/upstream/repo"
  )
end
T["browse selects remotes by ancestry rather than the presence of any ref"] = function()
  H.git(root, "update-ref", "refs/remotes/origin/main", hash)
  vim.fn.writefile({ "new" }, root .. "/new")
  H.git(root, "add", "new")
  H.git(root, "commit", "-m", "new commit")
  H.git(root, "remote", "add", "upstream", "https://github.com/upstream/repo.git")
  H.git(root, "update-ref", "refs/remotes/upstream/main", "HEAD")
  MiniTest.expect.equality(
    require("gin.browse").url(root, "HEAD", { home = true }),
    "https://github.com/upstream/repo"
  )
  MiniTest.expect.equality(
    require("gin.browse").url(root, hash, { commit = true }),
    "https://github.com/owner/repo/commit/" .. hash
  )
end
T["status browse action uses the selected repository-relative path"] = function()
  vim.fn.writefile({ "modified" }, root .. "/sub/space # file.md")
  vim.g.gin_browse_persistent_args = { "--no-browser", "++worktree=" .. root }
  vim.cmd.cd(root .. "/sub")
  vim.cmd.GinStatus()
  require("gin.action").call(vim.api.nvim_get_current_buf(), "browse:permalink:yank", { 2, 2 })
  MiniTest.expect.equality(
    vim.fn.getreg('"'),
    "https://github.com/owner/repo/blob/" .. hash .. "/sub/space%20%23%20file.md"
  )
end
T["history browse commit action uses the selected commit"] = function()
  vim.g.gin_browse_persistent_args = { "--no-browser", "++worktree=" .. root }
  vim.cmd("GinLog --oneline")
  require("gin.action").call(vim.api.nvim_get_current_buf(), "browse:commit:yank", { 1, 1 })
  MiniTest.expect.equality(vim.fn.getreg('"'), "https://github.com/owner/repo/commit/" .. hash)
end
T["browse PR finds a merge containing the selected commit"] = function()
  H.git(root, "checkout", "-b", "topic")
  vim.fn.writefile({ "topic" }, root .. "/topic")
  H.git(root, "add", "topic")
  H.git(root, "commit", "-m", "topic change")
  local topic = vim.trim(H.git(root, "rev-parse", "HEAD"))
  H.git(root, "checkout", "main")
  H.git(root, "merge", "--no-ff", "-m", "Merge pull request #42 from owner/topic", "topic")
  H.git(root, "update-ref", "refs/remotes/origin/main", "HEAD")
  H.git(root, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
  MiniTest.expect.equality(
    require("gin.browse").url(root, topic, { pr = true }),
    "https://github.com/owner/repo/pull/42"
  )
  vim.cmd("GinBrowse --pr --no-browser ++repository ++yank=a HEAD")
  MiniTest.expect.equality(vim.fn.getreg("a"), "https://github.com/owner/repo/pull/42")
end
for _, case in ipairs({
  { "github.com", "github.com", "Merge pull request #42 from owner/topic", "/pull/42" },
  { "gitlab.com", "gitlab.com", "See merge request owner/repo!42", "/-/merge_requests/42" },
  {
    "code.example.invalid",
    "gitlab.com",
    "See merge request owner/repo!42",
    "/-/merge_requests/42",
  },
}) do
  T["browse finds request IDs in merge bodies and later ancestor merges for " .. case[1]] = function()
    H.git(root, "remote", "set-url", "origin", "https://" .. case[1] .. "/owner/repo.git")
    if case[1] ~= case[2] then
      vim.g.gin_browse_aliases = { [case[1]] = case[2] }
    end
    H.git(root, "checkout", "-b", "topic")
    H.git(root, "commit", "--allow-empty", "-m", "topic change")
    local topic = vim.trim(H.git(root, "rev-parse", "HEAD"))
    H.git(root, "checkout", "-b", "staging", "main")
    H.git(root, "merge", "--no-ff", "-m", "Integrate topic locally", "topic")
    H.git(root, "checkout", "main")
    H.git(root, "merge", "--no-ff", "-m", "Merge staging", "-m", case[3], "staging")
    H.git(root, "update-ref", "refs/remotes/origin/trunk", "HEAD")
    H.git(root, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/trunk")
    local expected = "https://" .. case[1] .. "/owner/repo" .. case[4]
    MiniTest.expect.equality(require("gin.browse").url(root, topic, { pr = true }), expected)
    vim.cmd("GinBrowse --pr --no-browser ++repository ++yank=a HEAD")
    MiniTest.expect.equality(vim.fn.getreg("a"), expected)
    vim.g.gin_browse_persistent_args = { "--no-browser" }
    vim.cmd("GinLog --format=%H")
    require("gin.action").call(vim.api.nvim_get_current_buf(), "browse:pr:yank", { 1, 1 })
    MiniTest.expect.equality(vim.fn.getreg('"'), expected)
  end
end
for _, provider in ipairs({ "github.com", "gitlab.com" }) do
  T["browse PR reports a missing merge for " .. provider] = function()
    H.git(root, "remote", "set-url", "origin", "https://" .. provider .. "/owner/repo.git")
    H.git(root, "update-ref", "refs/remotes/origin/main", "HEAD")
    MiniTest.expect.error(function()
      require("gin.browse").url(root, "HEAD", { pr = true })
    end, "No pull request found")
  end
end
T["browse PR rejects providers without a request route"] = function()
  H.git(root, "remote", "set-url", "origin", "https://bitbucket.org/owner/repo.git")
  MiniTest.expect.error(function()
    require("gin.browse").url(root, "HEAD", { pr = true })
  end, "Hosting service has no pull request URL")
end
return T
