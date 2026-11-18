local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsTabFilter = ns.ContactsTabFilter or require("WhisperMessenger.UI.ContactsList.ContactsTabFilter")
local MenuEntries = ns.ContactsListMenuEntries or require("WhisperMessenger.UI.ContactsList.MenuEntries")
local GuildInviteMenuEntry = ns.ContactsListGuildInviteMenuEntry or require("WhisperMessenger.UI.ContactsList.GuildInviteMenuEntry")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")
local ProtectedMenuEntries = ns.ContactsListProtectedMenuEntries or require("WhisperMessenger.UI.ContactsList.ProtectedMenuEntries")
local SectionEntries = ns.ContactsListSectionEntries or require("WhisperMessenger.UI.ContactsList.SectionEntries")
local LegacyMenu = ns.ContactsListLegacyMenu or require("WhisperMessenger.UI.ContactsList.LegacyMenu")

local ExportMenuEntry = MenuEntries.Export
local NotifyMenuEntries = MenuEntries.Notify
local AddFriendMenuEntry = MenuEntries.AddFriend
local BlockMenuEntry = MenuEntries.Block
local ProfileLinksMenuEntry = MenuEntries.ProfileLinks

local ContextMenu = {}

local registeredModernMenu = nil

-- Menu.ModifyMenu hook on Blizzard's FRIEND / BN_FRIEND player menus. Only
-- acts when the menu was opened from one of our rows (contextData carries
-- our item).
local function addWhisperMessengerEntries(_owner, rootDescription, contextData)
  if rootDescription == nil or type(rootDescription.CreateButton) ~= "function" then
    return
  end
  if type(contextData) ~= "table" or type(contextData.whisperMessengerItem) ~= "table" then
    return
  end
  local item = contextData.whisperMessengerItem
  ProtectedMenuEntries.Fix(rootDescription, item)
  local profileLinks = ProfileLinksMenuEntry.Links(item)
  -- No entries: skip the section rather than show it empty.
  if
    type(contextData.whisperMessengerOnMarkUnread) ~= "function"
    and type(contextData.whisperMessengerOnUpdatePrefs) ~= "function"
    and not SectionEntries.HasRowActions(contextData.whisperMessengerRowActions)
    and #profileLinks == 0
  then
    return
  end
  -- Divider + gold title mark our entries apart from Blizzard's.
  if type(rootDescription.CreateDivider) == "function" then
    rootDescription:CreateDivider()
  end
  if type(rootDescription.CreateTitle) == "function" then
    rootDescription:CreateTitle(SectionEntries.TITLE)
  end
  SectionEntries.AddMarkUnread(rootDescription, item, contextData.whisperMessengerOnMarkUnread)
  ExportMenuEntry.Add(rootDescription, item)
  SectionEntries.AddPrefs(rootDescription, item, contextData.whisperMessengerOnUpdatePrefs, false)
  AddFriendMenuEntry.Add(rootDescription, item)
  GuildInviteMenuEntry.Add(rootDescription, item)
  BlockMenuEntry.Add(rootDescription, item, contextData.whisperMessengerRowActions)
  ProfileLinksMenuEntry.Add(rootDescription, profileLinks)
  SectionEntries.AddRowActions(rootDescription, item, contextData.whisperMessengerRowActions)
end

local function ensureModernMenu()
  local menu = _G.Menu
  if type(menu) ~= "table" or type(menu.ModifyMenu) ~= "function" then
    return false
  end
  if registeredModernMenu == menu then
    return true
  end

  local okFriend = pcall(menu.ModifyMenu, "MENU_UNIT_FRIEND", addWhisperMessengerEntries)
  local okBnet = pcall(menu.ModifyMenu, "MENU_UNIT_BN_FRIEND", addWhisperMessengerEntries)
  if not okFriend or not okBnet then
    return false
  end

  registeredModernMenu = menu
  return true
end

local function resolveMenuName(item)
  local name = item.displayName or item.gameAccountName or item.battleTag
  if name == nil or name == "" then
    return nil
  end

  return name
end

-- Group rows are not players, so they get a small menu of our own instead of
-- Blizzard's player menu. Returns false (row click selects) without the
-- modern menu API.
local function openGroupMenu(item, anchorFrame, onMarkUnread, onUpdatePrefs, rowActions)
  local menuUtil = _G.MenuUtil
  if type(menuUtil) ~= "table" or type(menuUtil.CreateContextMenu) ~= "function" then
    return false
  end
  menuUtil.CreateContextMenu(anchorFrame, function(_owner, rootDescription)
    SectionEntries.AddMarkUnread(rootDescription, item, onMarkUnread)
    ExportMenuEntry.Add(rootDescription, item)
    SectionEntries.AddPrefs(rootDescription, item, onUpdatePrefs, true)
    SectionEntries.AddRowActions(rootDescription, item, rowActions)
  end)
  return true
