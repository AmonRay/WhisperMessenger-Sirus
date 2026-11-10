local FakeUI = require("tests.helpers.fake_ui")
local LinkOverlay = require("WhisperMessenger.UI.ChatBubble.LinkOverlay")
local BubbleStructure = require("WhisperMessenger.UI.ChatBubble.BubbleStructure")

-- A 3.3.5a-like frame: no SetHyperlinksEnabled, so its FontString links
-- never fire OnHyperlink* scripts.
local function legacyFrame(factory)
  local frame = factory.CreateFrame("Frame", nil, nil)
  frame.SetHyperlinksEnabled = nil
  return frame
end

local LINK = "|cffffffff|Hitem:6948:0:0:0|h[Камень возвращения]|h|r"

return function()
  local factory = FakeUI.NewFactory()

  -- Bubbles on a legacy client get a SimpleHTML twin that takes link clicks.
  do
    local frame = legacyFrame(factory)
    BubbleStructure.createStructure(frame, factory)
    local html = frame._linkHTML
    assert(html ~= nil, "expected a link twin on a 3.3.5a frame")
    assert(html.frameType == "SimpleHTML", "expected the twin to be SimpleHTML, got " .. tostring(html.frameType))
    assert(type(html.scripts.OnHyperlinkClick) == "function", "twin should handle link clicks")
    assert(type(html.scripts.OnHyperlinkEnter) == "function", "twin should show link tooltips")
    assert(html:IsShown() == false, "twin starts hidden")
  end

  -- Modern frames keep firing link scripts themselves: no twin. (Skipped when
  -- the suite runs as 3.3.5a, where every frame gets one.)
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
    if FlavorCompat.isWrath335 ~= true then
      BubbleStructure.createStructure(frame, factory)
      assert(frame._linkHTML == nil, "no twin when the frame fires link scripts")
    end
  end

  -- Text with a link: twin shows the text over the (hidden) FontString.
  do
    local frame = legacyFrame(factory)
    local _, _, textFS = BubbleStructure.createStructure(frame, factory)
    textFS:SetTextColor(0.5, 0.6, 0.7, 1)
    textFS:SetWidth(200)
    textFS:SetText("wts " .. LINK)
    assert(LinkOverlay.Sync(frame, textFS, "wts " .. LINK) == true, "expected the twin to render")
    local html = frame._linkHTML
    assert(html.text == "wts " .. LINK, "twin should carry the same text")
    assert(html:IsShown() == true, "twin should show for linked text")
    assert(textFS.alpha == 0, "FontString should be hidden under the twin")
    assert(html.width == 200, "twin should match the text width")
    assert(html.textColor[1] == 0.5 and html.textColor[3] == 0.7, "twin should match the text color")

    -- Reused for plain text: twin hides, FontString shows again.
    textFS:SetText("hello")
    assert(LinkOverlay.Sync(frame, textFS, "hello") == false, "plain text needs no twin")
    assert(html:IsShown() == false, "twin should hide for plain text")
    assert(textFS.alpha == 1, "FontString should be visible again")
  end

  -- Bubble mouse scripts still fire over the text.
  do
    local frame = legacyFrame(factory)
    BubbleStructure.createStructure(frame, factory)
    local got = nil
    frame:SetScript("OnMouseUp", function(self, button)
      got = { self = self, button = button }
    end)
    frame._linkHTML.scripts.OnMouseUp(frame._linkHTML, "RightButton")
    assert(got ~= nil and got.self == frame and got.button == "RightButton", "twin should forward OnMouseUp to the bubble")
  end

  -- Clicking a link in the twin reaches SetItemRef.
  do
    local savedMixin = rawget(_G, "ChatFrameMixin")
    local savedRef = rawget(_G, "SetItemRef")
    rawset(_G, "ChatFrameMixin", nil)
    local clicked = nil
    rawset(_G, "SetItemRef", function(link)
      clicked = link
    end)
    local frame = legacyFrame(factory)
    BubbleStructure.createStructure(frame, factory)
    local ok, err = pcall(frame._linkHTML.scripts.OnHyperlinkClick, frame._linkHTML, "item:6948:0:0:0", LINK, "LeftButton")
    rawset(_G, "ChatFrameMixin", savedMixin)
    rawset(_G, "SetItemRef", savedRef)
    assert(ok, tostring(err))
    assert(clicked == "item:6948:0:0:0", "expected the link click to reach SetItemRef, got " .. tostring(clicked))
  end

  print("PASS: test_bubble_link_overlay")
end
