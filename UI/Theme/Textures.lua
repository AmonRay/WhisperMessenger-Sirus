local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")

local Textures = {
  class_icon_prefix = "Interface\\ICONS\\ClassIcon_",
  faction_alliance = "Interface\\ICONS\\PVPCurrency-Honor-Alliance",
  faction_horde = "Interface\\ICONS\\PVPCurrency-Honor-Horde",
  bnet_icon = "Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon",
  -- Neutral portrait for a contact whose class is not known yet (a fresh
  -- whisper from a player who is offline, for example). The Battle.net
  -- toast icon this replaces is a chat bubble meant for Battle.net invites,
  -- and at avatar size it reads as a blurry blue blob.
  unknown_avatar = "Interface\\AddOns\\WhisperMessenger\\Media\\avatar_unknown.tga",
  addon_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\icon.tga",
  -- Relationship marks. Guild prefers RelationshipAtlas; this shield, tinted
  -- green via RelationshipTint, is its fallback on clients without the atlas.
  relationship_guild = "Interface\\ICONS\\INV_Shield_06",
  relationship_bnet = "Interface\\FriendsFrame\\Battlenet-Portrait",
  relationship_friend = "Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon",
  relationship_community = "Interface\\ICONS\\Achievement_GuildPerk_EverybodysFriend",
  -- Pin glyphs (bundled, white on transparent; tinted at runtime).
  pin_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\pin.tga",
  unpin_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\unpin.tga",
  pinned_marker = "Interface\\AddOns\\WhisperMessenger\\Media\\pinned.tga",
  trash_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\remove.tga",
  -- Title-bar line icons (white on transparent; tinted at runtime).
  title_close_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\close.tga",
  title_settings_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\settings.tga",
  title_back_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\back.tga",
  title_new_whisper_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\new_whisper.tga",
  title_whats_new_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\whats_new.tga",
  title_mark_read_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\mark_read.tga",
  quick_reply_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\quick_reply.tga",
  muted_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\muted.tga",
  -- Settings-nav page icons (white on transparent; tinted like the label).
  nav_general_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\nav_general.tga",
  nav_appearance_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\nav_appearance.tga",
  nav_behavior_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\nav_behavior.tga",
  nav_whispers_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\nav_whispers.tga",
  nav_chats_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\nav_chats.tga",
  nav_filters_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\nav_filters.tga",
  nav_notifications_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\nav_notifications.tga",
  nav_icons_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\nav_icons.tga",
}

-- Class tokens with a matching ClassIcon_* texture. Unknown tags must
-- return nil so callers fall back to the BNet icon instead of silently
-- pointing SetTexture at a nonexistent path (renders as an empty circle).
local KNOWN_CLASS_TAGS = {
  WARRIOR = true,
  PALADIN = true,
  HUNTER = true,
  ROGUE = true,
  PRIEST = true,
  DEATHKNIGHT = true,
  SHAMAN = true,
  MAGE = true,
  WARLOCK = true,
  MONK = true,
  DRUID = true,
  DEMONHUNTER = true,
  EVOKER = true,
}

-- The shared Wrath class sheet has a 1-2 px cell edge (a border line) around
-- every class portrait. Cropped edge to edge it showed as a strip down the
-- left side of each icon; pull the crop in by a few percent of the cell.
local WRATH_CLASS_ICON_INSET = 0.03

local WRATH_CLASS_ICON_SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

local CLASS_ID_TAGS = {
  [1] = "WARRIOR",
  [2] = "PALADIN",
  [3] = "HUNTER",
  [4] = "ROGUE",
  [5] = "PRIEST",
  [6] = "DEATHKNIGHT",
  [7] = "SHAMAN",
  [8] = "MAGE",
  [9] = "WARLOCK",
  [11] = "DRUID",
}

local function localizedClassTag(value)
  local raw = string.upper(value)
  local compact = string.gsub(raw, "[%s%-]", "")
  for _, names in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE, _G.LOCALIZED_CLASS_NAMES_FEMALE }) do
    if type(names) == "table" then
      for tag, localized in pairs(names) do
        if type(localized) == "string" then
          local localizedRaw = string.upper(localized)
          if localizedRaw == raw or string.gsub(localizedRaw, "[%s%-]", "") == compact then
            return tag
          end
        end
      end
    end
  end
  return nil
end

local function NormalizeClassTag(value)
  if type(value) == "number" then
    return CLASS_ID_TAGS[value]
  end
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local tag = string.upper((string.gsub(value, "[%s%-]", "")))
  if KNOWN_CLASS_TAGS[tag] then
    return tag
  end
  -- A Russian client names the class "Друид" or "Рыцарь смерти".
  return localizedClassTag(value)
end

local function ClassIcon(classTag)
  local tag = NormalizeClassTag(classTag)
  if tag == nil then
    return nil
  end
  if FlavorCompat.isWrath335 then
    return nil
  end
  return Textures.class_icon_prefix .. tag
end

