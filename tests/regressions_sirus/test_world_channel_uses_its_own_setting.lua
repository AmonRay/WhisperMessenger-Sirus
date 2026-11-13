local ChannelKey = require("WhisperMessenger.Core.Ingest.ChannelChatIngest.ChannelKey")
local ChannelChatIngest = require("WhisperMessenger.Core.Ingest.ChannelChatIngest")
local ConversationStore = require("WhisperMessenger.Model.ConversationStore")

-- Sirus runs its world chat on the game's Looking for Group channel: the line
-- arrives with zone channel ID 26 and the name "4. Мир". Keying it by that ID
-- made it "lfg", so the "Мир" toggle in the Channels settings did nothing and
-- only the "Looking for Group" one let the messages through.
local WORLD_ID = 26
local WORLD_NAME = "4. Мир"

local function newState(enabledChannels)
  return {
    localProfileId = "x5",
    localPlayerGuid = "Player-1-SELF",
    store = ConversationStore.New({}),
    accountState = { settings = { enabledChannels = enabledChannels }, filters = { ignored = {}, rules = {} } },
    now = function()
      return 100
    end,
  }
end

return function()
  -- test_world_channel_keys_by_its_name_not_the_lfg_id
  do
    assert(
      ChannelKey.Slug(WORLD_ID, "Мир") == "c:мир",
      "Мир must key as its own channel, got " .. tostring(ChannelKey.Slug(WORLD_ID, "Мир"))
    )
    assert(ChannelKey.Slug(0, "Мир(А)") == "c:мир(а)", "Мир(А) keeps its own channel")
    assert(ChannelKey.Slug(0, "Мир(О)") == "c:мир(о)", "Мир(О) keeps its own channel")
  end

  -- test_a_real_looking_for_group_line_still_keys_as_lfg
  do
    assert(ChannelKey.Slug(WORLD_ID, "Looking For Group") == "lfg", "a plain LFG line keeps the built-in key")
    assert(ChannelKey.Slug(1, "General") == "general", "built-in channels still key by zone ID")
  end

  -- test_the_world_channel_toggle_lets_its_lines_through
  do
    local state = newState({ ["c:мир"] = true })
    local handled = ChannelChatIngest.HandleEvent(state, {
      text = "продам глиф",
      playerName = "Шахтёр",
      channelName = WORLD_NAME,
      zoneChannelID = WORLD_ID,
      channelIndex = 4,
      channelBaseName = "Мир",
      lineID = 1,
      guid = "Player-1-X",
    })
    local keys = {}
    for key in pairs(state.store.conversations) do
      keys[#keys + 1] = key
    end
    assert(handled == true, "the world channel line must open its chat, keys: " .. tostring(keys[1]))
    assert(keys[1] == "channel::x5::c:мир", "expected the world channel chat, got: " .. tostring(keys[1]))
  end

  -- test_the_looking_for_group_toggle_does_not_control_the_world_channel
  do
    local state = newState({ lfg = true })
    local handled = ChannelChatIngest.HandleEvent(state, {
      text = "продам глиф",
      playerName = "Шахтёр",
      channelName = WORLD_NAME,
      zoneChannelID = WORLD_ID,
      channelIndex = 4,
      channelBaseName = "Мир",
      lineID = 1,
      guid = "Player-1-X",
    })
    assert(handled == false, "the LFG toggle must not switch the world channel on")
  end
end
