-- Sirus sends CHAT_MSG_CHANNEL without the channel base name argument that
-- retail has (the Wrath client never used it), so a channel that is not one of
-- Blizzard's own IDs could not be keyed at all: the player ticked "Мир", its
-- lines arrived with an unknown zone channel ID, and the Channels tab stayed
-- empty. The line's own channel name ("4. Мир") has to identify it.
local function loadEventBridge()
  package.preload["WhisperMessenger.Transport.BNetResolver"] = function()
    return {
      NormalizeAvailabilityStatus = function(status)
        return status
      end,
      ResolveAccountInfo = function()
        return nil
      end,
      ResolvePlayerInfo = function()
        return {}
      end,
    }
  end
  package.preload["WhisperMessenger.Core.SoundPlayer"] = function()
    return { Play = function() end }
  end
  return require("WhisperMessenger.Core.Bootstrap.EventBridge")
end

return function()
  local EventBridge = loadEventBridge()
  local Store = require("WhisperMessenger.Model.ConversationStore")
  local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")

  local function makeRuntime(enabledChannels)
    local refreshKeys = {}
    return {
      localProfileId = "x5",
      localPlayerGuid = "Player-1-SELF",
      store = Store.New({ maxMessagesPerConversation = 50 }),
      channelMessageStore = ChannelMessageStore.New(),
      accountState = { settings = { enabledChannels = enabledChannels }, filters = { ignored = {}, rules = {} } },
      collapseIndex = {},
      now = function()
        return 100
      end,
      scheduleIncomingRefresh = function(key)
        refreshKeys[#refreshKeys + 1] = key
      end,
    },
      refreshKeys
  end

  -- 12 arguments, as the Wrath client sends them: no channel base name.
  local function wrathLine(runtime, text, sender, channelName, zoneChannelID, channelIndex, lineID)
    return EventBridge.RouteChannelEvent(
      runtime,
      "CHAT_MSG_CHANNEL",
      text,
      sender,
      "Всеобщий",
      channelName,
      sender,
      "",
      zoneChannelID,
      channelIndex,
      nil,
      0,
      lineID,
      "Player-1-" .. sender
    )
  end

  -- test_channel_setting_key_survives_a_russian_locale
  -- string.lower follows the process locale: on a Russian Windows it turns the
  -- bytes of "Мир" into garbage, so the key the picker saved ("c:мир") never
  -- matched the key an incoming line built.
  do
    local ChannelKey = require("WhisperMessenger.Core.Ingest.ChannelChatIngest.ChannelKey")
    assert(ChannelKey.Slug(4, "Мир") == "c:мир", "the world channel keeps its saved key")
    assert(ChannelKey.Slug(5, "Мир(А)") == "c:мир(а)", "Мир(А) lowercases byte for byte")
    assert(ChannelKey.Slug(0, "Trade") == "c:trade", "ASCII names still lowercase")
    assert(ChannelKey.LowerName("ЁЖ") == "ёж", "Cyrillic uppercase lowercases with the same bytes")
  end

  -- test_world_channel_line_opens_its_chat_without_a_base_name_argument
  do
    local runtime, refreshKeys = makeRuntime({ ["c:мир"] = true })
    wrathLine(runtime, "Всем привет", "Рэйнбоу", "4. Мир", 4, 4, 9001)
    local key = "channel::x5::c:мир"
    local conversation = runtime.store.conversations[key]
    assert(conversation ~= nil, "the world channel line must open its chat, keys: " .. tostring(next(runtime.store.conversations)))
    assert(#conversation.messages == 1, "the line is stored once, got " .. #conversation.messages)
    assert(conversation.messages[1].text == "Всем привет", "the line keeps its text")
    assert(conversation.displayName == "Мир", "the chat is named after the channel, got " .. tostring(conversation.displayName))
    assert(#refreshKeys == 1 and refreshKeys[1] == key, "the open tab refreshes once")
  end

  -- test_world_channel_line_is_recorded_as_context_too
  do
    local runtime = makeRuntime({ ["c:мир"] = true })
    wrathLine(runtime, "продам руду", "Шахтёр", "4. Мир", 4, 4, 9002)
    local entry = ChannelMessageStore.GetLatest(runtime.channelMessageStore, "Шахтёр")
    assert(entry ~= nil, "the line is kept for whisper context")
    assert(entry.zoneChannelID == 4, "it keeps the zone channel ID, got " .. tostring(entry.zoneChannelID))
  end

  -- test_disabled_world_channel_still_opens_nothing
  do
    local runtime = makeRuntime({})
    wrathLine(runtime, "Всем привет", "Рэйнбоу", "4. Мир", 4, 4, 9003)
    assert(next(runtime.store.conversations) == nil, "a channel the player did not tick opens no chat")
  end

  -- test_other_world_channel_names_stay_separate
  do
    local runtime = makeRuntime({ ["c:мир"] = true, ["c:мир(а)"] = true })
    wrathLine(runtime, "за Альянс", "Пал", "5. Мир(А)", 5, 5, 9004)
    assert(runtime.store.conversations["channel::x5::c:мир(а)"] ~= nil, "Мир(А) keys by its own name")
    assert(runtime.store.conversations["channel::x5::c:мир"] == nil, "Мир stays empty")
  end
end