--- Paint the neutral avatar. Also resets the texture coordinates: the
-- previous contact's class icon may have left a crop on the same texture,
-- which made the fallback look cut off when switching conversations.
local function ApplyFallbackIcon(texture)
  if texture == nil or type(texture.SetTexture) ~= "function" then
    return false
  end
  texture:SetTexture(Textures.unknown_avatar)
  if type(texture.SetTexCoord) == "function" then
    texture:SetTexCoord(0, 1, 0, 1)
  end
  return true
end

local function ApplyClassIcon(texture, classTag)
  local tag = NormalizeClassTag(classTag)
  if texture == nil or tag == nil then
    return false
  end
  -- The client exposing class coordinates is enough, even when its build info
  -- does not identify it as Wrath: there the per-class files are absent and
  -- only the shared sheet exists.
  local coords = _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[tag]
  if coords and type(texture.SetTexture) == "function" then
    texture:SetTexture(WRATH_CLASS_ICON_SHEET)
    if type(texture.SetTexCoord) == "function" then
      local padX = (coords[2] - coords[1]) * WRATH_CLASS_ICON_INSET
      local padY = (coords[4] - coords[3]) * WRATH_CLASS_ICON_INSET
      texture:SetTexCoord(coords[1] + padX, coords[2] - padX, coords[3] + padY, coords[4] - padY)
    end
    return true
  end
  local path = ClassIcon(tag)
  if path == nil or type(texture.SetTexture) ~= "function" then
    return false
  end
  texture:SetTexture(path)
  if type(texture.SetTexCoord) == "function" then
    texture:SetTexCoord(0, 1, 0, 1)
  end
  return true
end

--- Map factionName to atlas icon path
local function FactionIcon(factionName)
  if factionName == "Alliance" then
    return Textures.faction_alliance
  elseif factionName == "Horde" then
    return Textures.faction_horde
  end
  return nil
end

--- Map ChannelType constant to a representative icon texture.
-- Returns nil for whisper-type channels (the class icon is used instead).
local CHANNEL_ICONS = {
  -- These icons are from achievement / Cata talent art (3.0+ and 4.0+
  -- respectively). Classic Era 1.15 and TBC Classic 2.5 may not bundle them,
  -- in which case the missing-texture placeholder shows. Swap to vanilla-safe
  -- paths (e.g. GROUPFRAME / TargetingFrame / Calendar) if that happens.
  PARTY = "Interface\\ICONS\\Achievement_BG_winAB_5Cap",
  INSTANCE_CHAT = "Interface\\ICONS\\Achievement_Arena_2v2_7",
  RAID = "Interface\\ICONS\\Ability_Hunter_HunterVsWild",
  GUILD = "Interface\\ICONS\\Achievement_PVP_G_09",
  OFFICER = "Interface\\ICONS\\Achievement_PVP_O_06",
  BN_CONVERSATION = "Interface\\ICONS\\Achievement_FeatsOfStrength_Gladiator_09",
  COMMUNITY = "Interface\\ICONS\\Achievement_Reputation_ArgentChampion",
  CHANNEL = "Interface\\ICONS\\Achievement_Profession_Fishing_OldManBarlowned",
}

-- Built-in chat channels by the slug that ends their conversation key
-- ("channel::<profile>::trade"). Vanilla-era art so every flavor has it;
-- custom channels ("c:<name>") keep the shared CHANNEL icon.
local BUILT_IN_CHANNEL_ICONS = {
  general = "Interface\\ICONS\\Ability_Warrior_BattleShout",
  trade = "Interface\\ICONS\\INV_Misc_Coin_01",
  tradeservices = "Interface\\ICONS\\Trade_BlackSmithing",
  localdefense = "Interface\\ICONS\\Ability_Warrior_DefensiveStance",
  worlddefense = "Interface\\ICONS\\INV_Shield_06",
  lfg = "Interface\\ICONS\\Spell_Holy_PrayerOfFortitude",
}

local function ChannelIcon(channel, conversationKey)
  if channel == "CHANNEL" and type(conversationKey) == "string" then
    local slug = string.match(conversationKey, "^channel::.-::(.+)$")
    local icon = slug and BUILT_IN_CHANNEL_ICONS[slug]
    if icon then
      return icon
    end
  end
  return CHANNEL_ICONS[channel]
end

local RELATIONSHIP_TINTS = {
  guild = { 0.35, 0.85, 0.4 },
}

local function RelationshipTint(tie)
  return RELATIONSHIP_TINTS[tie]
end

local RELATIONSHIP_ATLASES = {
  guild = "communities-guildbanner-background",
}

-- Atlas drawn untinted in place of the tie's texture path, or nil.
local function RelationshipAtlas(tie)
  return RELATIONSHIP_ATLASES[tie]
end

local ThemeTextures = {
  TEXTURES = Textures,
  RelationshipTint = RelationshipTint,
  RelationshipAtlas = RelationshipAtlas,
  ClassIcon = ClassIcon,
  ApplyClassIcon = ApplyClassIcon,
  ApplyFallbackIcon = ApplyFallbackIcon,
  NormalizeClassTag = NormalizeClassTag,
  FactionIcon = FactionIcon,
  ChannelIcon = ChannelIcon,
}

ns.ThemeTextures = ThemeTextures
return ThemeTextures
