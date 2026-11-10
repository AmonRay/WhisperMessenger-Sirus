local WorldChannels = require("WhisperMessenger.Transport.WorldChannels")
local ChatGateway = require("WhisperMessenger.Transport.ChatGateway")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

local KEYS = {
  "C_FactionManager",
  "PLAYER_FACTION_GROUP",
  "PLAYER_FACTION_LANGUAGE",
  "LANGUAGE_ALLIANCE",
  "LANGUAGE_HORDE",
  "LANGUAGE_RENEGADE",
  "LFG_CHANNEL_NAME",
  "LFG_CHANNEL_NAME_ALLIANCE",
  "LFG_CHANNEL_NAME_HORDE",
  "GetChannelList",
  "GetChannelName",
}

local function withSirus(factionID, fn)
  local saved = {}
  for _, k in ipairs(KEYS) do
    saved[k] = rawget(_G, k)
  end
  rawset(_G, "PLAYER_FACTION_GROUP", { [0] = "Horde", [1] = "Alliance", [2] = "Renegade", Horde = 0, Alliance = 1, Renegade = 2 })
  rawset(_G, "LANGUAGE_ALLIANCE", "всеобщий")
  rawset(_G, "LANGUAGE_HORDE", "орочий")
  rawset(_G, "LANGUAGE_RENEGADE", "арго скорпидов")
  rawset(_G, "PLAYER_FACTION_LANGUAGE", { [0] = "орочий", [1] = "всеобщий", [2] = "арго скорпидов" })
  rawset(_G, "LFG_CHANNEL_NAME", "Мир")
  rawset(_G, "LFG_CHANNEL_NAME_ALLIANCE", "Мир(А)")
  rawset(_G, "LFG_CHANNEL_NAME_HORDE", "Мир(О)")
  rawset(_G, "C_FactionManager", {
    GetFactionOverride = function()
      return factionID
    end,
  })
  local ok, err = pcall(fn)
  for _, k in ipairs(KEYS) do
    rawset(_G, k, saved[k])
  end
  if not ok then
    error(err, 0)
  end
end

local function names(list)
  local out = {}
  for i, entry in ipairs(list) do
    out[i] = entry.name
  end
  return table.concat(out, ",")
end

local function spyApi()
  local calls = {}
  return {
    _calls = calls,
    SendChatMessage = function(text, chatType, language, target)
      calls[#calls + 1] = { text = text, chatType = chatType, language = language, target = target }
    end,
  }
end

return function()
  -- Renegade: both faction world channels, each with its faction's language.
  withSirus(2, function()
    assert(WorldChannels.IsRenegade() == true, "faction override 2 should be Renegade")
    assert(
      names(WorldChannels.ForCharacter()) == "Мир(А),Мир(О)",
      "Renegade should see Мир(А) and Мир(О), got " .. names(WorldChannels.ForCharacter())
    )
    assert(WorldChannels.LanguageFor("Мир(А)") == "всеобщий", "Мир(А) should use всеобщий for a Renegade")
    assert(WorldChannels.LanguageFor("Мир(О)") == "орочий", "Мир(О) should use орочий for a Renegade")
    assert(WorldChannels.LanguageFor("Мир") == nil, "plain Мир has no language override")
    assert(WorldChannels.LanguageFor("Торговля") == nil, "other channels have no language override")
  end)

  -- Horde / Alliance: only the plain world channel, no language override.
  for _, factionID in ipairs({ 0, 1 }) do
    withSirus(factionID, function()
      assert(WorldChannels.IsRenegade() == false, "faction " .. factionID .. " is not Renegade")
      assert(names(WorldChannels.ForCharacter()) == "Мир", "faction " .. factionID .. " should see only Мир")
      assert(WorldChannels.LanguageFor("Мир(А)") == nil, "no override outside Renegade (А)")
      assert(WorldChannels.LanguageFor("Мир(О)") == nil, "no override outside Renegade (О)")
    end)
  end

  -- No Sirus faction manager (retail/classic): never Renegade, nothing to add.
  withSirus(2, function()
    rawset(_G, "C_FactionManager", nil)
    assert(WorldChannels.IsRenegade() == false, "no faction manager means not Renegade")
    assert(WorldChannels.LanguageFor("Мир(А)") == nil, "no override without a faction manager")
  end)

  -- Arrange: drop world channels of the wrong faction, add the missing ones.
  withSirus(2, function()
    local arranged = WorldChannels.Arrange({
      { slug = "c:" .. string.lower("Мир(А)"), label = "Мир(А)", joined = true },
      { slug = "c:" .. string.lower("Мир"), label = "Мир", joined = true },
      { slug = "c:craftscan", label = "CraftScan", joined = true },
    })
    local labels = {}
    for i, row in ipairs(arranged) do
      labels[i] = row.label
    end
    assert(table.concat(labels, ",") == "Мир(А),CraftScan,Мир(О)", "Renegade rows: got " .. table.concat(labels, ","))
    assert(arranged[3].slug == "c:" .. string.lower("Мир(О)"), "added row should use the custom-channel slug")
  end)
  withSirus(0, function()
    local arranged = WorldChannels.Arrange({
      { slug = "c:" .. string.lower("Мир(А)"), label = "Мир(А)", joined = true },
      { slug = "c:" .. string.lower("Мир(О)"), label = "Мир(О)", joined = true },
    })
    assert(#arranged == 1 and arranged[1].label == "Мир", "Horde should list only Мир")
  end)

  -- Sending: a Renegade speaks the channel's faction language in Мир(А)/(О).
  withSirus(2, function()
    rawset(_G, "GetChannelList", function()
      return 5, "Мир(А)", false, 6, "Мир(О)", false, 2, "Торговля", false
    end)
    local api = spyApi()
    ChatGateway.Send(api, { channel = ChannelType.CHANNEL, channelBaseName = "Мир(А)" }, "привет")
    ChatGateway.Send(api, { channel = ChannelType.CHANNEL, channelBaseName = "Мир(О)" }, "привет")
    ChatGateway.Send(api, { channel = ChannelType.CHANNEL, channelBaseName = "Торговля" }, "wts")
    assert(api._calls[1].language == "всеобщий" and api._calls[1].target == 5, "Мир(А) should send in всеобщий to channel 5")
    assert(api._calls[2].language == "орочий" and api._calls[2].target == 6, "Мир(О) should send in орочий to channel 6")
    assert(api._calls[3].language == nil, "Торговля keeps the default language")
  end)
  withSirus(1, function()
    rawset(_G, "GetChannelList", function()
      return 5, "Мир(А)", false
    end)
    local api = spyApi()
    ChatGateway.Send(api, { channel = ChannelType.CHANNEL, channelBaseName = "Мир(А)" }, "x")
    assert(api._calls[1].language == nil, "Alliance keeps the default language")
  end)

  print("PASS: test_world_channels")
end
