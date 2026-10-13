vim.env.GIT_CONFIG_NOSYSTEM = "1"
vim.env.GIT_CONFIG_GLOBAL = "/dev/null"
for _, name in ipairs({ "GIT_EDITOR", "GIT_SEQUENCE_EDITOR", "GIT_ASKPASS", "SSH_ASKPASS" }) do
  vim.env[name] = nil
end
local prefix = vim.fs.dirname(vim.fs.dirname(vim.uv.fs_realpath(vim.v.progpath)))
vim.opt.rtp = {
  vim.fn.getcwd(),
  prefix .. "/lib/nvim",
  vim.env.VIMRUNTIME,
  vim.fn.getcwd() .. "/.deps/mini.nvim",
}
vim.opt.packpath = { vim.env.VIMRUNTIME }
require("mini.test").setup({
  collect = {
    find_files = function()
      return vim.fn.glob("tests/test_*.lua", false, true)
    end,
  },
  execute = { reporter = require("mini.test").gen_reporter.stdout({ quit_on_finish = true }) },
})
