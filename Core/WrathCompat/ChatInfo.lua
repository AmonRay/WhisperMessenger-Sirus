local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatInfo = {}

function ChatInfo.Create(env)
  local api = {}

  function api.SendChatMessage(text, chatType, _languageID, target)
    local send = env.SendChatMessage
    if type(send) ~= "function" then
      return false
    end
    return send(text, chatType, nil, target)
  end

  function api.SendAddonMessage(prefix, text, channel, target)
    local send = env.SendAddonMessage
    if type(send) ~= "function" then
      return false
    end
    return send(prefix, text, channel, target)
  end

  function api.RegisterAddonMessagePrefix(_prefix)
    return true
  end

  function api.IsAddonMessagePrefixRegistered(_prefix)
    return true
  end

  function api.InChatMessagingLockdown()
    return false
  end

  function api.IsChatLineCensored(_lineID)
    return nil
  end

  function api.GetChannelInfoFromIdentifier(_identifier)
    return nil
  end

  return api
end

function ChatInfo.Install(env)
  env = env or _G
  if type(env.C_ChatInfo) == "table" then
    return false
  end
  env.C_ChatInfo = ChatInfo.Create(env)
  return true
end

ns.WrathCompatChatInfo = ChatInfo

return ChatInfo
