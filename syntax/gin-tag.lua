if vim.b.current_syntax ~= nil then
  return
end
vim.cmd("syntax clear")
for name, target in pairs({
  Hash = "Constant",
  Name = "Special",
  Date = "Title",
  Subject = "Comment",
}) do
  vim.api.nvim_set_hl(0, "GinTag" .. name, { default = true, link = target })
end
vim.cmd([[
  syntax match GinTagHash /^[0-9a-f]\{7,\}/ nextgroup=GinTagName skipwhite
  syntax match GinTagName /\S\+/ contained nextgroup=GinTagDate skipwhite
  syntax match GinTagDate /\d\{4\}-\d\{2\}-\d\{2\}/ contained nextgroup=GinTagSubject skipwhite
  syntax match GinTagSubject /.*/ contained
]])
vim.b.current_syntax = "gin_tag"
