-- Experimental no-flags ECMAScript candidate; not used by Gin actions.
local M = {}
local casefold = require("tests.audit.regex_casefold")
local equivalents = {}
for cp, canonical in pairs(casefold) do
  equivalents[canonical] = equivalents[canonical] or { canonical }
  table.insert(equivalents[canonical], cp)
end
local function same_char(a, b, ignore_case)
  if ignore_case then
    return (casefold[a] or a) == (casefold[b] or b)
  end
  return a == b
end
local function line_terminator(cp)
  return cp == 10 or cp == 13 or cp == 0x2028 or cp == 0x2029
end
local identifiers = require("tests.audit.unicode_identifiers")
local function identifier_char(cp, first)
  if cp == 36 or cp == 95 or not first and (cp == 0x200C or cp == 0x200D) then
    return true
  end
  local ranges = first and identifiers.ID_Start or identifiers.ID_Continue
  local low, high = 1, #ranges
  while low <= high do
    local middle = math.floor((low + high) / 2)
    local range = ranges[middle]
    if cp < range[1] then
      high = middle - 1
    elseif cp > range[2] then
      low = middle + 1
    else
      return true
    end
  end
  return false
end
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
local function capture_string(capture)
  local parts, index = {}, 1
  while index <= #capture do
    local cp = capture[index]
    index = index + 1
    if cp >= 0xD800 and cp <= 0xDBFF then
      local trail = capture[index]
      assert(
        trail and trail >= 0xDC00 and trail <= 0xDFFF,
        "Cannot convert regular expression capture: unpaired surrogate"
      )
      cp = 0x10000 + (cp - 0xD800) * 0x400 + trail - 0xDC00
      index = index + 1
    else
      assert(
        cp < 0xDC00 or cp > 0xDFFF,
        "Cannot convert regular expression capture: unpaired surrogate"
      )
    end
    if cp < 0x80 then
      parts[#parts + 1] = string.char(cp)
    elseif cp < 0x800 then
      parts[#parts + 1] = string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
    elseif cp < 0x10000 then
      parts[#parts + 1] = string.char(
        0xE0 + math.floor(cp / 0x1000),
        0x80 + math.floor(cp / 0x40) % 0x40,
        0x80 + cp % 0x40
      )
    else
      parts[#parts + 1] = string.char(
        0xF0 + math.floor(cp / 0x40000),
        0x80 + math.floor(cp / 0x1000) % 0x40,
        0x80 + math.floor(cp / 0x40) % 0x40,
        0x80 + cp % 0x40
      )
    end
  end
  return table.concat(parts)
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
  local candidates = node.flags.i and equivalents[casefold[cp] or cp] or nil
  for _, cp in ipairs(candidates or { cp }) do
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
  end
  return node.negated and not found or not node.negated and found
end

-- Escape interpretation depends on captures anywhere in the pattern.
local function capture_info(source)
  local index, count, in_class, has_named = 1, 0, false, false
  while index <= #source do
    local cp = source[index]
    if cp == 92 then
      index = index + 2
    else
      if cp == 91 and not in_class then
        in_class = true
      elseif cp == 93 and in_class then
        in_class = false
      elseif cp == 40 and not in_class then
        local named = source[index + 1] == 63
          and source[index + 2] == 60
          and source[index + 3] ~= 61
          and source[index + 3] ~= 33
        has_named = has_named or named
        if source[index + 1] ~= 63 or named then
          count = count + 1
        end
      end
      index = index + 1
    end
  end
  return count, has_named
end

function M.compile(pattern)
  local source, cursor, count, names = units(pattern), 1, 0, {}
  local total_captures, has_named = capture_info(source)
  local flags = { i = false, m = false, s = false }
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
  local function hex4()
    local digits = ""
    for _ = 1, 4 do
      assert(peek():match("^%x$"), "Invalid regular expression: name Unicode escape")
      digits = digits .. peek()
      cursor = cursor + 1
    end
    return tonumber(digits, 16)
  end
  local function name_codepoint()
    local cp
    if take("\\") then
      expect("u")
      if take("{") then
        local digits = ""
        while peek():match("^%x$") do
          digits = digits .. peek()
          cursor = cursor + 1
        end
        expect("}")
        cp = tonumber(digits, 16)
        assert(cp and cp <= 0x10FFFF, "Invalid regular expression: name code point")
        return cp
      end
      cp = hex4()
      -- Only adjacent four-digit escapes form an escaped surrogate pair.
      if cp >= 0xD800 and cp <= 0xDBFF and peek() == "\\" and ascii(source[cursor + 1]) == "u" then
        cursor = cursor + 2
        local trail = hex4()
        assert(trail >= 0xDC00 and trail <= 0xDFFF, "Invalid regular expression: name surrogate")
        return 0x10000 + (cp - 0xD800) * 0x400 + trail - 0xDC00
      end
    else
      cp = assert(source[cursor], "Invalid regular expression: unclosed name")
      cursor = cursor + 1
      local trail = source[cursor]
      if cp >= 0xD800 and cp <= 0xDBFF and trail and trail >= 0xDC00 and trail <= 0xDFFF then
        cursor = cursor + 1
        return 0x10000 + (cp - 0xD800) * 0x400 + trail - 0xDC00
      end
    end
    return cp
  end
  local function capture_name()
    local codepoints = {}
    while source[cursor] do
      local cp = name_codepoint()
      -- V8 (Node and Deno) also accepts an escaped > as the name terminator.
      if cp == 62 then
        assert(#codepoints > 0, "Invalid regular expression: empty capture name")
        -- Numeric keys equate literal and escaped names without normalization.
        return table.concat(codepoints, ",")
      end
      assert(identifier_char(cp, #codepoints == 0), "Invalid regular expression: capture name")
      codepoints[#codepoints + 1] = cp
    end
    error("Invalid regular expression: unclosed name")
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
      if next_char:match("^[A-Za-z]$") or in_class and next_char:match("^[0-9_]$") then
        cursor = cursor + 1
        return literal(string.byte(next_char:upper()) % 32)
      end
      -- Legacy fallback consumes only the backslash; c remains its own atom.
      cursor = cursor - 1
      return literal(92)
    end
    if char == "k" and has_named then
      assert(not in_class, "Invalid regular expression: named reference in class")
      expect("<")
      return { kind = "reference", name = capture_name() }
    end
    if char:match("^[0-9]$") then
      if not in_class and char ~= "0" then
        local digits, after = char, cursor
        while ascii(source[after]):match("^[0-9]$") do
          digits = digits .. ascii(source[after])
          after = after + 1
        end
        local number = tonumber(digits)
        if number <= total_captures then
          cursor = after
          return { kind = "reference", number = number }
        end
      end
      if char:match("^[0-7]$") then
        local digits = char
        local limit = char <= "3" and 3 or 2
        while #digits < limit and peek():match("^[0-7]$") do
          digits = digits .. peek()
          cursor = cursor + 1
        end
        return literal(tonumber(digits, 8))
      end
      -- Non-octal 8/9 are identity escapes; later digits remain separate atoms.
      return literal(cp)
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
      local function append(value)
        if value.kind == "class" then
          vim.list_extend(node.items, value.items)
        else
          node.items[#node.items + 1] = value
        end
      end
      while source[cursor] and peek() ~= "]" do
        local first = item()
        if peek() == "-" and ascii(source[cursor + 1]) ~= "]" and source[cursor + 1] then
          cursor = cursor + 1
          local last = item()
          if first.kind == "literal" and last.kind == "literal" then
            assert(first.value <= last.value, "Invalid regular expression: reversed range")
            append({ kind = "range", first = first.value, last = last.value })
          else
            -- Without Unicode flags, class escapes turn the range into a union.
            append(first)
            append(literal(45))
            append(last)
          end
        else
          append(first)
        end
      end
      expect("]")
      return node
    elseif take("(") then
      local outer_flags = flags
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
            name = capture_name()
          end
        elseif peek():match("^[ims-]$") then
          kind, flags = "group", copy(flags)
          local seen = {}
          local function modifiers(enabled)
            while peek():match("^[ims]$") do
              local flag = peek()
              assert(not seen[flag], "Invalid regular expression: repeated modifier")
              seen[flag], flags[flag] = true, enabled
              cursor = cursor + 1
            end
          end
          modifiers(true)
          if take("-") then
            modifiers(false)
          end
          assert(next(seen), "Invalid regular expression: empty modifiers")
          expect(":")
        else
          error("Invalid regular expression: group prefix")
        end
      end
      if kind == "capture" then
        count = count + 1
        number = count
        if name then
          names[name] = names[name] or {}
          names[name][#names[name] + 1] = number
        end
      end
      local child = disjunction()
      flags = outer_flags
      expect(")")
      return {
        kind = kind,
        child = child,
        number = number,
        name = name,
        positive = positive,
        direction = direction,
      }
    end
    if peek() == "{" then
      local after = cursor + 1
      while ascii(source[after]):match("^[0-9]$") do
        after = after + 1
      end
      if after > cursor + 1 then
        if ascii(source[after]) == "," then
          after = after + 1
          while ascii(source[after]):match("^[0-9]$") do
            after = after + 1
          end
        end
        assert(ascii(source[after]) ~= "}", "Invalid regular expression: quantifier without atom")
      end
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
    node.flags = flags
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
      node.numbers = node.number and { node.number } or names[node.name]
      assert(node.numbers, "Invalid regular expression: unknown backreference")
      for _, number in ipairs(node.numbers) do
        assert(number <= count, "Invalid regular expression: backreference")
      end
    end
    local declared = {}
    if node.kind == "capture" and node.name then
      declared[node.name] = true
    end
    local function include(child)
      for name in pairs(validate(child)) do
        -- Only different alternatives make duplicate declarations exclusive.
        assert(
          node.kind == "alternation" or not declared[name],
          "Invalid regular expression: duplicate capture name"
        )
        declared[name] = true
      end
    end
    if node.child then
      include(node.child)
    end
    for _, child in ipairs(node.children or {}) do
      include(child)
    end
    return declared
  end
  validate(tree)

  local compiled = {
    match = function(_, text)
      local input = units(text)
      local function prepend(node, tasks)
        return { node = node, next = tasks }
      end
      local evaluate
      function evaluate(root, position, captures, direction)
        local tasks, choices = prepend(root), {}
        while true do
          if not tasks then
            return { position = position, captures = captures }
          end
          local node = tasks.node
          tasks = tasks.next
          local kind, failed = node.kind, false
          if kind == "sequence" then
            local first = direction == 1 and #node.children or 1
            local last = direction == 1 and 1 or #node.children
            for index = first, last, -direction do
              tasks = prepend(node.children[index], tasks)
            end
          elseif kind == "alternation" then
            for index = #node.children, 2, -1 do
              choices[#choices + 1] = {
                tasks = prepend(node.children[index], tasks),
                position = position,
                captures = captures,
              }
            end
            tasks = prepend(node.children[1], tasks)
          elseif kind == "group" then
            tasks = prepend(node.child, tasks)
          elseif kind == "capture" then
            tasks = prepend({ kind = "capture_end", number = node.number, start = position }, tasks)
            tasks = prepend(node.child, tasks)
          elseif kind == "capture_end" then
            captures = copy(captures)
            captures[node.number] =
              { math.min(node.start, position), math.max(node.start, position) }
          elseif kind == "look" then
            -- Lookaround is atomic; its local choices must not escape this call.
            local result = evaluate(node.child, position, captures, node.direction)
            failed = (result ~= nil) ~= node.positive
            if not failed and result then
              captures = result.captures
            end
          elseif kind == "repeat" then
            tasks = prepend({ kind = "repeat_step", repeated = node, iteration = 0 }, tasks)
          elseif kind == "repeat_after" then
            failed = position == node.start and node.iteration >= node.repeated.minimum
            if not failed then
              tasks = prepend({
                kind = "repeat_step",
                repeated = node.repeated,
                iteration = node.iteration + 1,
              }, tasks)
            end
          elseif kind == "repeat_step" then
            local repeated = node.repeated
            local can_stop = node.iteration >= repeated.minimum
            local can_continue = node.iteration < repeated.maximum
            local following, cleared
            if can_continue then
              cleared = copy(captures)
              for index = repeated.first_capture, repeated.last_capture do
                cleared[index] = nil
              end
              following = prepend({
                kind = "repeat_after",
                repeated = repeated,
                iteration = node.iteration,
                start = position,
              }, tasks)
              following = prepend(repeated.child, following)
            end
            if repeated.lazy and can_stop then
              if can_continue then
                choices[#choices + 1] =
                  { tasks = following, position = position, captures = cleared }
              end
            elseif can_continue then
              if can_stop then
                choices[#choices + 1] = { tasks = tasks, position = position, captures = captures }
              end
              tasks, captures = following, cleared
            else
              failed = not can_stop
            end
          elseif kind == "start" or kind == "finish" or kind == "boundary" then
            local matched = kind == "start"
                and (position == 1 or node.flags.m and line_terminator(input[position - 1]))
              or kind == "finish"
                and (position == #input + 1 or node.flags.m and line_terminator(input[position]))
            if kind == "boundary" then
              matched = word(input[position - 1]) ~= word(input[position])
              if node.negated then
                matched = not matched
              end
            end
            failed = not matched
          elseif kind == "reference" then
            local capture
            for _, number in ipairs(node.numbers) do
              if captures[number] then
                capture = captures[number]
                break
              end
            end
            local length = capture and capture[2] - capture[1] or 0
            local start = direction == 1 and position or position - length
            for offset = 0, length - 1 do
              if not same_char(input[start + offset], input[capture[1] + offset], node.flags.i) then
                failed = true
                break
              end
            end
            if not failed then
              position = position + length * direction
            end
          else
            local cp = input[direction == 1 and position or position - 1]
            local matched = kind == "literal" and same_char(cp, node.value, node.flags.i)
              or kind == "class" and class_matches(node, cp)
              or kind == "dot" and cp ~= nil and (node.flags.s or not line_terminator(cp))
            failed = not matched
            if matched then
              position = position + direction
            end
          end
          if failed then
            local choice = table.remove(choices)
            if not choice then
              return nil
            end
            tasks, position, captures = choice.tasks, choice.position, choice.captures
          end
        end
      end
      for start = 1, #input + 1 do
        local result = evaluate(tree, start, {}, 1)
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
  function compiled:match_strings(text, indices)
    local captures = self:match(text)
    if not captures then
      return nil
    end
    local result = {}
    for index = 1, indices and #indices or #captures do
      local capture = captures[indices and indices[index] or index]
      result[index] = capture and capture ~= vim.NIL and capture_string(capture) or vim.NIL
    end
    return result
  end
  return compiled
end
return M
