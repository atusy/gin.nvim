if vim.b.current_syntax ~= nil then
  return
end
vim.cmd("syntax clear")
require("gin.blame").highlights()
vim.cmd([[
  syntax match GinBlameLineNumber /\v^\s*\d+/ containedin=ALLBUT,GinBlameLineNumber nextgroup=GinBlameTime skipwhite
  syntax match GinBlameTime /\v(just now|in \d+ \w+|\d+ \w+ ago)\t/ contained nextgroup=GinBlameAuthor
  syntax match GinBlameAuthor /\v[^\t]+\t/ contained nextgroup=GinBlameSummary
  syntax match GinBlameSummary /\v.+$/ contained
]])
vim.b.current_syntax = "gin_blame_nav"
