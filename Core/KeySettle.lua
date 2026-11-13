local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WrathTimer = ns.WrathCompatTimer or require("WhisperMessenger.Core.WrathCompat.Timer")

local KeySettle = {}

-- A key press runs its action on key-down; the key's character event reaches
-- whatever has focus during the next frame's input phase, after that frame's
-- C_Timer callbacks. Waiting one frame plus a short delay (What The Whisper
-- uses the same 0.05s) keeps the composer unfocused until the letter is gone.
KeySettle.SETTLE_SECONDS = 0.05

function KeySettle.Schedule(fn)
  local timer = _G.C_Timer
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    fn()
    return
  end
  WrathTimer.AfterOn(timer, 0, function()
    WrathTimer.AfterOn(timer, KeySettle.SETTLE_SECONDS, fn)
  end)
end

-- Keep the upstream public name while internal callers use a distinct name
-- so the timer-boundary check can distinguish this helper from client timers.
KeySettle.After = KeySettle.Schedule

ns.KeySettle = KeySettle

return KeySettle
