local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local HeaderElements = require("WhisperMessenger.UI.ConversationPane.HeaderElements")
local BubbleIcon = require("WhisperMessenger.UI.ChatBubble.BubbleIcon")
local RowView = require("WhisperMessenger.UI.ContactsList.RowView")

return function()
  -- test_new_contact_uses_the_neutral_avatar_not_the_bnet_bubble
  do
    assert(Theme.TEXTURES.unknown_avatar ~= Theme.TEXTURES.bnet_icon, "unknown avatar must not reuse the Battle.net icon")

    local factory = FakeUI.NewFactory()
    local pane = factory.CreateFrame("Frame", nil, nil)
    pane:SetSize(600, 420)

    local headerFrame = HeaderElements.createHeaderFrame(factory, pane, 56)
    local headerIcon = HeaderElements.createClassIcon(factory, headerFrame, { displayName = "Григориец" })
    assert(
      headerIcon.texture.texturePath == Theme.TEXTURES.unknown_avatar,
      "new contact header should show the neutral avatar, got: " .. tostring(headerIcon.texture.texturePath)
    )

    local bubbleFrame = factory.CreateFrame("Frame", nil, pane)
    local bubbleIcon = BubbleIcon.CreateIcon(factory, pane, bubbleFrame, { direction = "in" }, "in", {})
    assert(
      bubbleIcon.texture.texturePath == Theme.TEXTURES.unknown_avatar,
      "incoming bubble without a class should show the neutral avatar, got: " .. tostring(bubbleIcon.texture.texturePath)
    )

    assert(
      RowView.IconPath({ displayName = "Григориец" }) == Theme.TEXTURES.unknown_avatar,
      "contact row without a class should show the neutral avatar"
    )
  end

  -- test_fallback_resets_the_class_icon_crop
  do
    -- The header texture is reused between conversations. A class icon sets
    -- its own atlas crop, so the neutral avatar must clear it or it renders
    -- as a cut-off corner of the silhouette.
    local factory = FakeUI.NewFactory()
    local pane = factory.CreateFrame("Frame", nil, nil)
    local texture = pane:CreateTexture(nil, "ARTWORK")
    texture:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    assert(Theme.ApplyFallbackIcon(texture) == true, "fallback should be applied to a texture")
    assert(texture.texturePath == Theme.TEXTURES.unknown_avatar, "fallback should set the neutral avatar")
    local coords = texture.texCoords
    assert(
      coords[1] == 0 and coords[2] == 1 and coords[3] == 0 and coords[4] == 1,
      "fallback should reset the texture coordinates, got a leftover crop"
    )
  end
end
