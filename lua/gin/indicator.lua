local M = {}
local active, generation = 0, 0
local saved

function M.open()
  if active == 0 then
    saved = { more = vim.o.more, cmdheight = vim.o.cmdheight }
    vim.o.more = false
    generation = generation + 1
  end
  active = active + 1
  local closed = false
  return {
    write = vim.schedule_wrap(function(_, data)
      if closed or not data then
        return
      end
      local text = vim.trim(data:gsub("\27%[[%d;]*m", ""))
      if text == "" then
        return
      end
      local height = #vim.split(text, "\n", { plain = true })
      vim.o.cmdheight = math.max(vim.o.cmdheight, math.min(height, math.max(1, vim.o.lines - 1)))
      vim.cmd.redraw()
      vim.api.nvim_echo({ { text, "None" } }, false, {})
      generation = generation + 1
      local version = generation
      vim.defer_fn(function()
        if saved and version == generation then
          vim.o.cmdheight = saved.cmdheight
        end
      end, 500)
    end),
    close = function()
      if closed then
        return
      end
      closed = true
      active = active - 1
      if active == 0 then
        generation = generation + 1
        vim.o.more, vim.o.cmdheight = saved.more, saved.cmdheight
        saved = nil
      end
    end,
  }
end

return M
