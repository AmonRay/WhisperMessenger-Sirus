local ChatInfo = require("WhisperMessenger.Core.WrathCompat.ChatInfo")

return function()
  local sent = {}
  local addonSent = {}
  local env = {
    SendChatMessage = function(text, chatType, language, target)
      sent[#sent + 1] = { text, chatType, language, target }
      return true
    end,
    SendAddonMessage = function(prefix, text, channel, target)
      addonSent[#addonSent + 1] = { prefix, text, channel, target }
      return true
    end,
  }

  assert(ChatInfo.Install(env) == true, "expected the shim to install")

  env.C_ChatInfo.SendChatMessage("hi", "WHISPER", nil, "Jaina")
  assert(sent[1][1] == "hi" and sent[1][2] == "WHISPER", "expected the chat text and type to pass through")
  assert(sent[1][3] == nil and sent[1][4] == "Jaina", "expected a nil language and the whisper target")

  env.C_ChatInfo.SendChatMessage("trade message", "CHANNEL", nil, 2)
  assert(sent[2][4] == 2, "expected the channel number as the target")

  -- 3.3.5a languages are localized names; retail number IDs are dropped.
  env.C_ChatInfo.SendChatMessage("world", "CHANNEL", "всеобщий", 5)
  assert(sent[3][3] == "всеобщий", "expected a language name to pass through")
  env.C_ChatInfo.SendChatMessage("world", "CHANNEL", 7, 5)
  assert(sent[4][3] == nil, "expected a numeric language ID to be dropped")

  env.C_ChatInfo.SendAddonMessage("WMRX", "payload", "WHISPER", "Jaina")
  assert(addonSent[1][1] == "WMRX" and addonSent[1][3] == "WHISPER", "expected the addon message to pass through")
  assert(addonSent[1][4] == "Jaina", "expected the addon message target")

  assert(env.C_ChatInfo.RegisterAddonMessagePrefix("WMRX") == true, "expected prefix registration to succeed")
  assert(env.C_ChatInfo.InChatMessagingLockdown() == false, "expected no chat lockdown on 3.3.5")
end
