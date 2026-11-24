local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Competitive = ns.BootstrapLifecycleHandlersCompetitive or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Competitive")
local Presence = ns.BootstrapLifecycleHandlersPresence or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local RestrictionState = ns.BootstrapLifecycleHandlersRestrictionState
  or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.RestrictionState")
local GroupMembership = ns.BootstrapLifecycleHandlersGroupMembership or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.GroupMembership")
local OnlineNotify = ns.BootstrapLifecycleHandlersOnlineNotify or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.OnlineNotify")
local RelationshipRefresh = ns.BootstrapLifecycleHandlersRelationshipRefresh
  or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.RelationshipRefresh")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")

local RestrictedActions = ns.BootstrapRestrictedActions or require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local Common = ns.BootstrapLifecycleHandlersCommon or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
local LifecycleHandlers = {}

-- Call immediately after changing settings.blockChatInInstances. No queued
-- messages are sent here: leaving an addon lock must not bypass hardware rules.
function LifecycleHandlers.SyncInstancePolicy(Bootstrap, deps)
  local runtime = Bootstrap.runtime
  if not runtime then
    return
  end
  deps = deps or {}
  local enabled = RestrictedActions.BlockChatInInstances(runtime)
  -- With the policy off the flags the game's own events set stay untouched
  -- (ChallengeMode owns mythic, encounter/PvP own theirs): they no longer
  -- answer the runtime checks, but a later flag reader must not see them
  -- cleared.
  if enabled then
    local detector = deps.getContentDetector and deps.getContentDetector() or ns.ContentDetector
    Bootstrap._inMythicContent = RestrictedActions.IsMythicLockdown(runtime) or (detector ~= nil and detector.IsMythicRestricted(_G.GetInstanceInfo))
    if detector then
      Bootstrap._inCompetitiveContent = detector.IsCompetitiveContent(_G.GetInstanceInfo)
    end
  end
  -- The game's restriction event path suspends on its own; only the Sirus
  -- instance detection suspends here when nothing else did.
  local alreadySuspended = RestrictedActions.For(Bootstrap).flag("mythic")
  if enabled and Bootstrap._inMythicContent and not alreadySuspended then
    if runtime.suspend then
      runtime.suspend()
    end
  elseif not alreadySuspended and (runtime._instanceChatSuspended or _G._wmSuspended) then
    -- A pause the game's own restriction (or ChallengeMode) owns is resumed by
    -- that path, not by leaving an instance the addon no longer flags.
    if runtime.resume then
      runtime.resume()
    end
  end
  if Bootstrap.syncChatFilters then
    Bootstrap.syncChatFilters()
  end
  if runtime.syncReplyKey then
    runtime.syncReplyKey()
  end
  if not RestrictedActions.IsCompetitiveContent(runtime, Bootstrap) and not RestrictedActions.IsMythicLockdown(runtime, Bootstrap) then
    runtime.messagingNotice = nil
    for key, status in pairs(runtime.sendStatusByConversation or {}) do
      if status.status == "Mythic Lockdown" or status.status == "Competitive Content" then
        runtime.sendStatusByConversation[key] = nil
      end
    end
  end
  Common.notifyCompetitiveState(Bootstrap)
  Common.refreshRuntimeWindow(Bootstrap)
end

