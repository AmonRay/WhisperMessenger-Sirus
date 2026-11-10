local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Personal emojis: each one belongs to a fixed set of character names.
-- Only those characters see it in the emoji picker, and a ":key:" token
-- renders as the icon only when one of them sent the message. From anyone
-- else the token stays plain text, so typing it by hand gains nothing.
local RestrictedEmojis = {}

local MEDIA = "Interface\\AddOns\\WhisperMessenger\\Media\\"

-- To add an emoji: drop a square power-of-two TGA into Media\ and add an
-- entry here. Owners are character names without the realm.
local DEFINITIONS = {
  {
    key = "clown",
    texture = MEDIA .. "emoji_clown.tga",
    owners = { "Рэйнбоу", "Реинбоу", "Рэинбоу", "Рейнбоу" },
  },
}

local byKey = {}
local orderedKeys = {}

-- "Name-Realm" -> "Name"; anything that isn't a usable string -> nil.
local function baseName(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local base = string.match(name, "^([^%-]+)") or name
  if base == "" then
    return nil
  end
  return base
end

RestrictedEmojis.BaseName = baseName

function RestrictedEmojis.Register(definition)
  if type(definition) ~= "table" or type(definition.key) ~= "string" or type(definition.texture) ~= "string" then
    return false
  end
  local owners = {}
  for _, owner in ipairs(definition.owners or {}) do
    local base = baseName(owner)
    if base ~= nil then
      owners[base] = true
    end
  end
  if byKey[definition.key] == nil then
    table.insert(orderedKeys, definition.key)
  end
  byKey[definition.key] = { key = definition.key, texture = definition.texture, owners = owners }
  return true
end

for _, definition in ipairs(DEFINITIONS) do
  RestrictedEmojis.Register(definition)
end

function RestrictedEmojis.IsRestricted(key)
  return byKey[key] ~= nil
end

function RestrictedEmojis.GetTexture(key)
  local entry = byKey[key]
  return entry and entry.texture or nil
end

function RestrictedEmojis.CanUse(key, name)
  local entry = byKey[key]
  local base = baseName(name)
  return entry ~= nil and base ~= nil and entry.owners[base] == true
end

-- Keys usable by `name`, in definition order.
function RestrictedEmojis.KeysFor(name)
  local keys = {}
  for _, key in ipairs(orderedKeys) do
    if RestrictedEmojis.CanUse(key, name) then
      table.insert(keys, key)
    end
  end
  return keys
end

function RestrictedEmojis.LocalPlayerName()
  if type(UnitName) ~= "function" then
    return nil
  end
  local ok, name = pcall(UnitName, "player")
  if ok then
    return baseName(name)
  end
  return nil
end

-- Who wrote a transcript message: our own lines are the local player;
-- an outgoing record's playerName is the whisper target, not us.
function RestrictedEmojis.SenderOf(message)
  if type(message) ~= "table" then
    return nil
  end
  if message.direction == "out" then
    return RestrictedEmojis.LocalPlayerName()
  end
  return baseName(message.playerName)
end

function RestrictedEmojis.GetInlineTextureMarkup(key, size)
  local entry = byKey[key]
  if entry == nil then
    return nil
  end
  size = size or 16
  return string.format("|T%s:%d:%d|t", entry.texture, size, size)
end

ns.RestrictedEmojis = RestrictedEmojis
return RestrictedEmojis