end

local function openMenu(item, anchorFrame, onMarkUnread, onUpdatePrefs, rowActions)
  if type(item) ~= "table" then
    return false
  end
  if ContactsTabFilter.IsGroupChannel(item.channel) then
    return openGroupMenu(item, anchorFrame, onMarkUnread, onUpdatePrefs, rowActions)
  end

  local name = resolveMenuName(item)
  if name == nil then
    return false
  end

  local lineID = item.lineID
  local chatType = item.chatType
  local which = item.channel == "BN" and "BN_FRIEND" or "FRIEND"

  -- Never pass anchorFrame as the menu's chatFrame: Blizzard's Whisper entry
  -- sends to chatFrame.editBox, which our frames lack, so Whisper errors out.
  -- Without one, Blizzard picks the player's own chat edit box.
  if ensureModernMenu() and type(_G.UnitPopup_OpenMenu) == "function" then
    _G.UnitPopup_OpenMenu(which, {
      name = name,
      lineID = lineID,
      chatType = chatType,
      chatTarget = name,
      bnetAccountID = item.bnetAccountID,
      bnetIDAccount = item.bnetAccountID,
      guid = item.guid,
      battleTag = item.battleTag,
      communityClubID = item.communityClubID,
      communityStreamID = item.communityStreamID,
      communityEpoch = item.communityEpoch,
      communityPosition = item.communityPosition,
      whisperMessengerItem = item,
      whisperMessengerOnMarkUnread = onMarkUnread,
      whisperMessengerOnUpdatePrefs = onUpdatePrefs,
      whisperMessengerRowActions = rowActions,
    })
    return true
  end

  -- 3.3.5a builds its player menu from UnitPopup_ShowMenu and cannot be
  -- extended afterwards, so the section is armed just before the menu opens.
  LegacyMenu.Arm({
    item = item,
    onMarkUnread = onMarkUnread,
    onUpdatePrefs = onUpdatePrefs,
    rowActions = rowActions,
  })

  if item.channel == "BN" then
    if type(_G.FriendsFrame_ShowBNDropdown) == "function" then
      _G.FriendsFrame_ShowBNDropdown(
        name,
        1,
        lineID,
        chatType,
        nil,
        nil,
        item.bnetAccountID,
        item.communityClubID,
        item.communityStreamID,
        item.communityEpoch,
        item.communityPosition,
        item.battleTag
      )
      return true
    end
    LegacyMenu.Disarm()
  elseif type(_G.FriendsFrame_ShowDropdown) == "function" then
    _G.FriendsFrame_ShowDropdown(
      name,
      1,
      lineID,
      chatType,
      nil,
      nil,
      item.communityClubID,
      item.communityStreamID,
      item.communityEpoch,
      item.communityPosition,
      item.guid
    )
    return true
  end

  LegacyMenu.Disarm()

  if type(_G.UnitPopup_OpenMenu) == "function" then
    _G.UnitPopup_OpenMenu(which, {
      name = name,
      lineID = lineID,
      chatType = chatType,
      chatTarget = name,
      bnetIDAccount = item.bnetAccountID,
      guid = item.guid,
      battleTag = item.battleTag,
      communityClubID = item.communityClubID,
      communityStreamID = item.communityStreamID,
      communityEpoch = item.communityEpoch,
      communityPosition = item.communityPosition,
    })
    return true
  end

  return false
end

-- onUpdatePrefs(item, changes): changes is { muted = bool } / { nickname =
-- text } / { note = text } / { notifyOnline = bool } / { notifyZone = bool }.
-- rowActions: { onPin(item), onRemove(item) } (the row's hover actions).
-- An opened menu takes ESC before the window.
function ContextMenu.Open(item, anchorFrame, onMarkUnread, onUpdatePrefs, rowActions)
  local opened = openMenu(item, anchorFrame, onMarkUnread, onUpdatePrefs, rowActions)
  if opened then
    PickerPopup.ReportMenuShown()
  end
  return opened
end

ns.ContactsListContextMenu = ContextMenu
return ContextMenu
