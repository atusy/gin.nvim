if vim.b.current_syntax then
  return
end
vim.cmd("syntax clear")
vim.api.nvim_set_hl(0, "GinBlameLineNumber", { default = true, link = "LineNr" })
vim.api.nvim_set_hl(0, "GinBlameTime", { fg = "#87afaf", ctermfg = 109 })
vim.api.nvim_set_hl(0, "GinBlameAuthor", {
  fg = "#ffaf5f",
  ctermfg = 215,
  bold = true,
  cterm = { bold = true },
})
vim.api.nvim_set_hl(0, "GinBlameSummary", { default = true, link = "Normal" })
vim.cmd([[
  syntax match GinBlameLineNumber /\v^\s*\d+/ containedin=ALLBUT,GinBlameLineNumber nextgroup=GinBlameTime skipwhite
  syntax match GinBlameTime /\v(just now|in \d+ \w+|\d+ \w+ ago)\t/ contained nextgroup=GinBlameAuthor
  syntax match GinBlameAuthor /\v[^\t]+\t/ contained nextgroup=GinBlameSummary
  syntax match GinBlameSummary /\v.+$/ contained
]])
vim.b.current_syntax = "gin_blame_nav"
