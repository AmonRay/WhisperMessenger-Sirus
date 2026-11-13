local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelKey = ns.ChannelChatIngestChannelKey or require("WhisperMessenger.Core.Ingest.ChannelChatIngest.ChannelKey")
local ChannelIndex = ns.ChannelIndex or require("WhisperMessenger.Transport.ChannelIndex")

-- Sirus world channels. Horde and Alliance use "Мир"; Renegades join
-- distinct "Мир(А)" / "Мир(О)" channels and use each faction's language.
local WorldChannels = {}

-- PLAYER_FACTION_GROUP ids (SharedXML/SharedConstants.lua) when the table
-- is missing.
local FALLBACK_GROUP = { Horde = 0, Alliance = 1, Renegade = 2 }
-- Language globals per faction, used when PLAYER_FACTION_LANGUAGE is missing.
local LANGUAGE_GLOBALS = { Horde = "LANGUAGE_HORDE", Alliance = "LANGUAGE_ALLIANCE" }

local function globalString(key)
  local value = rawget(_G, key)
  if type(value) == "string" and value ~= "" then
    return value
  end
  return nil
end

local function factionGroup(name)
  local groups = rawget(_G, "PLAYER_FACTION_GROUP")
  if type(groups) == "table" and type(groups[name]) == "number" then
    return groups[name]
  end
  return FALLBACK_GROUP[name]
end

local LANGUAGE_IDS = { Alliance = 7, Horde = 1 }

-- Language IDs identify the language, not the character's faction. The API
-- supplies the localized name required by the Wrath SendChatMessage adapter.
local function apiLanguage(name, api)
  local getName = type(api) == "table" and api.GetLanguageNameByID or nil
  getName = getName or rawget(_G, "GetLanguageNameByID")
  if type(getName) == "function" then
    local ok, value = pcall(getName, LANGUAGE_IDS[name])
    if ok and type(value) == "string" and value ~= "" then
      return value
    end
  end
  local count = type(api) == "table" and api.GetNumLanguages or rawget(_G, "GetNumLanguages")
  local getLanguage = type(api) == "table" and api.GetLanguageByIndex or rawget(_G, "GetLanguageByIndex")
  if type(count) == "function" and type(getLanguage) == "function" then
    local ok, total = pcall(count)
    if ok and type(total) == "number" then
      for index = 1, total do
        local read, value, id = pcall(getLanguage, index)
        if read and id == LANGUAGE_IDS[name] and type(value) == "string" and value ~= "" then
          return value
        end
      end
    end
  end
  return nil
end

local function factionLanguage(name, api)
  local localized = apiLanguage(name, api)
  if localized then
    return localized
  end
  local languages = rawget(_G, "PLAYER_FACTION_LANGUAGE")
  local language = type(languages) == "table" and languages[factionGroup(name)] or nil
  if type(language) == "string" and language ~= "" then
    return language
  end
  return globalString(LANGUAGE_GLOBALS[name])
end

-- The Sirus faction override (C_FactionManager) says Renegade.
function WorldChannels.IsRenegade()
  local manager = rawget(_G, "C_FactionManager")
  if type(manager) ~= "table" or type(manager.GetFactionOverride) ~= "function" then
    return false
  end
  local ok, factionID = pcall(manager.GetFactionOverride)
  return ok and factionID ~= nil and tonumber(factionID) == factionGroup("Renegade")
end

-- Server channel names, not localized LFG UI labels. Those globals can be
-- absent or refer to LookingForGroup rather than Sirus world chat.
local function allChannels()
  return {
    { name = "Мир" },
    { name = "Мир(А)", faction = "Alliance" },
    { name = "Мир(О)", faction = "Horde" },
  }
end

-- The world channels this character should see, as { name = ... } rows.
function WorldChannels.ForCharacter()
  local out = {}
  -- Actual membership takes precedence over faction guesses and UI globals.
  local seen = {}
  for _, row in ipairs(ChannelIndex.Joined() or {}) do
    for _, channel in ipairs(allChannels()) do
      if not row.disabled and row.name == channel.name and not seen[row.name] then
        seen[row.name] = true
        out[#out + 1] = { name = row.name }
      end
    end
  end
  if #out > 0 then
    return out
  end
  -- Do not invent Sirus channels on other clients without a faction manager.
  if type(rawget(_G, "C_FactionManager")) ~= "table" then
    return out
  end
  local renegade = WorldChannels.IsRenegade()
  for _, channel in ipairs(allChannels()) do
    if (channel.faction ~= nil) == renegade then
      out[#out + 1] = { name = channel.name }
    end
  end
  return out
end

local function slugFor(name)
  return ChannelKey.Slug(0, name)
end

-- Slug -> world channel, for every Sirus world channel.
local function worldSlugs()
  local slugs = {}
  for _, channel in ipairs(allChannels()) do
    slugs[slugFor(channel.name)] = channel
  end
  return slugs
end

function WorldChannels.IsWorldChannel(channelBaseName)
  local slug = slugFor(channelBaseName)
  return slug ~= nil and worldSlugs()[slug] ~= nil
end

-- Sirus has no Looking for Group channel of its own: the game's LFG slot runs
-- the world chat ("Мир"), so a separate Looking for Group row would control
-- nothing. True while the character is in a world channel.
function WorldChannels.ReplacesLookingForGroup()
  for _, row in ipairs(ChannelIndex.Joined() or {}) do
    if not row.disabled and WorldChannels.IsWorldChannel(row.name) then
      return true
    end
  end
  return false
end

-- The channel fixes its language regardless of the character's faction.
function WorldChannels.RequiresLanguage(channelBaseName)
  local slug = slugFor(channelBaseName)
  local channel = slug and worldSlugs()[slug] or nil
  return channel ~= nil and channel.faction ~= nil
end

function WorldChannels.LanguageFor(channelBaseName, api)
  local slug = slugFor(channelBaseName)
  local channel = slug and worldSlugs()[slug] or nil
  if channel == nil or channel.faction == nil then
    return nil
  end
  return factionLanguage(channel.faction, api)
end

-- Custom channel rows ({ slug, label, joined }) for the channel picker: drops
-- world channels that don't belong to this character's faction and appends
-- the ones that do but are missing.
function WorldChannels.Arrange(channels)
  local all = worldSlugs()
  local wanted = {}
  for _, channel in ipairs(WorldChannels.ForCharacter()) do
    wanted[slugFor(channel.name)] = channel.name
  end
  local out, seen = {}, {}
  for _, row in ipairs(type(channels) == "table" and channels or {}) do
    -- Live membership wins over an unavailable/stale faction override API.
    if row.joined == true or all[row.slug] == nil or wanted[row.slug] ~= nil then
      out[#out + 1] = row
      seen[row.slug] = true
    end
  end
  for _, channel in ipairs(WorldChannels.ForCharacter()) do
    local slug = slugFor(channel.name)
    if not seen[slug] then
      out[#out + 1] = { slug = slug, label = channel.name, joined = false }
      seen[slug] = true
    end
  end
  return out
end

ns.WorldChannels = WorldChannels
return WorldChannels
