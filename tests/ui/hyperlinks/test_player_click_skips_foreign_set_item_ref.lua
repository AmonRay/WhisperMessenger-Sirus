-- Other addons replace the global SetItemRef: DBM-Core wraps it for its own
-- links, and Leatrix Plus (with "Alt click invite" on) turns an alt+click on a
-- player name into InviteUnit, a protected call that is blocked in combat. Our
-- own frames must never reach those wrappers: a player click goes to Blizzard's
-- chat handler, and with no handler at all it does nothing.
local FakeUI = require("tests.helpers.fake_ui")
local LinkClicks = require("WhisperMessenger.UI.Hyperlinks.LinkClicks")

local PLAYER_LINK = "player:Thrall:12"
local ITEM_LINK = "item:6948:0:0:0:0:0:0"

local function clickLink(link, text)
  local frame = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
  frame:EnableMouse(true)
  LinkClicks.BindClick(frame)
  frame:GetScript("OnHyperlinkClick")(frame, link, text, "LeftButton")
end

local function playerText(link)
  return "|H" .. link .. "|h[Thrall]|h"
end

-- Installs a SetItemRef that behaves like Leatrix's alt-click wrapper and a
-- Blizzard chat handler recorder; returns both recorders and a restore.
local function withStubs(options, fn)
  local saved = {
    SetItemRef = _G.SetItemRef,
    ChatFrameMixin = _G.ChatFrameMixin,
    ChatFrame_OnHyperlinkShow = _G.ChatFrame_OnHyperlinkShow,
    IsAltKeyDown = _G.IsAltKeyDown,
  }
  local calls = { setItemRef = {}, invite = {}, handler = {} }

  rawset(_G, "IsAltKeyDown", function()
    return true
  end)
  rawset(_G, "SetItemRef", function(link)
    table.insert(calls.setItemRef, link)
    if string.match(link, "^player") then
      table.insert(calls.invite, link)
    end
  end)
  rawset(_G, "ChatFrameMixin", nil)
  rawset(_G, "ChatFrame_OnHyperlinkShow", nil)
  if options.handler == true then
    rawset(_G, "ChatFrame_OnHyperlinkShow", function(_self, link, text)
      table.insert(calls.handler, { link = link, text = text })
    end)
  end

  local ok, err = pcall(fn, calls)
  for key, value in pairs(saved) do
    rawset(_G, key, value)
  end
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_player_click_never_reaches_a_foreign_set_item_ref
  withStubs({ handler = true }, function(calls)
    clickLink(PLAYER_LINK, playerText(PLAYER_LINK))

    assert(#calls.invite == 0, "alt+click on a player name must never run InviteUnit, got " .. #calls.invite)
    assert(#calls.setItemRef == 0, "a player click must not go through SetItemRef, got " .. tostring(calls.setItemRef[1]))
    assert(#calls.handler == 1, "Blizzard's chat handler takes the click, ran " .. #calls.handler)
    assert(calls.handler[1].link == PLAYER_LINK, "Blizzard's handler gets the decoded link, got " .. tostring(calls.handler[1].link))
  end)

  -- test_player_click_does_nothing_without_a_blizzard_handler
  withStubs({ handler = false }, function(calls)
    clickLink(PLAYER_LINK, playerText(PLAYER_LINK))

    assert(#calls.invite == 0, "no InviteUnit without a Blizzard handler either, got " .. #calls.invite)
    assert(#calls.setItemRef == 0, "a player click stays out of SetItemRef, got " .. tostring(calls.setItemRef[1]))
  end)

  -- test_item_click_still_falls_back_to_set_item_ref
  withStubs({ handler = false }, function(calls)
    clickLink(ITEM_LINK, "|H" .. ITEM_LINK .. "|h[Hearthstone]|h")

    assert(#calls.setItemRef == 1, "an item click still needs SetItemRef, got " .. #calls.setItemRef)
    assert(#calls.invite == 0, "an item click is not a player click")
  end)
end
