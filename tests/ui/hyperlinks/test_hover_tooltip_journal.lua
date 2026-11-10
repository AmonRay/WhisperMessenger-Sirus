-- journal: links (Sirus quest/encounter journal) have no GameTooltip
-- support: the client shows nothing useful, so the fallback printed the raw
-- "journal:1:1569:2" link text as a tooltip. Hovering shows nothing for them;
-- clicking still routes through SetItemRef.
local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")

local function newTooltipStub()
  local calls = { setOwner = 0, setHyperlink = nil, setText = nil, show = 0 }
  local tooltip = {
    SetOwner = function()
      calls.setOwner = calls.setOwner + 1
    end,
    SetHyperlink = function(_, link)
      calls.setHyperlink = link
    end,
    SetText = function(_, t)
      calls.setText = t
    end,
    Show = function()
      calls.show = calls.show + 1
    end,
    Hide = function() end,
  }
  return tooltip, calls
end

local function assertNoTooltip(link, label)
  local savedTooltip = _G.GameTooltip
  local tooltip, calls = newTooltipStub()
  _G.GameTooltip = tooltip

  Hyperlinks.HandleEnter({}, link)

  _G.GameTooltip = savedTooltip
  assert(calls.setOwner == 0, "SetOwner must not be called for " .. label)
  assert(calls.setHyperlink == nil, "SetHyperlink must not be called for " .. label)
  assert(calls.setText == nil, "SetText must not be called for " .. label)
  assert(calls.show == 0, "Show must not be called for " .. label)
end

return function()
  -- test_bare_journal_link_shows_no_tooltip
  assertNoTooltip("journal:1:1569:2", "a journal link")

  -- test_wrapped_journal_link_shows_no_tooltip
  assertNoTooltip("|Hjournal:1:1569:2|h[Leotheras the Blind]|h", "a |H-wrapped journal link")

  -- test_journal_link_type_is_case_insensitive
  assertNoTooltip("JOURNAL:1:1569:2", "an uppercase JOURNAL link")
end
