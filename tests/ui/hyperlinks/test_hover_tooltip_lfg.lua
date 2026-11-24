-- Links from another addon's group finder (for example the Sirus dungeon
-- listing "[Tomb of Maan (9)]") have no Blizzard tooltip. Hovering one used
-- to show its raw wire text — "lfglist:4420:1326" — which reads as broken.
-- Such links must show nothing; clicking still works.
local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")

local function newTooltipStub()
  local calls = { setOwner = 0, setHyperlink = nil, setText = nil, shown = 0 }
  local tooltip = {
    SetOwner = function()
      calls.setOwner = calls.setOwner + 1
    end,
    SetHyperlink = function(_, link)
      calls.setHyperlink = link
      error("the client cannot render this link")
    end,
    SetText = function(_, text)
      calls.setText = text
    end,
    Show = function()
      calls.shown = calls.shown + 1
    end,
    Hide = function() end,
  }
  return tooltip, calls
end

local function withTooltip(fn, tooltip)
  local saved = _G.GameTooltip
  _G.GameTooltip = tooltip
  local ok, err = pcall(fn)
  _G.GameTooltip = saved
  assert(ok, err)
end

return function()
  -- test_bare_lfglist_link_shows_no_tooltip
  do
    local tooltip, calls = newTooltipStub()
    withTooltip(function()
      Hyperlinks.HandleEnter({}, "lfglist:4420:1326")
    end, tooltip)
    assert(calls.setOwner == 0, "the tooltip must not even be anchored for an lfglist link")
    assert(calls.setHyperlink == nil, "SetHyperlink must not run for an lfglist link")
    assert(calls.setText == nil, "the raw lfglist text must not be shown")
    assert(calls.shown == 0, "no tooltip is shown")
  end

  -- test_wrapped_lfglist_link_shows_no_tooltip
  do
    local tooltip, calls = newTooltipStub()
    withTooltip(function()
      Hyperlinks.HandleEnter({}, "|Hlfglist:4420:1326|h[Гробница маны (9)]|h")
    end, tooltip)
    assert(calls.setOwner == 0, "a wrapped lfglist link must not be anchored either")
    assert(calls.setText == nil, "the raw wrapped link must not be shown")
    assert(calls.shown == 0, "no tooltip is shown for a wrapped lfglist link")
  end

  -- test_link_type_match_is_case_insensitive
  do
    local tooltip, calls = newTooltipStub()
    withTooltip(function()
      Hyperlinks.HandleEnter({}, "LFGLIST:4420:1326")
    end, tooltip)
    assert(calls.setOwner == 0, "uppercase LFGLIST must be skipped too")
  end

  -- test_unrenderable_link_shows_no_raw_fallback
  do
    local tooltip, calls = newTooltipStub()
    withTooltip(function()
      Hyperlinks.HandleEnter({}, "customgroupfinder:4420:1326")
    end, tooltip)
    assert(calls.setText == nil, "a link the client cannot render shows no raw text")
    assert(calls.shown == 0, "a link the client cannot render shows no tooltip")
  end

  -- test_regular_item_link_still_gets_its_tooltip
  do
    local calls = { setHyperlink = nil, shown = 0 }
    local tooltip = {
      SetOwner = function() end,
      SetHyperlink = function(_, link)
        calls.setHyperlink = link
      end,
      SetText = function() end,
      Show = function()
        calls.shown = calls.shown + 1
      end,
      Hide = function() end,
    }
    withTooltip(function()
      Hyperlinks.HandleEnter({}, "item:6948")
    end, tooltip)
    assert(calls.setHyperlink == "item:6948", "item links keep their native tooltip")
    assert(calls.shown == 1, "the item tooltip is shown")
  end
end
