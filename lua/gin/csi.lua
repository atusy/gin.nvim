local M = {}

-- Match the CSI grammar used by upstream ansi-escape-code, including private parameters.
M.pattern = "\27%[[0-?]*[!-/]*[@-~]"
M.partial = "\27%[[0-?]*[!-/]*$"

function M.strip(text)
  return (text:gsub(M.pattern, ""))
end

return M
