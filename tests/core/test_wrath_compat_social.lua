local Social = require("WhisperMessenger.Core.WrathCompat.Social")

return function()
  local friends = {
    { "Arthas", 80, "Warrior", "Icecrown", 1, "<GM>", "note" },
    { "Jaina", 80, "Mage", "Dalaran", nil, "", "" },
  }
  local env = {
    GetNumFriends = function()
      return #friends
    end,
    GetFriendInfo = function(index)
      local friend = friends[index]
      if friend == nil then
        return nil
      end
      return friend[1], friend[2], friend[3], friend[4], friend[5], friend[6], friend[7]
    end,
    GetServerTime = function()
      return 1234567890
    end,
    date = function(_format, timestamp)
      return os.date("*t", timestamp)
    end,
  }

  Social.Install(env)

  local byName = env.C_FriendList.GetFriendInfo("Arthas")
  assert(byName ~= nil, "expected a friend entry by name")
  assert(byName.connected == true, "expected the connected flag as a boolean")
  assert(byName.className == "Warrior", "expected the class name")

  local offline = env.C_FriendList.GetFriendInfo("Jaina")
  assert(offline.connected == false, "expected a disconnected friend")

  assert(env.C_FriendList.GetFriendInfo("Nobody") == nil, "expected nil for an unknown friend")
  assert(env.C_FriendList.GetNumFriends() == 2, "expected the friend count")

  local calendar = env.C_DateAndTime.GetCurrentCalendarTime()
  assert(type(calendar) == "table", "expected server calendar time")
  assert(calendar.monthDay ~= nil and calendar.minute ~= nil, "expected calendar fields for the time format")
end
