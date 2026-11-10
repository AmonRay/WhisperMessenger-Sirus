-- Personal emojis: :clown: belongs to the Rainbow characters only. It shows
-- in their picker and renders as an icon only in messages they sent.
local RestrictedEmojis = require("WhisperMessenger.Model.RestrictedEmojis")
local ReactionAssets = require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")

local function withPlayer(name, fn)
  local saved = _G.UnitName
  _G.UnitName = function(unit)
    if unit == "player" then
      return name
    end
    return nil
  end
  local ok, err = pcall(fn)
  _G.UnitName = saved
  if not ok then
    error(err, 0)
  end
end

return function()
  -- ownership
  assert(RestrictedEmojis.IsRestricted("clown"), "clown should be restricted")
  assert(not RestrictedEmojis.IsRestricted("smile"), "regular emojis are not restricted")
  for _, owner in ipairs({ "Рэйнбоу", "Реинбоу", "Рэинбоу", "Рейнбоу" }) do
    assert(RestrictedEmojis.CanUse("clown", owner), "owner allowed: " .. owner)
    assert(RestrictedEmojis.CanUse("clown", owner .. "-Сирус"), "realm suffix ignored: " .. owner)
  end
  assert(not RestrictedEmojis.CanUse("clown", "Артас"), "other players are not allowed")
  assert(not RestrictedEmojis.CanUse("clown", nil), "unknown sender is not allowed")
  assert(not RestrictedEmojis.CanUse("clown", ""), "empty sender is not allowed")

  -- picker list
  local keys = RestrictedEmojis.KeysFor("Рейнбоу")
  assert(#keys == 1 and keys[1] == "clown", "owner gets the clown in the picker")
  assert(#RestrictedEmojis.KeysFor("Артас") == 0, "others get nothing extra")

  -- sender resolution
  withPlayer("Рэйнбоу", function()
    assert(
      RestrictedEmojis.SenderOf({ direction = "out", playerName = "Артас-Сирус" }) == "Рэйнбоу",
      "outgoing sender is the local player"
    )
  end)
  assert(
    RestrictedEmojis.SenderOf({ direction = "in", playerName = "Реинбоу-Сирус" }) == "Реинбоу",
    "incoming sender is playerName"
  )
  assert(RestrictedEmojis.SenderOf(nil) == nil, "nil message has no sender")

  -- rendering
  local texture = RestrictedEmojis.GetTexture("clown")
  assert(type(texture) == "string" and texture:find("emoji_clown", 1, true), "clown texture path")
  local allowed = ReactionAssets.FormatTextForDisplay("hi :clown:", "Рэинбоу")
  assert(allowed:find("emoji_clown", 1, true), "clown renders for an owner: " .. allowed)
  assert(not allowed:find(":clown:", 1, true), "token replaced for an owner")
  assert(ReactionAssets.FormatTextForDisplay("hi :clown:", "Артас") == "hi :clown:", "stays literal for others")
  assert(ReactionAssets.FormatTextForDisplay("hi :clown:") == "hi :clown:", "stays literal without a sender")

  local viaLinks = Hyperlinks.FormatTextForDisplay(":clown: |cff0070dd|Hitem:1|h[X]|h|r :clown:", "Рейнбоу")
  local _, count = viaLinks:gsub("emoji_clown", "")
  assert(count == 2, "both tokens around a link render for an owner: " .. viaLinks)
  assert(Hyperlinks.FormatTextForDisplay(":clown:", "Артас") == ":clown:", "Hyperlinks keeps it literal for others")
  -- the sender must not leak into the next call
  assert(Hyperlinks.FormatTextForDisplay(":clown:") == ":clown:", "no sender carry-over between calls")
end
