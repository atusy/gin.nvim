if vim.b.current_syntax then
  return
end
vim.cmd("syntax clear")
for name, target in pairs({
  Hash = "Constant",
  Selector = "Special",
  Action = "Title",
  Deco = "Identifier",
}) do
  vim.api.nvim_set_hl(0, "GinReflog" .. name, { default = true, link = target })
end
vim.cmd([[
  syntax match GinReflogHash /^[0-9a-f]\{7,\}/ nextgroup=GinReflogDeco,GinReflogSelector skipwhite
  syntax match GinReflogDeco /([^)]*)/ contained nextgroup=GinReflogSelector skipwhite
  syntax match GinReflogSelector /\S\+@{\d\+}/ contained nextgroup=GinReflogAction
  syntax match GinReflogAction /: [^:]\+:/hs=s+2,he=e-1 contained
]])
vim.b.current_syntax = "gin_reflog"
