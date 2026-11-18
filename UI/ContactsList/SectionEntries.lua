local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local ContactPrefsDialog = ns.ContactsListContactPrefsDialog or require("WhisperMessenger.UI.ContactsList.ContactPrefsDialog")
local MenuEntries = ns.ContactsListMenuEntries or require("WhisperMessenger.UI.ContactsList.MenuEntries")
local GuildInviteMenuEntry = ns.ContactsListGuildInviteMenuEntry or require("WhisperMessenger.UI.ContactsList.GuildInviteMenuEntry")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- The WhisperMessenger part of a contact's right-click menu. Written against
-- the menu-description interface (CreateButton / CreateCheckbox / CreateTitle)
-- so the same entries appear on clients that build the menu themselves and in
-- the 3.3.5a dropdown (see LegacyMenu).
local SectionEntries = {}

SectionEntries.TITLE = UIHelpers.colorEscape(Theme.TAG_GOLD) .. "Whisper Messenger|r"

local function hasUnansweredIncoming(item)
  if type(item.conversation) == "table" then
    return Store.CountUnansweredIncoming(item.conversation) > 0
  end
  return (tonumber(item.unansweredCount) or 0) > 0
end

function SectionEntries.AddMarkUnread(description, item, onMarkUnread)
  if type(onMarkUnread) ~= "function" then
    return
  end
  local button = description:CreateButton(Localization.Text("Mark last messages as unread"), function()
    onMarkUnread(item)
  end)
  if button and type(button.SetEnabled) == "function" then
    button:SetEnabled(hasUnansweredIncoming(item))
  end
end

-- Mute/Unmute for every row; nickname, note and the notify entries for
-- whispers only.
function SectionEntries.AddPrefs(description, item, onUpdatePrefs, isGroup)
  if type(onUpdatePrefs) ~= "function" then
    return
  end
  local muted = item.muted == true
  description:CreateButton(Localization.Text(muted and "Unmute" or "Mute"), function()
    onUpdatePrefs(item, { muted = not muted })
  end)
  if isGroup then
    return
  end
  description:CreateButton(Localization.Text("Set nickname…"), function()
    ContactPrefsDialog.ShowNickname(item, function(text)
      onUpdatePrefs(item, { nickname = text })
    end)
  end)
  description:CreateButton(Localization.Text("Edit note…"), function()
    ContactPrefsDialog.ShowNote(item, function(text)
      onUpdatePrefs(item, { note = text })
    end)
  end)
  MenuEntries.Notify.Add(description, item, onUpdatePrefs)
end

-- Pin/Unpin and Remove: the row's hover-button actions, through the same
-- handlers, so they are reachable in the collapsed rail too (no hover
-- buttons there). rowActions: { onPin(item), onRemove(item) }.
function SectionEntries.AddRowActions(description, item, rowActions)
  if type(rowActions) ~= "table" then
    return
  end
  if type(rowActions.onPin) == "function" then
    description:CreateButton(Localization.Text(item.pinned and "Unpin" or "Pin to top"), function()
      rowActions.onPin(item)
    end)
  end
  if type(rowActions.onRemove) == "function" then
    description:CreateButton(Localization.Text("Remove"), function()
      rowActions.onRemove(item)
    end)
  end
end

function SectionEntries.HasRowActions(rowActions)
  return type(rowActions) == "table"
    and (type(rowActions.onPin) == "function" or type(rowActions.onRemove) == "function" or type(rowActions.onIgnorePlayer) == "function")
end

function SectionEntries.HasEntries(contextData)
  local item = contextData and contextData.item
  return type(item) == "table"
    and (
      type(contextData.onMarkUnread) == "function"
      or type(contextData.onUpdatePrefs) == "function"
      or SectionEntries.HasRowActions(contextData.rowActions)
    )
end

-- Divider, gold title, then the entries: the section the player sees on the
-- clients that build the menu themselves.
function SectionEntries.AddTitled(description, contextData, isGroup)
  if type(description.CreateDivider) == "function" then
    description:CreateDivider()
  end
  if type(description.CreateTitle) == "function" then
    description:CreateTitle(SectionEntries.TITLE)
  end
  SectionEntries.AddMarkUnread(description, contextData.item, contextData.onMarkUnread)
  MenuEntries.Export.Add(description, contextData.item)
  SectionEntries.AddPrefs(description, contextData.item, contextData.onUpdatePrefs, isGroup)
  if not isGroup then
    MenuEntries.AddFriend.Add(description, contextData.item)
    GuildInviteMenuEntry.Add(description, contextData.item)
    MenuEntries.Block.Add(description, contextData.item, contextData.rowActions)
    MenuEntries.ProfileLinks.Add(description, MenuEntries.ProfileLinks.Links(contextData.item))
    SectionEntries.AddRowActions(description, contextData.item, contextData.rowActions)
  end
end

ns.ContactsListSectionEntries = SectionEntries
return SectionEntries
