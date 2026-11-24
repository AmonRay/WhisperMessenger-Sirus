local Availability = require("WhisperMessenger.Transport.Availability")
local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

-- A whisper says the player was there at that moment. On clients that have
-- no whisper check, that memo used to stay "Online" forever, so a contact who
-- logged off hours ago still looked online. It has to expire, and the live
-- guild/community roster and the friends list decide after that.

local GUID = "Player-1084-0ABC0004"
local FIVE_MINUTES = 300

local function staleRuntime(now, options)
  options = options or {}
  return {
    availabilityByGUID = {
      [GUID] = { status = "CanWhisper", canWhisper = true, confirmedByWhisper = true, confirmedAt = now - FIVE_MINUTES },
    },
    sendStatusByConversation = {},
    store = { conversations = {} },
    localFaction = "Horde",
    friendListApi = options.friendListApi or {},
    now = function()
      return now
    end,
  }
end

local function enrich(runtime)
  local contacts = {
    { guid = GUID, channel = "WOW", displayName = "Klera-Realm", conversationKey = "key", factionName = "Horde" },
  }
  ContactEnricher.EnrichContactsAvailability(contacts, runtime)

  return contacts[1].availability.status
end

return function()
  -- test_expired_whisper_proof_without_any_live_source_is_offline
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local runtime = staleRuntime(1000)
    assert(enrich(runtime) == "Offline", "an expired whisper proof alone must not keep the contact online")
    assert(runtime.availabilityByGUID[GUID] == nil or runtime.availabilityByGUID[GUID].confirmedByWhisper ~= true, "expired proof must be dropped")
  end

  -- test_guild_roster_online_keeps_an_expired_whisper_proof_online
  do
    PresenceCache._reset()
    PresenceCache._setCache({ [GUID] = "online" })
    assert(enrich(staleRuntime(1000)) == "CanWhisper", "the roster showing them online keeps them online")
  end

  -- test_guild_roster_offline_turns_an_expired_whisper_proof_offline
  do
    PresenceCache._reset()
    PresenceCache._setCache({ [GUID] = "offline" })
    assert(enrich(staleRuntime(1000)) == "Offline", "the roster showing them offline turns them offline")
  end

  -- test_friend_online_keeps_an_expired_whisper_proof_online
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local friendListApi = {
      GetFriendInfo = function(name)
        return name == "Klera-Realm" and { connected = true } or nil
      end,
    }
    assert(enrich(staleRuntime(1000, { friendListApi = friendListApi })) == "CanWhisper", "a connected character friend is still online")
  end

  -- test_failed_send_offline_does_not_hide_a_connected_friend
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local runtime = staleRuntime(1000)
    -- A failed send stores a bare Offline. It is not an answer from the
    -- whisper check, so the friends list must still be able to correct it.
    runtime.availabilityByGUID[GUID] = Availability.FromStatus("Offline")
    runtime.friendListApi = {
      GetFriendInfo = function(name)
        return name == "Klera-Realm" and { connected = true } or nil
      end,
    }
    assert(enrich(runtime) == "CanWhisper", "a failed send must not outrank the live friends list")
  end

  -- test_friend_offline_turns_an_expired_whisper_proof_offline
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local friendListApi = {
      GetFriendInfo = function(name)
        return name == "Klera-Realm" and { connected = false } or nil
      end,
    }
    assert(enrich(staleRuntime(1000, { friendListApi = friendListApi })) == "Offline", "a disconnected character friend is offline")
  end

  -- test_fresh_whisper_proof_is_untouched
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local runtime = {
      availabilityByGUID = {
        [GUID] = { status = "CanWhisper", canWhisper = true, confirmedByWhisper = true, confirmedAt = 990 },
      },
      sendStatusByConversation = {},
      store = { conversations = {} },
      localFaction = "Horde",
      now = function()
        return 1000
      end,
    }
    assert(enrich(runtime) == "CanWhisper", "a whisper 10 seconds ago still proves the player is online")
  end

  -- test_friend_online_does_not_override_a_just_received_whisper
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local runtime = {
      availabilityByGUID = {
        [GUID] = { status = "CanWhisper", canWhisper = true, confirmedByWhisper = true, confirmedAt = 1000 },
      },
      sendStatusByConversation = {},
      store = { conversations = {} },
      localFaction = "Horde",
      friendListApi = {
        GetFriendInfo = function()
          -- A lagging friend list still reports the old offline state.
          return { connected = false }
        end,
      },
      now = function()
        return 1000
      end,
    }
    assert(enrich(runtime) == "CanWhisper", "a fresh whisper outranks a lagging friend list")
  end

  -- test_expired_proof_of_an_opposite_faction_contact_is_cross_faction
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local runtime = staleRuntime(1000)
    runtime.availabilityByGUID[GUID].status = "XFaction"
    local contacts = {
      { guid = GUID, channel = "WOW", displayName = "Klera-Realm", factionName = "Alliance" },
    }
    runtime.localFaction = "Horde"
    PresenceCache._setCache({ [GUID] = "online" })
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability.status == "XFaction", "roster online for an opposite-faction contact stays XFaction")
  end

  PresenceCache._reset()
end
