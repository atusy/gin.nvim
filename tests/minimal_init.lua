vim.env.GIT_CONFIG_NOSYSTEM = "1"
vim.env.GIT_CONFIG_GLOBAL = "/dev/null"
local prefix = vim.fs.dirname(vim.fs.dirname(vim.uv.fs_realpath(vim.v.progpath)))
vim.opt.rtp = {
  vim.fn.getcwd(),
  prefix .. "/lib/nvim",
  vim.env.VIMRUNTIME,
  vim.fn.getcwd() .. "/.deps/mini.nvim",
}
vim.opt.packpath = {}
require("mini.test").setup({
  collect = {
    find_files = function()
      return vim.fn.glob("tests/test_*.lua", false, true)
    end,
  },
  execute = { reporter = require("mini.test").gen_reporter.stdout({ quit_on_finish = true }) },
})
