local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatLinkSources = ns.ComposerChatLinkSources or require("WhisperMessenger.UI.Composer.ChatLinkSources")
local QuestLinkClassic = ns.UIHyperlinksQuestLinkClassic or require("WhisperMessenger.UI.Hyperlinks.QuestLinkClassic")
local UrlFormatter = ns.UIHyperlinksUrlFormatter or require("WhisperMessenger.UI.Hyperlinks.UrlFormatter")

local LinkHooks = {}
local registeredLinkHooks = false
local linkedInputs = {}
-- The window's own composer. Other boxes (the reply preview row) register
-- after it, so "the newest input" is not the one the player is looking at.
local primaryInputs = {}
local lastInsertFrameTime = nil
-- The 3.3.5a UI patches do not always answer EditBox:HasFocus for a custom
-- box, so the input's own focus events are tracked alongside it.
local focusedInputs = setmetatable({}, { __mode = "k" })
-- Blizzard keeps its own chat box active while the player clicks a bag or a
-- quest, so the shift-click still lands there after the click moved the
-- keyboard focus. Remember the composer the player was typing in for the same
-- reason: without it a shift-click from anywhere in the world finds no focused
-- box and the link is silently dropped.
local activeInput = nil

-- The messenger window frame. The composer sits under panes the layout hides
-- and reshows (the options page hides the conversation panes, a compact layout
-- hides others), so the window is the only frame that says whether a composer
-- is on screen. Asking the composer's own ancestors answered false for a
-- composer the player could see and type in, which dropped every bag
-- shift-click as "no composer".
local hostFrame = nil

function LinkHooks.SetHostFrame(frame)
  hostFrame = frame
end

local function hostShown()
  if hostFrame == nil or type(hostFrame.IsShown) ~= "function" then
    return true
  end
  return hostFrame:IsShown() == true
end

local function isInputFocused(input)
  if focusedInputs[input] == true then
    return true
  end
  if type(input.HasFocus) ~= "function" then
    return false
  end
  return input:HasFocus() == true
end

local function canInsert(input)
  return input ~= nil and type(input.Insert) == "function"
end

local function focusedInput()
  for _, input in ipairs(linkedInputs) do
    if canInsert(input) and isInputFocused(input) then
      return input
    end
  end
  return nil
end

local function preferredInput()
  -- The composer the player is typing in wins, as in the game's own chat: the
  -- client's IsShown and IsVisible answers for it are unreliable, and a
  -- shift-clicked link has to land where the player is typing.
  local focused = focusedInput()
  if focused ~= nil then
    return focused
  end
  -- Without focus the window has to be up, or the link would go into a chat
  -- the player cannot see.
  if not hostShown() then
    return nil
  end
  if canInsert(activeInput) then
    return activeInput
  end
  return nil
end

