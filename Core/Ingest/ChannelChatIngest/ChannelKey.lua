local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Which conversation a public channel line belongs to. Built-in channel
-- names are localized, so they key by zone channel ID; custom channels
-- (ID 0) key by their lowercased base name.
local ChannelKey = {}

ChannelKey.ZONE_CHANNEL_IDS = {
  [1] = "general",
  [2] = "trade",
  [22] = "localdefense",
  [23] = "worlddefense",
  [26] = "lfg",
  [42] = "tradeservices",
}

local CUSTOM_PREFIX = "c:"

-- UTF-8 lowercase for channel keys. The C string.lower follows the process
-- locale: on a Russian Windows it rewrites the bytes of Cyrillic and the key
-- stops matching the one the picker saved. ASCII and Cyrillic are lowered
-- here, every other byte is copied as is.
function ChannelKey.LowerName(name)
  if type(name) ~= "string" then
    return name
  end
  local out = {}
  local index = 1
  while index <= #name do
    local first = string.byte(name, index)
    if first >= 65 and first <= 90 then
      out[#out + 1] = string.char(first + 32)
      index = index + 1
    elseif first == 208 then
      local second = string.byte(name, index + 1)
      if second == nil then
        out[#out + 1] = string.sub(name, index)
        break
      end
      if second == 129 then -- Ё
        out[#out + 1] = string.char(209, 145)
      elseif second >= 144 and second <= 175 then -- А..Я -> а..я
        out[#out + 1] = string.char(208, second + 32)
      else
        out[#out + 1] = string.sub(name, index, index + 1)
      end
      index = index + 2
    else
      out[#out + 1] = string.char(first)
      index = index + 1
    end
  end
  return table.concat(out)
end

-- "General - Stormwind City" -> "General"; names without a zone unchanged.
function ChannelKey.BaseName(channelBaseName)
  if type(channelBaseName) ~= "string" or channelBaseName == "" then
    return nil
  end
  return string.match(channelBaseName, "^(.-) %- ") or channelBaseName
end

-- The bare base name of a channel line's own channel name ("4. Мир" ->
-- "Мир"), for clients that send no channel base name argument: the Wrath one
-- does not, and the channels the game itself runs there (Sirus' world
-- channels included) are then named only by this string. A zone suffix
-- (" - Stormwind City") is dropped, as BaseName does for the argument newer
-- clients send.
function ChannelKey.BaseNameFromChannelName(channelName)
  if type(channelName) ~= "string" or channelName == "" then
    return nil
  end
  local label = string.match(channelName, "^%d+%.%s*(.-)%s*%-") or string.match(channelName, "^%d+%.%s*(.+)$")
  if label == nil or label == "" then
    label = channelName
  end
  return ChannelKey.BaseName(label) or label
end

-- The slug behind "CHANNEL::<slug>", or nil when the line names no channel.
function ChannelKey.Slug(zoneChannelID, channelBaseName)
  local builtIn = ChannelKey.ZONE_CHANNEL_IDS[zoneChannelID]
  if builtIn ~= nil then
    return builtIn
  end
  local baseName = ChannelKey.BaseName(channelBaseName)
  return baseName and (CUSTOM_PREFIX .. ChannelKey.LowerName(baseName)) or nil
end

-- A channel the game itself runs (General, Trade, LookingForGroup, ...). Only
-- channels players or addons create have zone ID 0. Any other ID counts, since
-- ZONE_CHANNEL_IDS misses some (Classic's LookingForGroup is 24, Services 45).
function ChannelKey.IsBuiltIn(zoneChannelID)
  return type(zoneChannelID) == "number" and zoneChannelID ~= 0
end

-- A non-zero zone channel ID missing from ZONE_CHANNEL_IDS: the line keys by
-- its (localized) name instead, so /wmsg perf counts these.
function ChannelKey.IsUnknownZoneID(zoneChannelID)
  return type(zoneChannelID) == "number" and zoneChannelID ~= 0 and ChannelKey.ZONE_CHANNEL_IDS[zoneChannelID] == nil
end

function ChannelKey.ContactKey(zoneChannelID, channelBaseName)
  local slug = ChannelKey.Slug(zoneChannelID, channelBaseName)
  return slug and ("CHANNEL::" .. slug) or nil
end

-- "1. General - Stormwind City" -> "Stormwind City"; nil without a zone part.
function ChannelKey.ZoneLabel(channelName)
  if type(channelName) ~= "string" then
    return nil
  end
  return string.match(channelName, " %- (.+)$")
end

-- The key in settings.enabledChannels.
function ChannelKey.SettingKey(slug)
  return slug
end

ns.ChannelChatIngestChannelKey = ChannelKey
return ChannelKey
