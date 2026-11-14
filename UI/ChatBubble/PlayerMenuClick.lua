local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- Right-click or shift + left-click on a sender label or avatar hands the
-- click to an opener. Without one, right-click opens the player menu.
local PlayerMenuClick = {}

local function defaultOpenPlayerMenu(message, anchor, button)
  if button ~= nil and button ~= "RightButton" then
    return false
  end
  local PM = ns.ChatBubblePlayerMenu
  if type(PM) ~= "table" or type(PM.Open) ~= "function" then
    return false
  end
  return PM.Open(message, anchor)
end

local function isShiftLeftClick(button)
  return button == "LeftButton" and UIHelpers.isShiftDown()
end

-- Shift + left-click puts the sender's name into the focused composer, as a
-- shift-clicked name does in the game's own chat: every incoming line, whisper
-- or channel. When the composer cannot take it (window closed) the click falls
-- through to the opener, so a group line still sends its /who. The player menu
-- stays on right-click.
local function insertSenderName(message)
  local linkHooks = ns.ComposerLinkHooks
  if type(linkHooks) ~= "table" or type(linkHooks.InsertPlayerName) ~= "function" then
    return false
  end
  if type(message) ~= "table" or message.direction ~= "in" or message.channel == "BN" then
    return false
  end
  -- Channel and group lines may carry the sender only as a display name; a
  -- whisper always has playerName.
  local name = message.playerName or message.senderDisplayName
  if type(name) ~= "string" or name == "" or string.find(name, "|K", 1, true) then
    return false
  end
  return linkHooks.InsertPlayerName(name, true) == true
end

-- Shift + left-click on the message itself inserts the same name: the whole
-- line is the target the player aims at, not only the name above it.
function PlayerMenuClick.InsertOnShiftClick(message)
  if not UIHelpers.isShiftDown() then
    return false
  end
  return insertSenderName(message)
end

local function onMouseUp(self, button)
  if button ~= "RightButton" and not isShiftLeftClick(button) then
    return
  end
  if isShiftLeftClick(button) and insertSenderName(self._wmPlayerMenuMessage) then
    return
  end
  local opener = self._wmPlayerMenuOpener
  if type(opener) == "function" then
    opener(self._wmPlayerMenuMessage, self, button)
  end
end

function PlayerMenuClick.Attach(frame, message, opener)
  if type(frame.EnableMouse) ~= "function" or type(frame.SetScript) ~= "function" then
    return
  end
  frame._wmPlayerMenuMessage = message
  frame._wmPlayerMenuOpener = opener or defaultOpenPlayerMenu
  frame:EnableMouse(true)
  frame:SetScript("OnMouseUp", onMouseUp)
end

ns.ChatBubblePlayerMenuClick = PlayerMenuClick

return PlayerMenuClick
