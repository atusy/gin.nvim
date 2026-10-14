local T = MiniTest.new_set()
T["Latin-1 labels use TextDecoder's Windows-1252 mapping"] = function()
  MiniTest.expect.equality(require("gin.encoding").decode(string.char(128, 233), "latin1"), "€é")
end

local oracle =
  vim.json.decode(table.concat(vim.fn.readfile("tests/audit/encoding-oracle.json", "b"), "\n"))
for _, record in ipairs(oracle.records) do
  T[record.encoding .. " matches the fatal TextDecoder oracle"] = function()
    for _, case in ipairs(record.cases) do
      local ok, actual =
        pcall(require("gin.encoding").decode, string.char(unpack(case.bytes)), record.encoding)
      MiniTest.expect.equality(ok, not case.error)
      if ok then
        MiniTest.expect.equality(actual, case.text)
      end
    end
  end
  T[record.encoding .. " accepts its aliases with ASCII whitespace and case"] = function()
    for _, alias in ipairs(record.aliases) do
      MiniTest.expect.equality(
        require("gin.encoding").decode("", " \t\n" .. alias:upper() .. "\r\f"),
        ""
      )
    end
  end
end

T["detection skips invalid candidates and preserves the selected label"] = function()
  MiniTest.expect.equality(
    { require("gin.encoding").detect("caf\233", { "made-up", "utf-8", "LATIN1", "windows-1251" }) },
    { "café", "LATIN1", false }
  )
end
T["detection selects the first successful candidate"] = function()
  MiniTest.expect.equality(
    { require("gin.encoding").detect("\128", { "windows-1251", "latin1" }) },
    { "Ђ", "windows-1251", false }
  )
end
T["failed detection replaces invalid UTF-8 and retains whitespace and ANSI"] = function()
  MiniTest.expect.equality(
    { require("gin.encoding").detect(" \27[31m\255\n", { "utf-8", "made-up" }) },
    { " \27[31m�\n", "", false }
  )
end
T["empty candidate lists use UTF-8 fallback and report the removed BOM"] = function()
  MiniTest.expect.equality(
    { require("gin.encoding").detect("\239\187\191a", {}) },
    { "a", "", true }
  )
end
T["UTF-16 BOM is stripped only in the selected byte order"] = function()
  MiniTest.expect.equality(
    { require("gin.encoding").decode("\254\255\0A", "utf-16be") },
    { "A", true }
  )
  MiniTest.expect.equality(
    { require("gin.encoding").decode("\255\254", "utf-16be") },
    { "￾", false }
  )
end
return T
