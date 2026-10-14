-- Experimental no-flags ECMAScript candidate; not used by Gin actions.
local M = {}
local function units(text)
  local result = {}
  for index, part in ipairs(vim.split(text, "\0", { plain = true })) do
    if index > 1 then
      result[#result + 1] = 0
    end
    for _, cp in ipairs(vim.fn.str2list(part, true)) do
      if cp > 0xFFFF then
        cp = cp - 0x10000
        result[#result + 1] = 0xD800 + math.floor(cp / 0x400)
        result[#result + 1] = 0xDC00 + cp % 0x400
      else
        result[#result + 1] = cp
      end
    end
  end
  return result
end
local function ascii(cp)
  return cp and cp < 128 and string.char(cp) or ""
end
local function copy(captures)
  local result = {}
  for key, value in pairs(captures) do
    result[key] = value
  end
  return result
end
local function word(cp)
  return cp ~= nil
    and (cp == 95 or cp >= 48 and cp <= 57 or cp >= 65 and cp <= 90 or cp >= 97 and cp <= 122)
end
local function space(cp)
  return cp ~= nil
    and (
      cp >= 9 and cp <= 13
      or cp == 32
      or cp == 160
      or cp == 0x1680
      or cp >= 0x2000 and cp <= 0x200A
      or cp == 0x2028
      or cp == 0x2029
      or cp == 0x202F
      or cp == 0x205F
      or cp == 0x3000
      or cp == 0xFEFF
    )
end
local function class_matches(node, cp)
  if cp == nil then
    return false
  end
  local found = false
  for _, item in ipairs(node.items) do
    if item.kind == "range" then
      found = found or (cp >= item.first and cp <= item.last)
    elseif item.kind == "literal" then
      found = found or cp == item.value
    else
      local hit = item.name:lower() == "d" and cp >= 48 and cp <= 57
        or item.name:lower() == "w" and word(cp)
        or item.name:lower() == "s" and space(cp)
      if item.name == item.name:upper() then
        hit = not hit
      end
      found = found or hit
    end
  end
  return node.negated and not found or not node.negated and found
end

function M.compile(pattern)
  local source, cursor, count, names = units(pattern), 1, 0, {}
  local function peek()
    return ascii(source[cursor])
  end
  local function take(char)
    if peek() == char then
      cursor = cursor + 1
      return true
    end
    return false
  end
  local function expect(char)
    assert(take(char), "Invalid regular expression: expected " .. char)
  end
  local function literal(value)
    return { kind = "literal", value = value }
  end
  local function escape(in_class)
    local cp = assert(source[cursor], "Invalid regular expression: trailing escape")
    cursor = cursor + 1
    local char = ascii(cp)
    if char:match("^[dDsSwW]$") then
      return { kind = "class", items = { { kind = "builtin", name = char } } }
    end
    if not in_class and (char == "b" or char == "B") then
      return { kind = "boundary", negated = char == "B" }
    end
    local controls = { b = 8, f = 12, n = 10, r = 13, t = 9, v = 11 }
    if controls[char] then
      return literal(controls[char])
    end
    if char == "x" or char == "u" then
      local digits = char == "x" and 2 or 4
      local value = ""
      for offset = 0, digits - 1 do
        value = value .. ascii(source[cursor + offset])
      end
      if #value == digits and value:match("^%x+$") then
        cursor = cursor + digits
        return literal(tonumber(value, 16))
      end
      return literal(cp)
    end
    if char == "c" then
      local next_char = peek()
      if next_char:match("^[A-Za-z]$") then
        cursor = cursor + 1
        return literal(string.byte(next_char:upper()) % 32)
      end
      error("Unsupported regular expression: invalid control escape")
    end
    if not in_class and char == "k" and take("<") then
      local name = ""
      while source[cursor] and peek() ~= ">" do
        assert(peek() ~= "", "Unsupported regular expression: non-ASCII capture name")
        name = name .. peek()
        cursor = cursor + 1
      end
      expect(">")
      return { kind = "reference", name = name }
    end
    if char:match("^[0-9]$") then
      local digits = char
      while peek():match("^[0-9]$") do
        digits = digits .. peek()
        cursor = cursor + 1
      end
      if digits == "0" then
        return literal(0)
      end
      assert(char ~= "0", "Unsupported regular expression: legacy octal escape")
      assert(not in_class, "Unsupported regular expression: class decimal escape")
      return { kind = "reference", number = tonumber(digits) }
    end
    return literal(cp)
  end
  local disjunction
  local function atom()
    if take("^") then
      return { kind = "start" }
    elseif take("$") then
      return { kind = "finish" }
    elseif take(".") then
      return { kind = "dot" }
    elseif take("\\") then
      return escape(false)
    elseif take("[") then
      local node = { kind = "class", items = {}, negated = take("^") }
      local function item()
        if take("\\") then
          return escape(true)
        end
        local value = assert(source[cursor], "Invalid regular expression: unclosed class")
        cursor = cursor + 1
        return literal(value)
      end
      while source[cursor] and peek() ~= "]" do
        local first = item()
        if peek() == "-" and ascii(source[cursor + 1]) ~= "]" and source[cursor + 1] then
          cursor = cursor + 1
          local last = item()
          assert(
            first.kind == "literal" and last.kind == "literal",
            "Unsupported regular expression: class escape range"
          )
          assert(first.value <= last.value, "Invalid regular expression: reversed range")
          node.items[#node.items + 1] = { kind = "range", first = first.value, last = last.value }
        elseif first.kind == "class" then
          vim.list_extend(node.items, first.items)
        else
          node.items[#node.items + 1] = first
        end
      end
      expect("]")
      return node
    elseif take("(") then
      local kind, positive, direction, number = "capture", true, 1, nil
      local name
      if take("?") then
        if take(":") then
          kind = "group"
        elseif take("=") then
          kind = "look"
        elseif take("!") then
          kind, positive = "look", false
        elseif take("<") then
          if take("=") then
            kind, direction = "look", -1
          elseif take("!") then
            kind, direction, positive = "look", -1, false
          else
            name = ""
            while source[cursor] and peek() ~= ">" do
              assert(peek() ~= "", "Unsupported regular expression: non-ASCII capture name")
              name = name .. peek()
              cursor = cursor + 1
            end
            expect(">")
            assert(
              name:match("^[A-Za-z_$][A-Za-z0-9_$]*$") and not names[name],
              "Unsupported or invalid capture name"
            )
          end
        else
          error("Invalid regular expression: group prefix")
        end
      end
      if kind == "capture" then
        count = count + 1
        number = count
        if name then
          names[name] = number
        end
      end
      local child = disjunction()
      expect(")")
      return {
        kind = kind,
        child = child,
        number = number,
        positive = positive,
        direction = direction,
      }
    end
    assert(
      source[cursor] and not peek():match("^[*+?)]$"),
      "Invalid regular expression: unexpected token"
    )
    local node = literal(source[cursor])
    cursor = cursor + 1
    return node
  end
  local function term()
    local first_capture = count + 1
    local node = atom()
    local minimum, maximum
    if take("*") then
      minimum, maximum = 0, math.huge
    elseif take("+") then
      minimum, maximum = 1, math.huge
    elseif take("?") then
      minimum, maximum = 0, 1
    elseif peek() == "{" then
      local start = cursor
      cursor = cursor + 1
      local digits = ""
      while peek():match("^[0-9]$") do
        digits = digits .. peek()
        cursor = cursor + 1
      end
      if digits ~= "" then
        minimum, maximum = tonumber(digits), tonumber(digits)
        if take(",") then
          digits = ""
          while peek():match("^[0-9]$") do
            digits = digits .. peek()
            cursor = cursor + 1
          end
          maximum = tonumber(digits) or math.huge
        end
      end
      if not minimum or not take("}") then
        cursor, minimum, maximum = start, nil, nil
      end
    end
    if minimum then
      assert(minimum <= maximum, "Invalid regular expression: quantifier bounds")
      assert(
        node.kind ~= "start"
          and node.kind ~= "finish"
          and node.kind ~= "boundary"
          and not (node.kind == "look" and node.direction == -1),
        "Invalid regular expression: quantified assertion"
      )
      node = {
        kind = "repeat",
        child = node,
        minimum = minimum,
        maximum = maximum,
        lazy = take("?"),
        first_capture = first_capture,
        last_capture = count,
      }
    end
    return node
  end
  function disjunction()
    local alternatives = {}
    repeat
      local sequence = {}
      while source[cursor] and peek() ~= ")" and peek() ~= "|" do
        sequence[#sequence + 1] = term()
      end
      alternatives[#alternatives + 1] = { kind = "sequence", children = sequence }
    until not take("|")
    return { kind = "alternation", children = alternatives }
  end
  local tree = disjunction()
  assert(cursor > #source, "Invalid regular expression: unmatched parenthesis")
  local function validate(node)
    if node.kind == "reference" then
      node.number = node.number or names[node.name]
      assert(
        node.number and node.number <= count,
        "Unsupported or invalid regular expression: backreference"
      )
    end
    if node.child then
      validate(node.child)
    end
    for _, child in ipairs(node.children or {}) do
      validate(child)
    end
  end
  validate(tree)

  return {
    match = function(_, text)
      local input = units(text)
      local evaluate
      local function accept(position, captures)
        return { position = position, captures = captures }
      end
      function evaluate(node, position, captures, direction, continuation)
        local kind = node.kind
        if kind == "sequence" then
          local function next_child(index, pos, caps)
            if not node.children[index] then
              return continuation(pos, caps)
            end
            return evaluate(node.children[index], pos, caps, direction, function(p, c)
              return next_child(index + direction, p, c)
            end)
          end
          return next_child(direction == 1 and 1 or #node.children, position, captures)
        elseif kind == "alternation" then
          for _, child in ipairs(node.children) do
            local result = evaluate(child, position, captures, direction, continuation)
            if result then
              return result
            end
          end
        elseif kind == "group" then
          return evaluate(node.child, position, captures, direction, continuation)
        elseif kind == "capture" then
          return evaluate(node.child, position, captures, direction, function(pos, caps)
            caps = copy(caps)
            caps[node.number] = { math.min(position, pos), math.max(position, pos) }
            return continuation(pos, caps)
          end)
        elseif kind == "look" then
          local result = evaluate(node.child, position, captures, node.direction, accept)
          if (result ~= nil) == node.positive then
            return continuation(position, result and result.captures or captures)
          end
        elseif kind == "repeat" then
          local function repeat_match(iteration, pos, caps)
            if node.lazy and iteration >= node.minimum then
              local result = continuation(pos, caps)
              if result then
                return result
              end
            end
            if iteration < node.maximum then
              local cleared = copy(caps)
              for index = node.first_capture, node.last_capture do
                cleared[index] = nil
              end
              local result = evaluate(node.child, pos, cleared, direction, function(p, c)
                if p == pos and iteration >= node.minimum then
                  return nil
                end
                return repeat_match(iteration + 1, p, c)
              end)
              if result then
                return result
              end
            end
            if not node.lazy and iteration >= node.minimum then
              return continuation(pos, caps)
            end
          end
          return repeat_match(0, position, captures)
        elseif kind == "start" or kind == "finish" or kind == "boundary" then
          local matched = kind == "start" and position == 1
            or kind == "finish" and position == #input + 1
          if kind == "boundary" then
            matched = word(input[position - 1]) ~= word(input[position])
            if node.negated then
              matched = not matched
            end
          end
          if matched then
            return continuation(position, captures)
          end
        elseif kind == "reference" then
          local capture = captures[node.number]
          local length = capture and capture[2] - capture[1] or 0
          local start = direction == 1 and position or position - length
          for offset = 0, length - 1 do
            if input[start + offset] ~= input[capture[1] + offset] then
              return nil
            end
          end
          return continuation(position + length * direction, captures)
        else
          local cp = input[direction == 1 and position or position - 1]
          local matched = kind == "literal" and cp == node.value
            or kind == "class" and class_matches(node, cp)
            or kind == "dot"
              and cp ~= nil
              and cp ~= 10
              and cp ~= 13
              and cp ~= 0x2028
              and cp ~= 0x2029
          if matched then
            return continuation(position + direction, captures)
          end
        end
      end
      for start = 1, #input + 1 do
        local result = evaluate(tree, start, {}, 1, accept)
        if result then
          result.captures[0] = { start, result.position }
          local captures = {}
          for index = 0, count do
            local span = result.captures[index]
            captures[index + 1] = span and vim.list_slice(input, span[1], span[2] - 1) or vim.NIL
          end
          return captures
        end
      end
    end,
  }
end
return M
