local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local SuspendController = require("WhisperMessenger.Core.Bootstrap.MythicSuspendController")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local ContentDetector = require("WhisperMessenger.Core.ContentDetector")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")

local deps = {
  getContentDetector = function()
    return ContentDetector
  end,
  getPresenceCache = function()
    return nil
  end,
}

local function makeRuntime(value)
  local runtime = {
    accountState = { settings = { blockChatInInstances = value } },
    restrictedActions = RestrictedActions.New(),
    store = { conversations = {} },
  }
  local bootstrap = { runtime = runtime }
  local visible = true
  local calls = { unregister = 0, register = 0 }
  SuspendController.Attach(runtime, {
    Bootstrap = bootstrap,
    isWindowVisible = function()
      return visible
    end,
    setWindowVisible = function(shown)
      visible = shown
    end,
    getEventBridge = function()
      return nil
    end,
  })
  bootstrap.unregisterChatFilters = function()
    calls.unregister = calls.unregister + 1
  end
  bootstrap.syncChatFilters = function()
    calls.register = calls.register + 1
  end
  return bootstrap, runtime, calls, function()
    return visible
  end
end

local function enter(bootstrap)
  LifecycleHandlers.Handle(bootstrap, "PLAYER_ENTERING_WORLD", deps)
end

local function assertUnlocked(runtime, visible, context)
  assert(runtime.messagingNotice == nil, context .. ": no addon pause notice may remain")
  assert(_G._wmSuspended ~= true, context .. ": link hooks must not remain suspended")
  assert(visible(), context .. ": messenger must not be forcibly hidden")
end

return function()
  local saved = {
    instance = rawget(_G, "GetInstanceInfo"),
    timer = _G.C_Timer,
    suspended = _G._wmSuspended,
    restricted = _G.C_RestrictedActions,
    chat = _G.C_ChatInfo,
    mythic = FlavorCompat.hasMythicPlus,
  }
  local ok, err = pcall(function()
    -- No real server/API chat lock: these cases exercise addon-only policy.
    _G.C_RestrictedActions = nil
    _G.C_ChatInfo = nil
    _G.C_Timer = { After = function() end }
    FlavorCompat.hasMythicPlus = true
    local zone = { "Город", "none", 0 }
    _G.GetInstanceInfo = function()
      return unpack(zone)
    end
    local activities = {
      { "М+", "party", 8 },
      { "БГ", "pvp", 1 },
      { "Арена", "arena", 1 },
    }

    -- test_false_and_nil_never_suspend_in_any_requested_activity
    for _, setting in ipairs({ { value = false, label = "false" }, { label = "nil" } }) do
      for _, activity in ipairs(activities) do
        _G._wmSuspended = nil
        zone = activity
        local bootstrap, runtime, calls, visible = makeRuntime(setting.value)
        enter(bootstrap)
        if activity[2] == "party" then
          LifecycleHandlers.Handle(bootstrap, "CHALLENGE_MODE_START", deps)
        end
        local context = activity[1] .. "/" .. setting.label
        assertUnlocked(runtime, visible, context)
        assert(calls.unregister == 0, context .. ": live chat filters must not be removed by suspend")
      end
    end

    -- test_true_enables_pause_and_disabling_then_reconciling_clears_it
    -- PLAYER_ENTERING_WORLD is the existing public reconciliation event;
    -- immediate SettingsHandler wiring is a separate integration obligation.
    for _, activity in ipairs(activities) do
      _G._wmSuspended = nil
      zone = activity
      local bootstrap, runtime, _, visible = makeRuntime(true)
      enter(bootstrap)
      if activity[2] == "party" then
        LifecycleHandlers.Handle(bootstrap, "CHALLENGE_MODE_START", deps)
      end
      assert(runtime.messagingNotice ~= nil, activity[1] .. ": true must enable the addon restriction")
      runtime.accountState.settings.blockChatInInstances = false
      enter(bootstrap)
      assertUnlocked(runtime, visible, activity[1] .. "/disabled in place")
      zone = { "Город", "none", 0 }
      enter(bootstrap)
      assertUnlocked(runtime, visible, activity[1] .. "/left after disabling")
    end

    -- test_leaving_with_policy_enabled_restores_messenger
    for _, activity in ipairs(activities) do
      _G._wmSuspended = nil
      zone = activity
      local bootstrap, runtime, _, visible = makeRuntime(true)
      enter(bootstrap)
      assert(runtime.messagingNotice ~= nil, "precondition: activity must pause messaging")
      zone = { "Город", "none", 0 }
      enter(bootstrap)
      assertUnlocked(runtime, visible, activity[1] .. "/left with true")
    end
  end)
  rawset(_G, "GetInstanceInfo", saved.instance)
  _G.C_Timer = saved.timer
  _G.C_RestrictedActions = saved.restricted
  _G.C_ChatInfo = saved.chat
  _G._wmSuspended = saved.suspended
  FlavorCompat.hasMythicPlus = saved.mythic
  assert(ok, err)
end
