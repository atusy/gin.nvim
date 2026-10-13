local T = MiniTest.new_set()
T["emoji conversion preserves compound sequences and unknown names"] = function()
  local emojify = require("gin.emoji").emojify
  MiniTest.expect.equality(emojify(":woman_technologist: :us:"), "👩💻 🇺🇸")
  MiniTest.expect.equality(
    emojify(":not_known: :octocat: :SMILE:"),
    ":not_known: :octocat: :SMILE:"
  )
  MiniTest.expect.equality(emojify(":octocat:rocket:"), ":octocat:rocket:")
  MiniTest.expect.equality(emojify(":unknown:rocket::+1:"), ":unknown🚀👍")
  MiniTest.expect.equality(emojify("no names : : unfinished"), "no names : : unfinished")
end
return T