local function findInputForInsertion(allowVisibleWithoutFocus)
  local input = preferredInput()
  if input ~= nil or not allowVisibleWithoutFocus then
    return input
  end

  -- Nothing is focused: the window composer is where a click inside the
  -- window belongs. Falling back to the newest input sent the name into the
  -- reply preview's box, which the player could not see (seen in game).
  for _, candidate in ipairs(primaryInputs) do
    if canInsert(candidate) then
      return candidate
    end
  end

  for _, candidate in ipairs(linkedInputs) do
    if canInsert(candidate) then
      return candidate
    end
  end

  return nil
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
  -- API callers (keepText) send finished text: no rewrite, so the byte cap
  -- they were checked against still holds.
  local insertable = link
  if type(insertable) == "string" and options.keepText ~= true then
    insertable = QuestLinkClassic.Rewrite(insertable)
  end

  -- ponytail: one insert per frame. A single shift-click fans out into several
  -- Blizzard insert paths (player-link handler, SetItemRef modified-click
  -- fallback, our SetItemRef post-hook). Only the first — the plain
  -- whisperable name — should land. GetTime() is constant within a frame.
  local now = type(_G.GetTime) == "function" and _G.GetTime() or nil
  if now ~= nil and now == lastInsertFrameTime then
    return true -- already inserted this frame; report handled so callers don't fall back
  end
  lastInsertFrameTime = now

  local before = type(input.GetText) == "function" and input:GetText() or nil
  local function endsWith(text, tail)
    return tail ~= "" and type(text) == "string" and string.sub(text, -#tail) == tail
  end
  -- The game's own insert runs on the same box once the composer answers as
  -- the active chat window (see activeWindowReplacement), so a second copy
  -- would land twice. Classic sends plain "[Name (id)]" quest text, which the
  -- rewrite above turned into a hyperlink: replace it rather than add to it.
  if endsWith(before, insertable) then
    return true
  end
  if link ~= insertable and endsWith(before, link) and type(input.SetText) == "function" then
    input:SetText(string.sub(before, 1, #before - #link) .. insertable)
    return true
  end
  input:Insert(insertable)
  -- A client whose EditBox:Insert leaves the text alone (seen on 3.3.5a with a
  -- focused custom box) would silently swallow the shift-click.
  if before ~= nil and input:GetText() == before then
    local combined = before .. insertable
    if type(input.SetText) == "function" then
      input:SetText(combined)
      if type(input.SetCursorPosition) == "function" then
        pcall(input.SetCursorPosition, input, #combined)
      end
    end
  end
  return true
end

-- Every chat-link handler in the game, Blizzard's own and Sirus' custom
-- windows alike, asks this before it hands a link to ChatEdit_InsertLink
-- ("if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then").
-- Post-hooks cannot reach a button that stored its handler before we hooked
-- it, which is why the quest log, the achievement list, the adventure guide
-- and the battle pass never got through. The focused composer answers as the
-- active chat window, as the WIM messenger does, and only while Blizzard has
-- no box of its own open; everyone else gets Blizzard's own answer.
local nativeGetActiveWindow = nil
local function activeWindowReplacement()
  local blizzardBox = type(nativeGetActiveWindow) == "function" and nativeGetActiveWindow() or nil
  if blizzardBox ~= nil then
    return blizzardBox
  end
  if _G._wmSuspended then
    return nil
  end
  return focusedInput()
end

local function safeHookGlobal(functionName, handler)
  local ok = pcall(_G.hooksecurefunc, functionName, handler)
  return ok
end

local function safeHookMethod(target, methodName, handler)
  if type(target) ~= "table" then
    return false
  end
  local ok = pcall(_G.hooksecurefunc, target, methodName, handler)
  return ok
end

-- Never assign to a Blizzard global or a ChatFrameUtil field, not even to put
-- Blizzard's own function back: any write from addon code taints that slot for
-- the whole session. Blizzard's later reads of it (opening chat, inserting a
-- link, pressing Enter) then run tainted, and in an encounter the game blocks
-- the player's own chat message and blames this addon. Post-hooks through
-- hooksecurefunc keep Blizzard's function in place and its callers untainted.
--
-- Shift-click inserts end in InsertLink. The post-hook adds the link to our
-- composer only while it has focus and no Blizzard chat box is open (an open
-- one already got the link from Blizzard). A click can reach more than one
-- hook; the one-insert-per-frame dedupe in tryInsertLink keeps a single copy.
local function isOurInput(frame)
  for _, input in ipairs(linkedInputs) do
    if frame == input then
      return true
    end
  end
  return false
end

-- Blizzard's own answer only: the composer answers as the active window too,
-- and that must not read as "the game's chat box already took the link".
local function blizzardChatBoxActive()
  local util = _G.ChatFrameUtil
  local getActiveWindow = type(util) == "table" and util.GetActiveWindow or nil
  if type(getActiveWindow) ~= "function" then
    getActiveWindow = nativeGetActiveWindow or _G.ChatEdit_GetActiveWindow
  end
  if type(getActiveWindow) ~= "function" then
    return false
  end
  local active = getActiveWindow()
  return active ~= nil and not isOurInput(active)
end

local function insertFromBlizzard(link)
  if _G._wmSuspended then
    return
  end
  if type(link) ~= "string" or link == "" then
    return
  end
  if blizzardChatBoxActive() then
    return
  end
  tryInsertLink(link, { allowVisibleWithoutFocus = false })
end

local function playerNameFromLink(link)
  if type(link) ~= "string" then
    return nil
  end
  return string.match(link, "^player%a*:([^:]+)")
end

local function isBattleNetPlayerLink(link)
  return type(link) == "string" and string.find(link, "BNplayer", 1, true) == 1
end

local function isPlayerLink(link)
  return type(link) == "string" and string.find(link, "player", 1, true) == 1
end

-- A player name shift-clicked in our own window: inserts the plain name into
-- the focused composer and returns true, so the caller can keep the click
-- away from Blizzard's SetItemRef (with no Blizzard chat box open it sends a
-- /who for the name). Returns false when the composer did not take it.
-- A plain character name (never a |Hplayer link: the server refuses those in
-- a sent message). Callers decide when a click inserts one.
-- fromWindow: the click came from inside our own window, which proves a
-- composer is on screen; 3.3.5a answers IsShown unreliably for the window, so
-- that gate is skipped rather than dropping the click.
function LinkHooks.InsertPlayerName(name, fromWindow)
  if type(name) ~= "string" or name == "" or _G._wmSuspended then
    return false
  end
  return tryInsertLink(name, { allowVisibleWithoutFocus = fromWindow == true }) == true
end

function LinkHooks.InsertClickedPlayerName(link)
  if not ChatLinkSources.IsChatLinkClick() then
    return false
  end
  return LinkHooks.InsertPlayerName(playerNameFromLink(link))
end

local function wouldPassByteCap(input, current, text)
  if type(input.GetMaxBytes) ~= "function" then
    return false
  end
  local maxBytes = input:GetMaxBytes()
  if type(maxBytes) ~= "number" or maxBytes <= 0 then
    return false
  end
  return #current + #text > maxBytes - 1
end

-- Public insert for other addons: puts text into the composer the player is
-- typing in (shown and focused). Returns true only when the input's text really
-- changed, so a deduped, capped or refused insert reports false.
function LinkHooks.InsertText(text)
  if _G._wmSuspended then
    return false
  end
  local input = findInputForInsertion(false)
  if input == nil or type(input.GetText) ~= "function" then
    return false
  end
  local current = input:GetText() or ""
  if wouldPassByteCap(input, current, text) then
    return false
  end
  tryInsertLink(text, { allowVisibleWithoutFocus = false, keepText = true })
  return input:GetText() ~= current
end

local function registerLinkHooks()
  if registeredLinkHooks or type(_G.hooksecurefunc) ~= "function" then
    return
  end

  -- SetItemRef: handles clicking hyperlinks inside chat bubbles / transcript.
  safeHookGlobal("SetItemRef", function(link, text)
    if _G._wmSuspended then
      return
    end
    -- Our URL links only copy their address; they are never inserted.
    if link == nil or UrlFormatter.ExtractExternalUrlFromLink(link) ~= nil then
      return
    end
    -- A shift-clicked player name inserts the plain name, as Blizzard does
    -- for its own open chat box (Blizzard also sends a /who when none is
    -- open). This hook only sees clicks outside our window, or in it while
    -- the composer had no focus: with focus, our window's click script puts
    -- the name in through InsertClickedPlayerName and never calls SetItemRef.
    -- Blizzard ignores shift-clicked Battle.net names so the encoded account
    -- name never reaches chat; so do we. Any other click on a player name
    -- (right-click menu, plain click) inserts nothing: the server refuses a
    -- sent |Hplayer link ("Invalid escape code in chat message").
    local playerName = playerNameFromLink(link)
    if isBattleNetPlayerLink(link) or isPlayerLink(link) then
      if playerName ~= nil and ChatLinkSources.IsChatLinkClick() then
        insertFromBlizzard(playerName, "SetItemRef")
      end
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

  -- Gated click handlers only reach ChatEdit_InsertLink while one of
  -- Blizzard's own chat boxes is open, so a focused composer never sees a bag
  -- or bank shift-click through them. Their post-hooks hand us the link
  -- directly; the per-frame dedupe keeps a click that reaches both to one
  -- insert.
  local function insertFromChatLinkClick(link)
    if not ChatLinkSources.IsChatLinkClick() then
      return
    end
    insertFromBlizzard(link)
  end

  local function installGlobal(name, handler)
    safeHookGlobal(name, handler)
  end

  safeHookMethod(_G.ChatFrameUtil, "InsertLink", insertFromBlizzard)
  installGlobal("ChatEdit_InsertLink", function(link)
    insertFromBlizzard(link)
  end)
  installGlobal("ChatEdit_TryInsertChatLink", function(link)
    return insertFromChatLinkClick(link)
  end)
  installGlobal("HandleModifiedItemClick", function(link)
    return insertFromChatLinkClick(link)
  end)
  ChatLinkSources.Register(insertFromBlizzard)

  -- The one Blizzard slot the addon replaces; see activeWindowReplacement.
  if type(_G.ChatEdit_GetActiveWindow) == "function" and nativeGetActiveWindow == nil then
    nativeGetActiveWindow = _G.ChatEdit_GetActiveWindow
    _G.ChatEdit_GetActiveWindow = activeWindowReplacement
  end

  registeredLinkHooks = true
end

function LinkHooks.RegisterInput(input, isPrimary)
  table.insert(linkedInputs, 1, input)
  if isPrimary == true then
    table.insert(primaryInputs, 1, input)
  end
  if type(input.HookScript) == "function" then
    input:HookScript("OnEditFocusGained", function(self)
      focusedInputs[self] = true
      activeInput = self
    end)
    input:HookScript("OnEditFocusLost", function(self)
      focusedInputs[self] = nil
    end)
    input:HookScript("OnHide", function(self)
      focusedInputs[self] = nil
      if activeInput == self then
        activeInput = nil
      end
    end)
  end
  registerLinkHooks()
end

ns.ComposerLinkHooks = LinkHooks
return LinkHooks
