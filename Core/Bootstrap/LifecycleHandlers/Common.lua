local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or (type(require) == "function" and require("WhisperMessenger.Locale.Localization")) or nil
local function L(key)
  return Localization and Localization.Text(key) or key
end
local QueuedSends = ns.BootstrapQueuedSends or require("WhisperMessenger.Core.Bootstrap.QueuedSends")
local WrathTimer = ns.WrathCompatTimer or (type(require) == "function" and require("WhisperMessenger.Core.WrathCompat.Timer"))
local Common = {}

Common.COMPETITIVE_NOTICE = "Messages are paused in competitive content and will resume when you leave."

function Common.refreshRuntimeWindow(Bootstrap)
  if Bootstrap.runtime and Bootstrap.runtime.refreshWindow then
    Bootstrap.runtime.refreshWindow()
  end
end

function Common.scheduleAfter(delay, callback)
  if type(WrathTimer) == "table" and type(WrathTimer.Schedule) == "function" then
    return WrathTimer.Schedule(delay, callback) == true
  end

  return false
end

function Common.notifyCompetitiveState(Bootstrap)
  local runtime = Bootstrap.runtime
  local chatLocked = runtime ~= nil and type(runtime.isChatLocked) == "function" and runtime.isChatLocked()
  local isActive = Bootstrap._inCompetitiveContent == true
    or Bootstrap._inMythicContent == true
    or Bootstrap._inEncounter == true
    or chatLocked == true

  -- Set/clear the messaging notice on the runtime (visible banner in messenger).
  -- Skip if mythic suspend already owns the notice (its own suspend/resume manages it).
  if Bootstrap.runtime and not Bootstrap._inMythicContent then
    if isActive then
      Bootstrap.runtime.messagingNotice = L(Common.COMPETITIVE_NOTICE)
    else
      Bootstrap.runtime.messagingNotice = nil
    end
  end

  if type(Bootstrap.onCompetitiveStateChanged) == "function" then
    Bootstrap.onCompetitiveStateChanged(isActive)
  end

  if Bootstrap.runtime then
    QueuedSends.OnLockStateChanged(Bootstrap.runtime)
  end
end

ns.BootstrapLifecycleHandlersCommon = Common
return Common
