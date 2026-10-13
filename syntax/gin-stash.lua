if vim.b.current_syntax then
  return
end
vim.cmd("syntax clear")
for name, target in pairs({
  Ref = "Special",
  Type = "Title",
  Branch = "Identifier",
  Hash = "Constant",
}) do
  vim.api.nvim_set_hl(0, "GinStash" .. name, { default = true, link = target })
end
vim.cmd([[
  syntax match GinStashRef /^stash@{\d\+}/
  syntax match GinStashType /: \%(WIP on\|On\) /ms=s+2,me=e-1 nextgroup=GinStashBranch skipwhite
  syntax match GinStashBranch /[^:]\+\ze:/ contained
  syntax match GinStashHash /: \zs[0-9a-f]\{7,\}\ze /
]])
vim.b.current_syntax = "gin_stash"
