vim.env.GIT_CONFIG_NOSYSTEM = "1"
vim.env.GIT_CONFIG_GLOBAL = "/dev/null"
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.getcwd() .. "/.deps/mini.nvim")
require("mini.test").setup({
  collect = {
    find_files = function()
      return vim.fn.glob("tests/test_*.lua", false, true)
    end,
  },
  execute = { reporter = require("mini.test").gen_reporter.stdout({ quit_on_finish = true }) },
})
