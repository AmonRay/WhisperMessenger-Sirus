local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Router = require("WhisperMessenger.Core.EventRouter")
local Store = require("WhisperMessenger.Model.ConversationStore")
local RestrictionPredicates = require("tests.helpers.restriction_predicates")

-- The pending record keeps the text as typed, links included, so a message the
-- game never confirms can be sent again with its item link. sendWhisper clears
-- the record on success, so the test watches what is handed to the router.
local KEY = "me::WOW::thrall-nagrand"
local LINKED = "|cff9d9d9d|Hitem:6948::::::::80:::::|h[Hearthstone]|h|r look"

local function newRuntime()
  return RestrictionPredicates.Add({
    sendStatusByConversation = {},
    pendingOutgoing = {},
    now = function()
      return 100
    end,
    localProfileId = "me",
    chatApi = {
      SendChatMessage = function() end,
    },
    bnetApi = {},
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10, messageMaxAge = 86400, conversationMaxAge = 86400 }),
  })
end

local function payload()
  return {
    conversationKey = KEY,
    target = "Thrall-Nagrand",
    displayName = "Thrall",
    channel = "WOW",
    text = LINKED,
  }
end

return function()
  local realRecord = Router.RecordPendingSend
  local captured
  Router.RecordPendingSend = function(state, target, text, metadata)
    captured = metadata
    return realRecord(state, target, text, metadata)
  end

  local ok, err = pcall(function()
    -- test_pending_record_keeps_the_rich_text
    captured = nil
    SendHandler.HandleSend(newRuntime(), payload(), function() end)
    assert(type(captured) == "table", "the send is recorded as pending")
    assert(captured.richText == LINKED, "the pending record keeps the text with links, got: " .. tostring(captured.richText))

    -- test_send_does_not_leak_the_rich_text_global
    assert(rawget(_G, "richText") == nil, "the text stays local, got a global: " .. tostring(rawget(_G, "richText")))
  end)

  Router.RecordPendingSend = realRecord
  if not ok then
    error(err, 0)
  end
end
