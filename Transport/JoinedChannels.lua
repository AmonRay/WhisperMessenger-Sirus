local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelKey = ns.ChannelChatIngestChannelKey or require("WhisperMessenger.Core.Ingest.ChannelChatIngest.ChannelKey")
local ChannelIndex = ns.ChannelIndex or require("WhisperMessenger.Transport.ChannelIndex")

-- The custom chat channels the character has joined, read from the game.
local JoinedChannels = {}

local CUSTOM_ZONE_ID = 0
-- Community streams are listed as raw "Community:<club>:<stream>" ids.
local COMMUNITY_PREFIX = "Community:"
-- Enum.PermanentChatChannelType.Custom.
local CUSTOM_CHANNEL_TYPE = 3

local function pack(...)
  return { n = select("#", ...), ... }
end

-- Lowercased names of the server's built-in channels. The list follows the
-- current zone (no Trade outside a capital), so it is only the fallback for
-- clients without the channel type.
local function serverChannelNames()
  local names = {}
  local enumerate = rawget(_G, "EnumerateServerChannels")
  if type(enumerate) ~= "function" then
    return names
  end
  local ok, list = pcall(function()
    return pack(enumerate())
  end)
  if not ok then
    return names
  end
  for i = 1, list.n do
    if type(list[i]) == "string" then
      names[string.lower(list[i])] = true
    end
  end
  return names
end

-- The channel's own type, or nil when the client can't tell.
local function channelType(name)
  local chatInfo = _G.C_ChatInfo
  local getInfo = type(chatInfo) == "table" and chatInfo.GetChannelInfoFromIdentifier or nil
  if type(getInfo) ~= "function" then
    return nil
  end
  local ok, info = pcall(getInfo, name)
  if ok and type(info) == "table" then
    return info.channelType
  end
  return nil
end

local function isCustom(name, serverNames)
  if string.find(name, COMMUNITY_PREFIX, 1, true) then
    return false
  end
  local kind = channelType(name)
  if kind ~= nil then
    return kind == CUSTOM_CHANNEL_TYPE
  end
  return not serverNames[string.lower(name)]
end

-- Custom channels as { slug, label, joined }, in the game's channel order.
function JoinedChannels.Custom()
  local channels = {}
  local rows = ChannelIndex.Joined() or {}
  local serverNames = serverChannelNames()
  local seen = {}
  for _, row in ipairs(rows) do
    local name = row.name
    -- World chat may be reported as a built-in server channel on Sirus.
    local isWorld = name == "Мир" or name == "Мир(А)" or name == "Мир(О)"
    if isWorld or isCustom(name, serverNames) then
      local slug = ChannelKey.Slug(CUSTOM_ZONE_ID, name)
      if slug and not seen[slug] then
        seen[slug] = true
        local liveId = ChannelIndex.Resolve(name)
        channels[#channels + 1] = { slug = slug, label = name, joined = liveId ~= nil, id = liveId }
      end
    end
  end
  return channels
end

ns.JoinedChannels = JoinedChannels
return JoinedChannels