local function handle(Bootstrap, event, deps, ...)
  -- Runs first and never consumes the event: the branches below return.
  RelationshipRefresh.handle(Bootstrap, event, ...)
  if event == "PLAYER_GUILD_UPDATE" then
    return true
  end

  if event == "ADDON_RESTRICTION_STATE_CHANGED" then
    local restrictionType, newState = ...
    return RestrictionState.handleAddonRestrictionStateChanged(Bootstrap, restrictionType, newState, deps)
  end

  if event == "BN_FRIEND_LIST_SIZE_CHANGED" or event == "BN_FRIEND_INFO_CHANGED" then
    -- The friend list may now know a character it did not know before (a
    -- friend added, the list loading late, a friend logging on to it), so
    -- characters it missed are looked up again.
    if Bootstrap.runtime then
      Bootstrap.runtime.characterMergeMisses = nil
    end
    return Presence.handleBNetFriendEvent(Bootstrap, deps)
  end

  if event == "FRIENDLIST_UPDATE" then
    return OnlineNotify.handleFriendListUpdate(Bootstrap)
  end

  if event == "BN_FRIEND_ACCOUNT_ONLINE" or event == "BN_FRIEND_ACCOUNT_OFFLINE" then
    local bnetAccountID = ...
    return OnlineNotify.handleBNetAccountEvent(Bootstrap, bnetAccountID, event == "BN_FRIEND_ACCOUNT_ONLINE")
  end

  if event == "PLAYER_LOGOUT" then
    if Bootstrap.runtime then
      MessageReactions.FlushControls(Bootstrap.runtime)
      MessageReactions.ClearTransient(Bootstrap.runtime)
    end
    -- Group chats (party, raid, instance) are persisted across /reload and
    -- logout so the user can keep recent history. Membership transitions
    -- are tracked separately via GROUP_ROSTER_UPDATE.
    return Presence.handlePlayerLogout(Bootstrap)
  end

  if event == "GROUP_FORMED" or event == "GROUP_JOINED" then
    local category, partyGUID = ...
    return GroupMembership.handleGroupJoined(Bootstrap, category, partyGUID)
  end

  if event == "GROUP_LEFT" then
    local category, partyGUID = ...
    return GroupMembership.handleGroupLeft(Bootstrap, category, partyGUID)
  end

  if event == "GROUP_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
    return GroupMembership.handleGroupRosterUpdate(Bootstrap)
  end

  if Competitive.handleChallengeModeEvent(Bootstrap, event) then
    return true
  end

  if Competitive.handleEncounterEvent(Bootstrap, event, deps) then
    return true
  end

  if event == "PLAYER_REGEN_DISABLED" then
    return Competitive.handleCombatStart(Bootstrap)
  end

  if event == "PLAYER_REGEN_ENABLED" then
    return Competitive.handleCombatEnd(Bootstrap, deps)
  end

  if event == "ZONE_CHANGED_NEW_AREA" then
    return Competitive.handleZoneChangedNewArea(Bootstrap, deps)
  end

  if event == "PLAYER_ENTERING_WORLD" then
    local handled = Presence.handlePlayerEnteringWorld(Bootstrap, deps)
    GroupMembership.handleGroupRosterUpdate(Bootstrap)
    return handled
  end

  if event == "UPDATE_BINDINGS" or event == "HOUSE_EDITOR_MODE_CHANGED" then
    -- User remapped REPLY, or opened/closed the house editor (which needs R
    -- for "remove decor"). Re-run syncReplyKey so our override follows.
    if Bootstrap.runtime and Bootstrap.runtime.syncReplyKey then
      Bootstrap.runtime.syncReplyKey()
    end
    return true
  end

  if event == "GUILD_ROSTER_UPDATE" or event == "CLUB_MEMBER_UPDATED" or event == "CLUB_MEMBER_ADDED" or event == "CLUB_MEMBER_REMOVED" then
    return Presence.handlePresenceInvalidation(Bootstrap, deps)
  end

  return false
end

function LifecycleHandlers.Handle(Bootstrap, event, deps, ...)
  local handled = handle(Bootstrap, event, deps, ...)
  -- Zone and world entry handlers re-derive the instance state themselves.
  -- The game's own ADDON_RESTRICTION_STATE_CHANGED path owns its filters and
  -- pause (it syncs and suspends on its own), so only the legacy ChallengeMode
  -- events re-sync the Sirus instance policy here.
  if
    (event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET")
    and RestrictedActions.BlockChatInInstances(Bootstrap.runtime)
  then
    LifecycleHandlers.SyncInstancePolicy(Bootstrap, deps)
  end
  return handled
end

ns.BootstrapLifecycleHandlers = LifecycleHandlers
return LifecycleHandlers
