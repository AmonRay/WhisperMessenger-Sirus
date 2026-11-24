local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local OutgoingDelivery = ns.OutgoingDelivery or require("WhisperMessenger.Model.OutgoingDelivery")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ChatPrint = ns.ChatPrint or require("WhisperMessenger.Util.ChatPrint")

-- Messages written during chat lockdown wait in history as "queued". They
-- are only ever sent by a Send now click after the lock lifts.
local QueuedSends = {}

local ONE_WAITING_KEY = "1 queued message is waiting — open the messenger to send or discard."
local MANY_WAITING_KEY = "%d queued messages are waiting — open the messenger to send or discard."

function QueuedSends.IsChatLocked(runtime)
  -- Sirus runtimes keep the older shape without the restriction predicates.
  if type(runtime.isMythicLockdown) == "function" and runtime.isMythicLockdown() then
    return true
  end
  return type(runtime.isCompetitiveContent) == "function" and runtime.isCompetitiveContent() == true
end

-- Called on every lock-state notification; announces once per lift.
function QueuedSends.OnLockStateChanged(runtime)
  local locked = QueuedSends.IsChatLocked(runtime)
  local wasLocked = runtime.queuedSendsLocked
  runtime.queuedSendsLocked = locked
  if wasLocked ~= true or locked then
    return false
  end
  local count = OutgoingDelivery.CountQueued(runtime.store)
  if count == 0 then
    return false
  end
  ChatPrint.Print(count == 1 and Localization.Text(ONE_WAITING_KEY) or string.format(Localization.Text(MANY_WAITING_KEY), count))
  if type(runtime.refreshWindow) == "function" then
    runtime.refreshWindow()
  end
  return true
end

local function payloadFor(conversationKey, message)
  return {
    conversationKey = conversationKey,
    target = message.target or message.playerName,
    displayName = message.playerName or message.target,
    channel = message.channel,
    bnetAccountID = message.bnetAccountID,
    guid = message.guid,
    gameAccountName = message.gameAccountName,
    text = message.text,
    replyTo = message.replyTo,
  }
end

-- Sends an unsent message's original text to its original target.
local function resend(runtime, conversationKey, message, sendHandler, refreshWindow)
  local payload = payloadFor(conversationKey, message)
  local sent = sendHandler.HandleSend(runtime, payload, refreshWindow)
  -- A new failed record replaces this one; otherwise it stays queued.
  if sent or payload.deliveryRecorded then
    OutgoingDelivery.Remove(runtime.store, conversationKey, message)
    refreshWindow()
  end
  return sent == true
end

local function sendNow(runtime, conversationKey, message, sendHandler, refreshWindow)
  if message.delivery ~= "queued" or QueuedSends.IsChatLocked(runtime) or OutgoingDelivery.IsOtherCharacters(message) then
    refreshWindow()
    return false
  end
  return resend(runtime, conversationKey, message, sendHandler, refreshWindow)
end

-- Sends a sent message's text again as a new message; the original stays in
-- history. `send` is the window's send path (group routing included).
function QueuedSends.Repeat(_runtime, conversationKey, message, send)
  if type(message) ~= "table" or conversationKey == nil or type(send) ~= "function" then
    return false
  end
  if type(message.text) ~= "string" or message.text == "" then
    return false
  end
  return send(payloadFor(conversationKey, message)) == true
end

-- action: "send_now" | "discard" | "retry". Retry sends a failed message
-- again; if the player is still offline it comes back as a new failed record.
function QueuedSends.HandleAction(runtime, conversationKey, message, action, sendHandler, refreshWindow)
  if type(message) ~= "table" or conversationKey == nil then
    return false
  end
  if action == "send_now" then
    return sendNow(runtime, conversationKey, message, sendHandler, refreshWindow)
  end
  if action == "discard" then
    local removed = OutgoingDelivery.Remove(runtime.store, conversationKey, message)
    refreshWindow()
    return removed
  end
  if action == "retry" and message.delivery == "failed" then
    return resend(runtime, conversationKey, message, sendHandler, refreshWindow)
  end
  return false
end

ns.BootstrapQueuedSends = QueuedSends
return QueuedSends
