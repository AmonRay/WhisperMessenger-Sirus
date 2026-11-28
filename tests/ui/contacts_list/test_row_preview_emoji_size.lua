-- Personal emoji in the contact list preview must read as an emoji. The
-- preview line passes its own font size, so the icon scales with the text
-- instead of sitting at the small default badge size.
local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  local function makeRow()
    local row = factory.CreateFrame("Frame", nil, parent)
    row.classIconFrame = factory.CreateFrame("Frame", nil, row)
    return row
  end

  -- test_preview_emoji_scales_with_the_preview_font
  do
    local row = makeRow()
    local item = {
      displayName = "Рэинбоу",
      lastPreview = "лови :clown:",
      conversation = {
        messages = { { direction = "in", playerName = "Рэинбоу-Сирус", text = "лови :clown:" } },
      },
    }

    RowElements.createPreview(row, item, 260)

    local text = row.preview:GetText() or ""
    assert(text:find("emoji_clown", 1, true), "the preview must show the clown picture, got " .. text)

    local size = tonumber(text:match(":(%d+):%d+|t"))
    local _, fontSize = row.preview:GetFont()
    assert(size ~= nil, "the preview emoji must carry a size, got " .. text)
    assert(
      size >= fontSize * 2 - 1,
      "the preview emoji must be about twice the preview text, got " .. tostring(size) .. " for font " .. tostring(fontSize)
    )
  end

  -- test_draft_preview_emoji_scales_with_the_preview_font
  do
    local savedUnitName = _G.UnitName
    _G.UnitName = function(unit)
      return unit == "player" and "Рэинбоу" or nil
    end

    local row = makeRow()
    local item = {
      displayName = "Рэинбоу",
      lastPreview = "привет",
      draft = "лови :poop:",
      conversationKey = "me::WOW::rainbow",
    }

    RowElements.createPreview(row, item, 260)
    RowElements.updatePreview(row, item, 260, false, nil)
    _G.UnitName = savedUnitName

    local text = row.preview:GetText() or ""
    assert(text:find("emoji_poop", 1, true), "the draft preview must show the poop picture, got " .. text)

    local size = tonumber(text:match(":(%d+):%d+|t"))
    local _, fontSize = row.preview:GetFont()
    assert(size ~= nil, "the draft emoji must carry a size, got " .. text)
    assert(size >= fontSize * 2 - 1, "the draft emoji must be about twice the preview text, got " .. tostring(size))
  end
end
