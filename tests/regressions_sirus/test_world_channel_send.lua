local ChatGateway = require("WhisperMessenger.Transport.ChatGateway")
local ChannelIndex = require("WhisperMessenger.Transport.ChannelIndex")
local ChannelKey = require("WhisperMessenger.Core.Ingest.ChannelChatIngest.ChannelKey")
local GroupSendPolicy = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPolicy")

return function()
  local names = {
    "GetChannelList", "GetChannelName", "UnitFactionGroup", "C_FactionManager",
    "LFG_CHANNEL_NAME", "LFG_CHANNEL_NAME_ALLIANCE", "LFG_CHANNEL_NAME_HORDE",
    "LANGUAGE_ALLIANCE", "LANGUAGE_HORDE", "PLAYER_FACTION_LANGUAGE", "PLAYER_FACTION_GROUP",
  }
  local saved = {}
  for _, name in ipairs(names) do
    saved[name] = rawget(_G, name)
  end
  local ok, err = pcall(function()
    _G.LFG_CHANNEL_NAME = "Мир"
    _G.LFG_CHANNEL_NAME_ALLIANCE = "Мир(А)"
    _G.LFG_CHANNEL_NAME_HORDE = "Мир(О)"
    _G.LANGUAGE_ALLIANCE = "Всеобщий"
    _G.LANGUAGE_HORDE = "Орочий"
    _G.PLAYER_FACTION_GROUP = { Horde = 0, Alliance = 1, Renegade = 2 }
    _G.PLAYER_FACTION_LANGUAGE = { [0] = "Орочий", [1] = "Всеобщий" }
    local faction = "Horde"
    local renegade = false
    _G.UnitFactionGroup = function()
      return faction
    end
    _G.C_FactionManager = {
      GetFactionOverride = function()
        return renegade and 2 or nil
      end,
    }
    local joined = {}
    _G.GetChannelList = function()
      return unpack(joined)
    end
    -- A stale name lookup must not override an authoritative joined list.
    _G.GetChannelName = function()
      return 99
    end

    local sent = {}
    local conversations = {}
    local runtime = {
      localProfileId = "qa-sirus",
      store = { conversations = conversations },
      chatApi = {
        SendChatMessage = function(text, channel, language, target)
          sent[#sent + 1] = { text = text, channel = channel, language = language, target = target }
        end,
      },
    }
    local policy = GroupSendPolicy.Create({ runtime = runtime, chatGateway = ChatGateway })
    local function conversation(name)
      local key = "channel::qa-sirus::" .. ChannelKey.Slug(0, name)
      local row = {
        conversationKey = key,
        ownerProfileId = "qa-sirus",
        channel = "CHANNEL",
        channelBaseName = name,
        channelIndex = 99,
        messages = { { text = "saved history", direction = "in" } },
      }
      conversations[key] = row
      return row
    end
    local function send(row)
      return policy.sendPayload({ channel = "CHANNEL", conversationKey = row.conversationKey, text = "Привет :heart:" })
    end

    -- test_horde_and_alliance_send_to_joined_plain_world_channel
    for _, playerFaction in ipairs({ "Horde", "Alliance" }) do
      faction = playerFaction
      joined = { 1, "Общий", false, 4, "Мир", false }
      local row = conversation("Мир")
      assert(policy.getNotice(row) == nil, playerFaction .. ": joined Мир must be writable")
      assert(send(row) == true, playerFaction .. ": Мир send must succeed")
      local call = sent[#sent]
      assert(call.target == 4 and call.channel == "CHANNEL", "must send to the joined numerical ID")
      assert(call.language == nil, "normal faction world chat keeps the default language")
      assert(call.text == "Привет :heart:", "wire text must not be replaced by display markup")
    end

    -- test_renegade_channels_have_separate_keys_history_targets_and_languages
    renegade = true
    joined = { 6, "Мир(О)", false, 8, "Мир(А)", false }
    local horde = conversation("Мир(О)")
    local alliance = conversation("Мир(А)")
    assert(horde.conversationKey ~= alliance.conversationKey, "renegade histories must remain distinct")
    for _, case in ipairs({ { horde, 6, "Орочий" }, { alliance, 8, "Всеобщий" } }) do
      local row, target, language = case[1], case[2], case[3]
      local history = row.messages
      assert(policy.getNotice(row) == nil, "joined faction world channel must be writable")
      assert(send(row) == true, "renegade world send must succeed")
      assert(sent[#sent].target == target, "must not send to the other faction's channel")
      assert(sent[#sent].language == language, "renegade send must use the channel faction language")
      assert(row.messages == history and history[1].text == "saved history", "sending must preserve history")
    end

    -- test_pair_enumeration_and_language_do_not_depend_on_character_faction_or_lfg_labels
    _G.LFG_CHANNEL_NAME = "LookingForGroup"
    _G.LFG_CHANNEL_NAME_ALLIANCE = nil
    _G.LFG_CHANNEL_NAME_HORDE = nil
    renegade = false
    for _, playerFaction in ipairs({ "Horde", "Alliance" }) do
      faction = playerFaction
      joined = { 2, "Общий", 6, "Мир(О)", 8, "Мир(А)" }
      for _, case in ipairs({ { horde, 6, "Орочий" }, { alliance, 8, "Всеобщий" } }) do
        assert(send(case[1]) == true, "pair enumeration must resolve each joined faction world channel")
        local call = sent[#sent]
        assert(call.channel == "CHANNEL" and call.target == case[2], "channel ID must be the fourth send argument")
        assert(call.language == case[3], "language must follow the channel, never the character faction")
      end
      joined = { 4, "Мир" }
      local plain = conversation("Мир")
      assert(send(plain) == true and sent[#sent].target == 4, "single pair must resolve without LFG labels")
    end

    -- test_renumber_resolves_on_every_send_without_rekeying_history
    local originalKey, history = horde.conversationKey, horde.messages
    joined = { 3, "Мир(А)", false, 12, "Мир(О)", false }
    assert(send(horde) == true, "renumbered channel remains writable")
    assert(sent[#sent].target == 12, "stored ID and previous live ID must both be ignored")
    assert(horde.conversationKey == originalKey and conversations[originalKey] == horde, "renumber must not rekey the conversation")
    assert(horde.messages == history, "renumber must preserve the history object")

    -- test_absent_channel_never_falls_back_to_other_faction_or_partial_match
    for _, list in ipairs({
      { 3, "Мир(А)", false },
      { 3, "Мир", false },
      { 3, "Мир(О) поиск", false },
      {},
      { 0, "Мир(О)", false },
      { 3, "Мир(О)", true },
      { 3, "Мир(О)", 1 },
      { 3, "Мир(О)", false, 7, "Мир(О)", false },
      { 3, "Мир(О)", 7, "Мир(О)" },
      { 3, "Мир(О). Поиск", false },
    }) do
      joined = list
      local before = #sent
      assert(ChannelIndex.Resolve("Мир(О)") == nil, "unjoined, invalid or disabled ID must not resolve")
      assert(policy.getNotice(horde) ~= nil, "missing exact channel must show a notice")
      assert(send(horde) == false, "missing channel must refuse sending")
      assert(#sent == before, "no other channel may receive the message")
    end
  end)
  for _, name in ipairs(names) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end
