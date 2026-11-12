local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelKey = ns.ChannelChatIngestChannelKey or require("WhisperMessenger.Core.Ingest.ChannelChatIngest.ChannelKey")

-- Resolve live membership at send time; never trust a saved channel number.
local ChannelIndex = {}
local lower = string.lower

local function sameChannel(name, wanted)
  if wanted == "Мир" or wanted == "Мир(А)" or wanted == "Мир(О)" then
    return name == wanted
  end
  local baseName = ChannelKey.BaseName(name)
  return baseName ~= nil and lower(baseName) == wanted
end

local function pack(...)
  return { n = select("#", ...), ... }
end

local function validLayout(list, stride)
  if list.n % stride ~= 0 then
    return false
  end
  for index = 1, list.n, stride do
    if type(list[index]) ~= "number" or type(list[index + 1]) ~= "string" then
      return false
    end
    if stride == 3 then
      local disabled = list[index + 2]
      if disabled ~= nil and type(disabled) ~= "boolean" and disabled ~= 0 and disabled ~= 1 then
        return false
      end
    end
  end
  return true
end

-- Wrath returns id/name pairs; newer clients add a disabled field.
-- nil means enumeration was unavailable, not that the player joined nothing.
-- Malformed or ambiguous enumeration fails closed (no name-lookup fallback).
function ChannelIndex.Joined()
  if type(_G.GetChannelList) ~= "function" then
    return nil
  end
  local ok, list = pcall(function()
    return pack(_G.GetChannelList())
  end)
  if not ok then
    return nil
  end
  local rows = {}
  if list.n == 0 then
    return rows
  end
  local pairsValid, triplesValid = validLayout(list, 2), validLayout(list, 3)
  if pairsValid == triplesValid then
    return rows
  end
  local stride = pairsValid and 2 or 3
  for index = 1, list.n, stride do
    local id, name = list[index], list[index + 1]
    local disabled = stride == 3 and list[index + 2] or false
    if type(id) == "number" and id > 0 and type(name) == "string" and name ~= "" then
      rows[#rows + 1] = { id = id, name = name, disabled = disabled == true or disabled == 1 }
    end
  end
  return rows
end

-- Exact base-name matching only. GetChannelName may accept partial names, so
-- its returned name must also match before accepting its numeric ID.
function ChannelIndex.Resolve(channelBaseName)
  local baseName = ChannelKey.BaseName(channelBaseName)
  if baseName == nil then
    return nil
  end
  local isWorld = baseName == "Мир" or baseName == "Мир(А)" or baseName == "Мир(О)"
  local wanted = isWorld and baseName or lower(baseName)
  local rows = ChannelIndex.Joined()
  if rows then
    local found
    for _, row in ipairs(rows) do
      if not row.disabled and sameChannel(row.name, wanted) then
        if found ~= nil and found ~= row.id then
          return nil
        end
        found = row.id
      end
    end
    return found
  end
  if type(_G.GetChannelName) == "function" then
    local ok, id, name = pcall(_G.GetChannelName, baseName)
    if ok and type(id) == "number" and id > 0 and sameChannel(name, wanted) then
      return id
    end
  end
  return nil
end

ns.ChannelIndex = ChannelIndex
return ChannelIndex
