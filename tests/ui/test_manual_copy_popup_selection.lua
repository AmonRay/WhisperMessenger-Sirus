-- The copy popup primes the game's StaticPopup edit box so Ctrl+C copies the
-- text right away: the box must hold the text, take focus and only then select
-- it. Selecting before SetFocus (or before the font change) drops the
-- selection, leaving the text neither highlighted nor copyable.
local FakeUI = require("tests.helpers.fake_ui")
local FontBox = require("tests.helpers.font_box")
local Resolvers = require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.Resolvers")
local StyledTextInputPopup = require("WhisperMessenger.UI.Shared.StyledTextInputPopup")

local function recordCalls(box)
  local calls = {}
  local function wrap(name)
    local original = box[name]
    box[name] = function(self, ...)
      calls[#calls + 1] = name
      if original then
        return original(self, ...)
      end
    end
  end
  for _, name in ipairs({ "SetText", "SetFocus", "HighlightText", "SetFont", "SetFontObject" }) do
    wrap(name)
  end
  return calls
end

local function indexOf(calls, name)
  for index, call in ipairs(calls) do
    if call == name then
      return index
    end
  end
  return nil
end

local function makePopup(factory)
  local popup = factory.CreateFrame("Frame", nil, nil)
  popup:SetWidth(420)
  popup.editBox = FontBox.Give(factory.CreateFrame("EditBox", nil, popup), FontBox.FRIZ, 14, "")
  popup.text = factory.CreateFrame("FontString", nil, popup)
  return popup
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_box_takes_focus_before_selecting_the_text
  do
    local popup = makePopup(factory)
    local calls = recordCalls(popup.editBox)
    Resolvers.primePopupEditBox(popup, "|cffffd200katerstiki-item-57-97760|r", "WM_TEST")
    local focusAt = indexOf(calls, "SetFocus")
    local highlightAt = indexOf(calls, "HighlightText")
    assert(focusAt ~= nil, "the box takes focus, calls: " .. table.concat(calls, ","))
    assert(highlightAt ~= nil, "the box selects its text, calls: " .. table.concat(calls, ","))
    assert(focusAt < highlightAt, "focus comes before the selection, calls: " .. table.concat(calls, ","))
  end

  -- test_selection_survives_the_font_change
  do
    StyledTextInputPopup.nativeChrome = false
    local popup = makePopup(factory)
    local calls = recordCalls(popup.editBox)
    StyledTextInputPopup.Apply(popup, "WM_TEST", "text with ő and ű", StyledTextInputPopup.INPUT_STYLE)
    assert(calls[#calls] == "HighlightText", "the selection is the last thing done, calls: " .. table.concat(calls, ","))
    local fontAt = indexOf(calls, "SetFont")
    local highlightAt = indexOf(calls, "HighlightText")
    if fontAt ~= nil then
      assert(fontAt < highlightAt, "the font change comes before the selection, calls: " .. table.concat(calls, ","))
    end
  end
end
