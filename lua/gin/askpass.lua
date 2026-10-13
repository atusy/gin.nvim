local M = {}
local requests, serial = {}, 0

function M.request(prompt)
  serial = serial + 1
  local id = serial
  requests[id] = { done = false }
  vim.schedule(function()
    local ok, value = pcall(vim.fn.inputsecret, prompt)
    requests[id] = { done = true, accepted = ok, value = ok and value or nil }
  end)
  return id
end

function M.poll(id)
  local result = assert(requests[id], "Unknown Git askpass request")
  if result.done then
    requests[id] = nil
  end
  return result
end
return M
