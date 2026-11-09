local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local QuestLinkClassic = ns.UIHyperlinksQuestLinkClassic or require("WhisperMessenger.UI.Hyperlinks.QuestLinkClassic")
local UrlFormatter = ns.UIHyperlinksUrlFormatter or require("WhisperMessenger.UI.Hyperlinks.UrlFormatter")

local LinkHooks = {}
local registeredLinkHooks = false
local linkedInputs = {}
local lastInsertFrameTime = nil

local function isInputShown(input)
  if type(input.IsVisible) == "function" then
    return input:IsVisible() == true
  end
  if type(input.IsShown) ~= "function" then
    return true
  end
  return input:IsShown() == true
end

local function isInputFocused(input)
  if type(input.HasFocus) ~= "function" then
    return false
  end
  return input:HasFocus() == true
end

local function findInputForInsertion(allowVisibleWithoutFocus)
  local fallbackVisibleInput = nil

  for _, input in ipairs(linkedInputs) do
    if input ~= nil and type(input.Insert) == "function" and isInputShown(input) then
      if isInputFocused(input) then
        return input
      end
      if allowVisibleWithoutFocus and fallbackVisibleInput == nil then
        fallbackVisibleInput = input
      end
    end
  end

  return fallbackVisibleInput
end

local function tryInsertLink(link, options)
  if link == nil then
    return false
  end

  options = options or {}
  local input = findInputForInsertion(options.allowVisibleWithoutFocus == true)
  if input == nil then
    return false
  end

  -- Classic vanilla shift-click of a quest produces plain `[Name (id)]` text
  -- with no |H...|h envelope. Rewrite to a real hyperlink so the link is
  -- clickable in the composer and survives transmission to the recipient.
  local insertable = link
  if type(insertable) == "string" then
    insertable = QuestLinkClassic.Rewrite(insertable)
  end

  -- ponytail: one insert per frame. A single shift-click fans out into several
  -- Blizzard insert paths (ChatEdit_InsertLink, SetItemRef modified-click
  -- fallback, our SetItemRef post-hook). Only the first should land.
  -- GetTime() is constant within a frame.
  local now = type(_G.GetTime) == "function" and _G.GetTime() or nil
  if now ~= nil and now == lastInsertFrameTime then
    return true -- already inserted this frame; report handled so callers don't fall back
  end
  lastInsertFrameTime = now

  input:Insert(insertable)
  return true
end

local function safeHookGlobal(functionName, handler)
  if type(_G[functionName]) ~= "function" then
    return false
  end
  local ok = pcall(_G.hooksecurefunc, functionName, handler)
  return ok
end

-- True when a Blizzard chat editbox currently owns the keyboard: the link
-- already went there, we must not duplicate it into the composer.
local function blizzardEditBoxFocused()
  local getActive = _G.ChatEdit_GetActiveWindow
  if type(getActive) ~= "function" then
    return false
  end
  local ok, editBox = pcall(getActive)
  return ok and editBox ~= nil and type(editBox.HasFocus) == "function" and editBox:HasFocus() == true
end

-- Shift-click of an item/spell/quest/achievement ends in ChatEdit_InsertLink.
-- Earlier versions REPLACED _G.ChatEdit_InsertLink / ChatEdit_GetActiveWindow
-- while the composer had focus and assigned the originals back on focus loss.
-- Any assignment from addon code leaves the global tainted for the rest of the
-- session, so every secure caller (spellbook modified click, bag items,
-- OPENCHAT) ran tainted afterwards. Now we only post-hook: Blizzard runs its
-- own untouched function, then we insert into our focused composer.
local function onChatEditInsertLink(link)
  if _G._wmSuspended or type(link) ~= "string" or link == "" then
    return
  end
  if blizzardEditBoxFocused() then
    return
  end
  tryInsertLink(link, { allowVisibleWithoutFocus = false })
end

local function registerLinkHooks()
  if registeredLinkHooks or type(_G.hooksecurefunc) ~= "function" then
    return
  end

  safeHookGlobal("ChatEdit_InsertLink", onChatEditInsertLink)

  -- SetItemRef: handles clicking hyperlinks inside chat bubbles / transcript.
  safeHookGlobal("SetItemRef", function(link, text)
    if _G._wmSuspended then
      return
    end
    -- Our URL links only copy their address; they are never inserted.
    if link == nil or UrlFormatter.ExtractExternalUrlFromLink(link) ~= nil then
      return
    end

    local linkToInsert = link
    if type(text) == "string" and text ~= "" and string.find(text, "|H", 1, true) then
      linkToInsert = text
    elseif type(link) == "string" and string.find(link, "quest:", 1, true) and type(text) == "string" and text ~= "" then
      linkToInsert = "|H" .. link .. "|h" .. text .. "|h"
    end

    -- Only insert into the messenger composer when it currently has focus.
    -- Otherwise clicking a chat-bubble link (or anything routed through
    -- SetItemRef) would silently dump the link into our editbox even when
    -- the user expected the default behavior (open quest log, show tooltip).
    tryInsertLink(linkToInsert, { allowVisibleWithoutFocus = false })
  end)

  registeredLinkHooks = true
end

function LinkHooks.RegisterInput(input)
  -- Fields some Blizzard helpers expect on a chat-like editbox. They live on
  -- our own EditBox only, so they never taint Blizzard state.
  if input.chatType == nil then
    input.chatType = "SAY"
  end
  if type(input.GetChatType) ~= "function" then
    input.GetChatType = function(self)
      return self.chatType or "SAY"
    end
  end
  table.insert(linkedInputs, 1, input)
  registerLinkHooks()
end

-- Exposed for tests.
LinkHooks._TryInsertLink = tryInsertLink
LinkHooks._OnChatEditInsertLink = onChatEditInsertLink

ns.ComposerLinkHooks = LinkHooks
return LinkHooks
