local Timer = require("WhisperMessenger.Core.WrathCompat.Timer")

return function()
  Timer.Reset()

  local env = {}
  assert(Timer.Install(env) == true, "expected the shim to install")
  assert(type(env.C_Timer) == "table", "expected C_Timer")
  assert(type(env.C_Timer.After) == "function", "expected C_Timer.After")
  assert(type(env.C_Timer.NewTimer) == "function", "expected C_Timer.NewTimer")

  local fired = 0
  env.C_Timer.After(0.5, function()
    fired = fired + 1
  end)
  Timer.Advance(0.4)
  assert(fired == 0, "expected the callback to wait for its delay")
  Timer.Advance(0.1)
  assert(fired == 1, "expected the callback to run once the delay passed")
  Timer.Advance(10)
  assert(fired == 1, "expected the callback to run only once")

  local cancelled = false
  local timer = env.C_Timer.NewTimer(1, function()
    cancelled = true
  end)
  timer:Cancel()
  Timer.Advance(2)
  assert(cancelled == false, "expected a cancelled timer not to fire")

  Timer.Reset()
  -- test_schedule_uses_own_driver_on_wrath
  do
    Timer.Reset()
    local clientCalls = 0
    local wrathEnv = {
      GetBuildInfo = function()
        return "3.3.5", "12340", "Nov 8 2026", 30300
      end,
      C_Timer = {
        After = function()
          clientCalls = clientCalls + 1
        end,
      },
      CreateFrame = function()
        return { SetScript = function() end, Hide = function() end, Show = function() end }
      end,
    }
    local fired = 0
    assert(Timer.Schedule(0.5, function()
      fired = fired + 1
    end, wrathEnv) == true, "expected the delay to be scheduled")
    assert(clientCalls == 0, "the client timer must not be used on 3.3.5a")
    Timer.Advance(0.5)
    assert(fired == 1, "expected our own driver to run the callback")
    Timer.Reset()
  end

  -- test_schedule_uses_client_timer_elsewhere
  do
    local scheduled
    local modernEnv = {
      WOW_PROJECT_ID = 1,
      C_Timer = {
        After = function(delay, callback)
          scheduled = { delay = delay, callback = callback }
        end,
      },
    }
    assert(Timer.Schedule(2, function() end, modernEnv) == true, "expected the delay to be scheduled")
    assert(scheduled ~= nil and scheduled.delay == 2, "expected the client timer to receive the delay")
  end
  -- test_ticker_fires_each_interval_and_stops_after_iterations
  do
    Timer.Reset()
    local ticks = 0
    local ticker = Timer.Create({
      CreateFrame = function()
        return { SetScript = function() end, Hide = function() end, Show = function() end }
      end,
    }).NewTicker(0.25, function()
      ticks = ticks + 1
    end, 2)
    Timer.Advance(0.25)
    assert(ticks == 1, "expected the first tick after one interval, got " .. ticks)
    Timer.Advance(0.25)
    assert(ticks == 2, "expected the second tick, got " .. ticks)
    Timer.Advance(1)
    assert(ticks == 2, "expected the ticker to stop after its iterations, got " .. ticks)
    assert(type(ticker.Cancel) == "function", "expected a cancellable ticker")
    Timer.Reset()
  end

  -- test_after_on_uses_client_timer_off_wrath
  do
    local scheduled
    local clientTimer = {
      After = function(delay, callback)
        scheduled = { delay = delay, callback = callback }
      end,
    }
    local saved = rawget(_G, "GetBuildInfo")
    rawset(_G, "GetBuildInfo", nil)
    assert(Timer.AfterOn(clientTimer, 1.5, function() end) == true, "expected the client timer to be used")
    rawset(_G, "GetBuildInfo", saved)
    assert(scheduled ~= nil and scheduled.delay == 1.5, "expected the client timer to receive the delay")
  end

  -- test_after_on_does_not_touch_the_wrath_client_timer
  do
    Timer.Reset()
    local clientCalls = 0
    local clientTimer = {
      After = function()
        clientCalls = clientCalls + 1
      end,
    }
    local saved = rawget(_G, "GetBuildInfo")
    rawset(_G, "GetBuildInfo", function()
      return "3.3.5", "12340", "Nov 8 2026", 30300
    end)
    assert(Timer.AfterOn(clientTimer, 0.1, function() end) == true, "expected the delay to be scheduled")
    rawset(_G, "GetBuildInfo", saved)
    assert(clientCalls == 0, "the client timer must not be used on 3.3.5a")
    Timer.Reset()
  end
end
