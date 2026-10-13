local M = {}

function M.reset(buf)
  local plugs = {}
  for _, name in ipairs({ "diffput", "diffget", "diffget-l", "diffget-r" }) do
    plugs["<Plug>(gin-" .. name .. ")"] = true
  end
  local defaults = { dp = true, ["do"] = true, dol = true, dor = true }
  for _, mode in ipairs({ "n", "x" }) do
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
      if plugs[mapping.lhs] or (defaults[mapping.lhs] and plugs[mapping.rhs]) then
        vim.keymap.del(mode, mapping.lhs, { buffer = buf })
      end
    end
  end
end

function M.bind(buf, name, command, target, default, disabled)
  vim.keymap.set({ "n", "x" }, "<Plug>(gin-" .. name .. ")", function()
    local range = vim.fn.mode() ~= "n" and require("gin.action").range() or nil
    vim.api.nvim_cmd({ cmd = command, args = { tostring(target) }, range = range }, {})
    vim.cmd.diffupdate()
  end, { buffer = buf, silent = true })
  if not disabled then
    vim.keymap.set(
      { "n", "x" },
      default,
      "<Plug>(gin-" .. name .. ")",
      { buffer = buf, remap = true }
    )
  end
end

function M.alias(buf, to, disabled)
  vim.keymap.set(
    { "n", "x" },
    "<Plug>(gin-diffget)",
    "<Plug>(gin-" .. to .. ")",
    { buffer = buf, remap = true }
  )
  if not disabled then
    vim.keymap.set({ "n", "x" }, "do", "<Plug>(gin-diffget)", { buffer = buf, remap = true })
  end
end

return M
