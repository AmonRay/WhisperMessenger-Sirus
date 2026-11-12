local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Store = require("WhisperMessenger.Model.ConversationStore")

return function()
  -- Stale content probes deliberately keep returning true after opt-out.
  -- This exercises the public send boundary, not a mock of policy evaluation.
  for _, activity in ipairs({ "mythic", "battleground", "arena" }) do
    for _, setting in ipairs({ { value = false }, {}, { value = true } }) do
      local sent = {}
      local runtime = {
        accountState = { settings = { blockChatInInstances = setting.value } },
        store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
        localProfileId = "qa-sirus",
        pendingOutgoing = {},
        sendStatusByConversation = {},
        now = function()
          return 100
        end,
        isMythicLockdown = function()
          return activity == "mythic"
        end,
        isCompetitiveContent = function()
          return activity ~= "mythic"
        end,
        chatApi = {
          SendChatMessage = function(text, channel, _language, target)
            sent[#sent + 1] = { text = text, channel = channel, target = target }
          end,
          RegisterAddonMessagePrefix = function() end,
          SendAddonMessage = function() end,
        },
      }
      local function send()
        return SendHandler.HandleSend(runtime, {
          conversationKey = "wow::WOW::thrall",
          target = "Thrall",
          displayName = "Thrall",
          channel = "WOW",
          text = "Привет :heart:",
        }, function() end)
      end
      if setting.value == true then
        assert(send() == false and #sent == 0, activity .. ": true must block addon sends")
        runtime.accountState.settings.blockChatInInstances = false
        assert(send() == true, activity .. ": disabling must immediately release stale addon send locks")
      else
        assert(send() == true, activity .. ": false/nil must allow sends despite stale content flags")
      end
      assert(#sent == 1, "one whisper must reach transport")
      assert(sent[1].text == "Привет :heart:", "wire text must stay unchanged")
      assert(sent[1].target == "Thrall" and sent[1].channel == "WHISPER", "public whisper transport contract must stay intact")
      assert(runtime.sendStatusByConversation["wow::WOW::thrall"] == nil, "old queued status must clear on send")
    end
  end
end
