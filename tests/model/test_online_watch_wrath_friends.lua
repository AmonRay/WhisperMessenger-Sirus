local OnlineWatch = require("WhisperMessenger.Model.OnlineWatch")
local Social = require("WhisperMessenger.Core.WrathCompat.Social")

-- 3.3.5a has no C_FriendList: the friends list is the global GetFriendInfo.
-- The compat adapter has to turn that into the same shape the addon reads, or
-- a friend shown online by the game looks offline in the messenger.

return function()
  local env = {
    GetNumFriends = function()
      return 1
    end,
    GetFriendInfo = function(index)
      if index ~= 1 then
        return nil
      end
      return "Линдаа", 80, "MAGE", "Остров Форбс", 1, "", ""
    end,
    Ambiguate = function(name)
      return name
    end,
  }

  -- Another realm's player keeps the realm suffix under Ambiguate, while the
  -- friends list still stores just the character name.
  local api = Social.CreateFriendList(env)
  local info = api.GetFriendInfo("Линдаа")
  assert(type(info) == "table" and info.connected == true, "the legacy friend entry must report the online flag")

  local runtime = { friendListApi = api }
  local online = OnlineWatch.ReadOnline(runtime, { channel = "WOW", displayName = "Линдаа-Остров Форбс" })
  assert(online == true, "a named friend with a realm suffix must resolve through the legacy list")
end
