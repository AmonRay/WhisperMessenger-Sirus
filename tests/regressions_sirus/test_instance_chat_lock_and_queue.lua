local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local SuspendController = require("WhisperMessenger.Core.Bootstrap.MythicSuspendController")
local Store = require("WhisperMessenger.Model.ConversationStore")

return function()
  local savedChat = _G.C_ChatInfo
  local savedRestricted = _G.C_RestrictedActions
  local savedInstance = _G.GetInstanceInfo
  local savedSuspended = _G._wmSuspended
  local ok, err = pcall(function()
    _G.C_RestrictedActions = nil
    _G.GetInstanceInfo = function()
      return "Город", "none", 0
    end
    for _, source in ipairs({ "api", "event" }) do
      local apiLocked = source == "api"
      _G.C_ChatInfo = {
        InChatMessagingLockdown = function()
          return apiLocked
        end,
      }
      _G._wmSuspended = nil
      local sent = 0
      local settings = { blockChatInInstances = true }
      local runtime = {
        accountState = { settings = settings },
        restrictedActions = RestrictedActions.New(),
        store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
        localProfileId = "qa-sirus",
        pendingOutgoing = {},
        sendStatusByConversation = {},
        now = function()
          return 100
        end,
        chatApi = {
          SendChatMessage = function()
            sent = sent + 1
          end,
          RegisterAddonMessagePrefix = function() end,
          SendAddonMessage = function() end,
        },
      }
      runtime.isChatLocked = function()
        return runtime.restrictedActions.isChatLocked()
      end
      if source == "event" then
        runtime.restrictedActions.updateFromEvent(RestrictedActions.TYPES.Chat, RestrictedActions.STATES.Active)
      end
      local bootstrap = { runtime = runtime }
      SuspendController.Attach(runtime, { Bootstrap = bootstrap })
      -- Use the public reconciliation function, not a replacement policy.
      runtime.syncInstanceChatPolicy = function()
        LifecycleHandlers.SyncInstancePolicy(bootstrap)
      end
      local change = SettingsHandler.Create({ runtime = runtime, accountSettings = settings })
      change("blockChatInInstances", false)
      assert(RestrictedActions.IsCompetitiveContent(runtime, bootstrap), source .. ": opt-out must not bypass real chat lock")
      assert(SendHandler.HandleSend(runtime, {
        conversationKey = "wow::WOW::thrall",
        target = "Thrall",
        displayName = "Thrall",
        channel = "WOW",
        text = "Не отправлять автоматически",
      }, function() end) == false, source .. ": real chat lock must refuse transport")
      assert(sent == 0, "locked message must not reach transport")
      local conversation = runtime.store.conversations["wow::WOW::thrall"]
      local queued = conversation and conversation.messages[#conversation.messages]
      assert(queued and queued.delivery == "queued", "refused message must remain queued in history")
      apiLocked = false
      runtime.restrictedActions.updateFromEvent(RestrictedActions.TYPES.Chat, RestrictedActions.STATES.Inactive)
      change("blockChatInInstances", true)
      runtime.suspend()
      change("blockChatInInstances", false)
      LifecycleHandlers.SyncInstancePolicy(bootstrap)
      assert(not runtime.isChatLocked(), "precondition: genuine chat lock lifted")
      assert(sent == 0, "setting changes, resume and reconciliation must never send queued messages")
      assert(
        conversation.messages[#conversation.messages] == queued and queued.delivery == "queued",
        "queue must survive unlocking for explicit user action"
      )
    end
  end)
  _G.C_ChatInfo = savedChat
  _G.C_RestrictedActions = savedRestricted
  _G.GetInstanceInfo = savedInstance
  _G._wmSuspended = savedSuspended
  assert(ok, err)
end
