local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Social = {}

local function number(value)
  return type(value) == "number" and value or nil
end

local function friendEntry(env, index)
  local getInfo = env.GetFriendInfo
  if type(getInfo) ~= "function" or type(index) ~= "number" then
    return nil
  end
  local name, level, className, area, connected, status, note = getInfo(index)
  if name == nil then
    return nil
  end
  return {
    name = name,
    level = level,
    className = className,
    area = area,
    connected = connected == 1 or connected == true,
    status = status,
    note = note,
  }
end

local function friendIndexByName(env, name)
  local total = number(env.GetNumFriends and env.GetNumFriends()) or 0
  local shortName = name
  local amb = env.Ambiguate
  if type(amb) == "function" then
    local ok, value = pcall(amb, name, "none")
    if ok and type(value) == "string" then
      shortName = value
    end
  end
  for i = 1, total do
    local friendName = env.GetFriendInfo and env.GetFriendInfo(i)
    if friendName == name or friendName == shortName then
      return i
    end
  end
  return nil
end

function Social.CreateFriendList(env)
  local api = {}

  function api.AddFriend(name)
    if type(env.AddFriend) == "function" then
      return env.AddFriend(name)
    end
  end

  function api.RemoveFriend(name)
    if type(env.RemoveFriend) == "function" then
      return env.RemoveFriend(name)
    end
  end

  function api.GetNumFriends()
    if type(env.GetNumFriends) == "function" then
      return env.GetNumFriends() or 0
    end
    return 0
  end

  function api.GetFriendInfo(key)
    if type(key) == "string" then
      return friendEntry(env, friendIndexByName(env, key))
    end
    return friendEntry(env, key)
  end

  function api.IsFriend(_guid)
    return false
  end

  function api.SendWho(filter)
    if type(env.SendWho) == "function" then
      return env.SendWho(filter)
    end
  end

  function api.SetWhoToUi(enabled)
    local setter = env.SetWhoToUI
    if type(setter) == "function" then
      return setter(enabled)
    end
  end

  function api.GetWhoToUi()
    local getter = env.GetWhoToUI
    if type(getter) == "function" then
      return getter()
    end
    return false
  end

  return api
end

local function bnetEntry(env, index)
  local getInfo = env.BNGetFriendInfo
  if type(getInfo) ~= "function" then
    return nil
  end
  local values = { pcall(getInfo, index) }
  if not values[1] then
    return nil
  end

  local entry = { friendIndex = index }
  for i = 2, #values do
    local value = values[i]
    if type(value) == "string" and value ~= "" then
      if string.find(value, "#", 1, true) then
        entry.battleTag = entry.battleTag or value
      elseif entry.accountName == nil then
        entry.accountName = value
      elseif entry.gameAccountInfo == nil then
        entry.gameAccountInfo = { characterName = value }
      end
    elseif type(value) == "number" and value > 0 then
      entry.presenceID = entry.presenceID or value
      if entry.bnetAccountID == nil or value > entry.bnetAccountID then
        entry.bnetAccountID = value
      end
    end
  end
  return entry
end

function Social.CreateBattleNet(env)
  local api = {}

  function api.GetNumFriends()
    if type(env.BNGetNumFriends) == "function" then
      return env.BNGetNumFriends() or 0
    end
    return 0
  end

  function api.GetFriendAccountInfo(index)
    return bnetEntry(env, index)
  end

  function api.GetAccountInfoByID(bnetAccountID)
    local total = api.GetNumFriends()
    for i = 1, total do
      local entry = bnetEntry(env, i)
      if entry ~= nil and entry.bnetAccountID == bnetAccountID then
        return entry
      end
    end
    return nil
  end

  function api.GetAccountInfoByGUID(guid)
    local total = api.GetNumFriends()
    for i = 1, total do
      local entry = bnetEntry(env, i)
      local gameAccount = entry ~= nil and entry.gameAccountInfo or nil
      if gameAccount ~= nil and gameAccount.playerGuid == guid then
        return entry
      end
    end
    return nil
  end

  function api.SendWhisper(bnetAccountID, text)
    if type(env.BNSendWhisper) == "function" then
      return env.BNSendWhisper(bnetAccountID, text)
    end
  end

  return api
end

local function calendarTime(env)
  local getServerTime = env.GetServerTime
  if type(getServerTime) ~= "function" then
    return nil
  end
  local ok, serverTime = pcall(getServerTime)
  if not ok or type(serverTime) ~= "number" then
    return nil
  end
  local dateFn = env.date
  if type(dateFn) ~= "function" then
    return nil
  end
  local okDate, t = pcall(dateFn, "*t", serverTime)
  if not okDate or type(t) ~= "table" then
    return nil
  end
  return {
    year = t.year,
    month = t.month,
    monthDay = t.day,
    hour = t.hour,
    minute = t.min,
    second = t.sec,
    weekday = t.wday,
  }
end

function Social.Install(env)
  env = env or _G
  if type(env.C_FriendList) ~= "table" then
    env.C_FriendList = Social.CreateFriendList(env)
  end
  if type(env.C_BattleNet) ~= "table" then
    env.C_BattleNet = Social.CreateBattleNet(env)
  end
  if type(env.C_GuildInfo) ~= "table" then
    env.C_GuildInfo = {
      GuildRoster = function()
        if type(env.GuildRoster) == "function" then
          return env.GuildRoster()
        end
      end,
    }
  end
  if type(env.C_AddOns) ~= "table" and type(env.GetAddOnInfo) == "function" then
    env.C_AddOns = { GetAddOnInfo = env.GetAddOnInfo }
  end
  if type(env.C_DateAndTime) ~= "table" then
    env.C_DateAndTime = {
      GetCurrentCalendarTime = function()
        return calendarTime(env)
      end,
    }
  end
  return true
end

ns.WrathCompatSocial = Social

return Social
