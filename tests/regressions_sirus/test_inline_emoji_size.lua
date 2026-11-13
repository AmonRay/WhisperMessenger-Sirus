local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

-- Reads both inline forms: the per-key texture (|Tpath:w:h|t, the one a
-- 3.3.5a client can draw) and the atlas subrect (w:h:0:0:...:x1:x2:y1:y2).
local function inlineIcons(display)
  local icons = {}
  for path, width, height in string.gmatch(display, "|T([^:|]+):(%d+):(%d+)") do
    icons[#icons + 1] = { path = path, width = tonumber(width), height = tonumber(height) }
  end
  return icons
end

return function()
  local savedSize = Fonts.GetFontSize()
  local ok, err = pcall(function()
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(600, 420)
    -- No exact pixel size is mandated: require at least text-sized icons,
    -- scaling with text, and readable default-size art (larger than 12px).
    local previousSize
    for _, size in ipairs({ 9, 12, 17 }) do
      Fonts.SetFontSize(size)
      local message = {
        kind = "user",
        direction = "in",
        channel = "WOW",
        playerName = "Thrall",
        text = "Hello :heart: world\n:thumbsup:",
      }
      local bubble = BubbleFrame.CreateBubble(factory, parent, message, { paneWidth = 600, showIcon = false })
      local display = bubble.frame._textFS:GetText()
      local icons = inlineIcons(display)
      assert(#icons == 2, "both inline emoji tokens must render inside the actual chat bubble")
      local iconSize
      for _, icon in ipairs(icons) do
        assert(icon.width == icon.height, "inline emoji must be square")
        assert(icon.height >= size, "inline emoji must not be smaller than the message text")
        assert(icon.height >= math.floor(size * 1.8), "inline emoji must read as an emoji, twice the font size, got " .. icon.height)
        assert(icon.path:find("Media\\emoji\\", 1, true), "3.3.5a needs a per-key texture, got " .. icon.path)
        if size == 12 then
          assert(icon.height > 12, "default inline emoji must be enlarged beyond the old 12px presentation")
        end
        iconSize = icon.height
      end
      if previousSize then
        assert(iconSize > previousSize, "inline emoji must grow when the message font grows")
      end
      previousSize = iconSize
      assert(display:find("\n", 1, true), "emoji replacement must retain explicit line breaks")
      assert(message.text == "Hello :heart: world\n:thumbsup:", "display formatting must not change saved/wire text")
      assert(bubble.height > 0, "emoji-bearing message must reserve bubble height")
    end

    -- test_inline_emoji_formatting_preserves_existing_hyperlink_markup
    local link = "|Hplayer:Thrall|h[Thrall]|h"
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      direction = "in",
      playerName = "Thrall",
      channel = "WOW",
      text = link .. " :heart:",
    }, { paneWidth = 600, showIcon = false })
    local linked = bubble.frame._textFS:GetText()
    assert(linked:find(link, 1, true), "emoji display formatting must preserve player hyperlinks")
    assert(#inlineIcons(linked) == 1, "the emoji after a hyperlink must still render")
  end)
  Fonts.SetFontSize(savedSize)
  assert(ok, err)
end
