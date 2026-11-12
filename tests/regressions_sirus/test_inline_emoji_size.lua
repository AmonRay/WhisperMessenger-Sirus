local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

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
      local count = 0
      local iconSize
      for height, width in display:gmatch("|T.-:(%d+):(%d+):") do
        height, width = tonumber(height), tonumber(width)
        count = count + 1
        assert(height == width and height >= size, "inline emoji must be square and no smaller than message text")
        if size == 12 then
          assert(height > 12, "default inline emoji must be enlarged beyond the old 12px presentation")
        end
        iconSize = height
      end
      assert(count == 2, "both inline emoji tokens must render inside the actual chat bubble")
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
    assert(bubble.frame._textFS:GetText():find(link, 1, true), "emoji display formatting must preserve player hyperlinks")
  end)
  Fonts.SetFontSize(savedSize)
  assert(ok, err)
end
