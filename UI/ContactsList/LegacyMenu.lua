local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SectionEntries = ns.ContactsListSectionEntries or require("WhisperMessenger.UI.ContactsList.SectionEntries")

-- 3.3.5a has no Menu/MenuUtil: the player menu is Blizzard's UIDropDownMenu,
-- filled by UnitPopup_ShowMenu while the frame initialises, and its click
-- handler only knows its own buttons. Adding our entries right after
-- UnitPopup_ShowMenu runs puts the WhisperMessenger section under Blizzard's
-- own entries, the way the newer clients do it (see ContextMenu).
local LegacyMenu = {}

local PLAYER_MENUS = { FRIEND = true, BN_FRIEND = true, FRIEND_OFFLINE = true, BN_FRIEND_OFFLINE = true }

-- The row the pending menu was opened from; one menu is built at a time.
local pending = nil
local hookedFunction = nil

-- Collects entries through the same description interface the newer clients
-- hand to the section builder.
local function newDescription()
  local entries = {}
  local description = { entries = entries }

  function description:CreateButton(text, onClick)
    local entry = { text = text, onClick = onClick, enabled = true }
    entries[#entries + 1] = entry
    return {
      SetEnabled = function(_, enabled)
        entry.enabled = enabled ~= false
      end,
    }
  end

  function description:CreateCheckbox(text, isChecked, onToggle)
    entries[#entries + 1] = { text = text, isChecked = isChecked, onToggle = onToggle }
  end

  function description:CreateTitle(text)
    entries[#entries + 1] = { text = text, isTitle = true }
  end

  -- The dropdown draws no separators of its own; the gold title is enough.
  function description:CreateDivider() end

  return description
end

-- The row's description is built before the menu is shown, so a checkbox has
-- to remember its own ticked state: the dropdown stays open on click and the
-- row snapshot never changes.
local function addEntry(entry)
  local info = _G.UIDropDownMenu_CreateInfo()
  info.text = entry.text
  info.notCheckable = true
  if entry.isTitle then
    info.isTitle = true
  elseif entry.onToggle ~= nil then
    local checked = type(entry.isChecked) == "function" and entry.isChecked() == true
    info.notCheckable = nil
    info.isNotRadio = true
    info.keepShownOnClick = true
    info.checked = checked
    info.func = function()
      checked = not checked
      entry.onToggle(checked)
    end
  elseif type(entry.onClick) == "function" then
    info.func = entry.onClick
    if entry.enabled == false then
      info.disabled = true
    end
  end
  _G.UIDropDownMenu_AddButton(info, 1)
end

local function appendSection(dropdownMenu, which)
  local context = pending
  pending = nil
  if context == nil or type(dropdownMenu) ~= "table" then
    return
  end
  -- UnitPopup_ShowMenu takes the menu kind as its second argument; the field
  -- is only filled on some clients.
  if not PLAYER_MENUS[which or dropdownMenu.which] then
    return
  end
  if type(_G.UIDropDownMenu_CreateInfo) ~= "function" or type(_G.UIDropDownMenu_AddButton) ~= "function" then
    return
  end

  local description = newDescription()
  SectionEntries.AddTitled(description, context, false)
  for _, entry in ipairs(description.entries) do
    addEntry(entry)
  end
end

-- Call right before opening Blizzard's player menu; returns false when the
-- client has nothing to append to, so the caller keeps its plain menu.
function LegacyMenu.Arm(context)
  if type(context) ~= "table" or not SectionEntries.HasEntries(context) then
    return false
  end
  local showMenu = _G.UnitPopup_ShowMenu
  if type(showMenu) ~= "function" or type(_G.hooksecurefunc) ~= "function" then
    return false
  end
  if hookedFunction ~= showMenu then
    local ok = pcall(_G.hooksecurefunc, "UnitPopup_ShowMenu", appendSection)
    if not ok then
      return false
    end
    hookedFunction = showMenu
  end
  pending = context
  return true
end

-- A menu that closed without building ours must not leak into the next one.
function LegacyMenu.Disarm()
  pending = nil
end

function LegacyMenu.HasPending()
  return pending ~= nil
end

ns.ContactsListLegacyMenu = LegacyMenu
return LegacyMenu
