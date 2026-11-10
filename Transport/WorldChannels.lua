local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelKey = ns.ChannelChatIngestChannelKey or require("WhisperMessenger.Core.Ingest.ChannelChatIngest.ChannelKey")

-- Sirus world channels. Horde and Alliance characters share one channel,
-- LFG_CHANNEL_NAME ("Мир"). A Renegade sits in both faction channels,
-- "Мир(А)" and "Мир(О)", and must speak that faction's language there
-- (всеобщий / орочий) instead of the Renegade default. No-op off Sirus.
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

local function factionLanguage(name)
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

-- Every Sirus world channel: { name, language? } in display order.
local function allChannels()
  local channels = {}
  local function add(key, faction)
    local name = globalString(key)
    if name then
      channels[#channels + 1] = { name = name, faction = faction }
    end
  end
  add("LFG_CHANNEL_NAME", nil)
  add("LFG_CHANNEL_NAME_ALLIANCE", "Alliance")
  add("LFG_CHANNEL_NAME_HORDE", "Horde")
  return channels
end

-- The world channels this character should see, as { name = ... } rows.
function WorldChannels.ForCharacter()
  local renegade = WorldChannels.IsRenegade()
  local out = {}
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

-- The language to send in for this channel, or nil for the default. Only a
-- Renegade gets one, and only in Мир(А) / Мир(О).
function WorldChannels.LanguageFor(channelBaseName)
  if not WorldChannels.IsRenegade() then
    return nil
  end
  local slug = slugFor(channelBaseName)
  local channel = slug and worldSlugs()[slug] or nil
  if channel == nil or channel.faction == nil then
    return nil
  end
  return factionLanguage(channel.faction)
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
    if all[row.slug] == nil or wanted[row.slug] ~= nil then
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
