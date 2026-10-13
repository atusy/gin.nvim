local M = {}
local function encode(value)
  return vim.uri_encode(tostring(value), "rfc3986")
end

function M.format(scheme, root, params, fragment, param_order)
  local query, seen = {}, {}
  local keys =
    vim.list_extend(vim.list_slice(param_order or {}), vim.fn.sort(vim.tbl_keys(params or {})))
  for _, key in ipairs(keys) do
    if not seen[key] then
      seen[key] = true
      local values = type(params[key]) == "table" and params[key] or { params[key] }
      for _, value in ipairs(values) do
        query[#query + 1] = encode(key) .. "=" .. encode(value)
      end
    end
  end
  return scheme
    .. "://"
    .. encode(root):gsub("%%2F", "/")
    .. (#query > 0 and "?" .. table.concat(query, "&") or "")
    .. (fragment and "#" .. encode(fragment) .. "$" or "")
end

local function legacy_decode(value, excludes)
  return (
    value:gsub("%%(%x%x)", function(hex)
      return excludes and excludes[hex:upper()] and "%" .. hex or string.char(tonumber(hex, 16))
    end)
  )
end

function M.parse(name)
  local scheme, rest = name:match("^(gin[%w]*)://(.*)$")
  assert(scheme, "Invalid Gin URI: " .. name)
  local head = rest:match("^[^#]*")
  local legacy = not head:find("?", 1, true)
    and (head:find(";", 1, true) or (rest:find("#", 1, true) and rest:sub(-1) ~= "$"))
  if legacy then
    rest = legacy_decode(rest, { ["25"] = true, ["3B"] = true, ["23"] = true })
  end
  local expr, fragment = rest:match(legacy and "^(.-)#(.*)$" or "^(.-)#(.*)%$$")
  expr = expr or rest
  local root, query = expr:match(legacy and "^(.-);(.*)$" or "^(.-)%?(.*)$")
  if legacy and query then
    query = legacy_decode(query, { ["25"] = true })
  end
  local params, param_order = {}, {}
  for record in (query or ""):gmatch("[^&]+") do
    local key, value = record:match("^([^=]+)=(.*)$")
    if not key then
      key, value = record, ""
    end
    if legacy then
      key, value = key:gsub("%+", " "), value:gsub("%+", " ")
    end
    key, value = vim.uri_decode(key), vim.uri_decode(value)
    if params[key] == nil then
      params[key] = value
      param_order[#param_order + 1] = key
    else
      if type(params[key]) ~= "table" then
        params[key] = { params[key] }
      end
      table.insert(params[key], value)
    end
  end
  return {
    scheme = scheme,
    root = vim.uri_decode(root or expr),
    params = params,
    param_order = param_order,
    fragment = fragment and vim.uri_decode(fragment) or nil,
  }
end

---Escape whitespace and backslashes using the user command's argument syntax.
function M.join(args)
  local escaped = {}
  for _, arg in ipairs(args) do
    escaped[#escaped + 1] = arg:gsub("\\", "\\\\"):gsub("%s", "\\%0")
  end
  return table.concat(escaped, " ")
end

function M.split(fragment)
  local args, current, escaped = {}, {}, false
  for char in fragment:gmatch(".") do
    if escaped then
      current[#current + 1], escaped = char, false
    elseif char == "\\" then
      escaped = true
    elseif char:match("%s") then
      if #current > 0 then
        args[#args + 1], current = table.concat(current), {}
      end
    else
      current[#current + 1] = char
    end
  end
  if escaped then
    current[#current + 1] = "\\"
  end
  if #current > 0 then
    args[#args + 1] = table.concat(current)
  end
  return args
end

return M
