local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Timer = {}

local timers = {}

local function fire(timer)
  if timer.cancelled then
    return
  end
  local ok, err = pcall(timer.callback)
  if not ok then
    local handler = _G.geterrorhandler
    if type(handler) == "function" then
      pcall(handler(), err)
    end
  end
end

function Timer.Advance(elapsed)
  elapsed = tonumber(elapsed) or 0
  for i = #timers, 1, -1 do
    local timer = timers[i]
    timer.remaining = timer.remaining - elapsed
    if timer.remaining <= 0 then
      table.remove(timers, i)
      fire(timer)
    end
  end
end

function Timer.Pending()
  return #timers
end

function Timer.Reset()
  for i = 1, #timers do
    timers[i].cancelled = true
  end
  timers = {}
end

function Timer.Create(env)
  local driver
  local function ensureDriver()
    if driver ~= nil then
      return driver
    end
    if type(env.CreateFrame) ~= "function" then
      return nil
    end
    driver = env.CreateFrame("Frame", "WhisperMessengerWrathTimer")
    if driver == nil then
      return nil
    end
    if driver.SetScript ~= nil then
      driver:SetScript("OnUpdate", function(_, elapsed)
        Timer.Advance(elapsed)
        if #timers == 0 and driver.Hide ~= nil then
          driver:Hide()
        end
      end)
    end
    if driver.Hide ~= nil then
      driver:Hide()
    end
    return driver
  end

  local function schedule(delay, callback)
    if type(callback) ~= "function" then
      return nil
    end
    local timer = {
      remaining = math.max(0, tonumber(delay) or 0),
      callback = callback,
      cancelled = false,
    }
    function timer:Cancel()
      self.cancelled = true
    end
    timers[#timers + 1] = timer
    local frame = ensureDriver()
    if frame ~= nil and frame.Show ~= nil then
      frame:Show()
    end
    return timer
  end

  local function newTicker(interval, callback, iterations)
    local ticker = { cancelled = false, remaining = iterations }
    function ticker:Cancel()
      self.cancelled = true
    end
    local function tick()
      if ticker.cancelled then
        return
      end
      local ok, err = pcall(callback)
      if not ok then
        local handler = _G.geterrorhandler
        if type(handler) == "function" then
          pcall(handler(), err)
        end
      end
      if ticker.cancelled then
        return
      end
      if ticker.remaining ~= nil then
        ticker.remaining = ticker.remaining - 1
      end
      if ticker.remaining == nil or ticker.remaining > 0 then
        schedule(interval, tick)
      end
    end
    schedule(interval, tick)
    return ticker
  end

  return {
    After = function(delay, callback)
      schedule(delay, callback)
    end,
    NewTimer = schedule,
    NewTicker = newTicker,
  }
end

local sharedScheduler

local function getScheduler(env)
  if sharedScheduler == nil then
    sharedScheduler = Timer.Create(env or _G)
  end
  return sharedScheduler
end

function Timer.IsWrath(env)
  env = env or _G
  local compat = ns.WrathCompat
  if type(compat) == "table" and type(compat.IsWrath335) == "function" then
    return compat.IsWrath335(env) == true
  end
  if env.WOW_PROJECT_ID ~= nil or type(env.GetBuildInfo) ~= "function" then
    return false
  end
  local ok, _, _, _, tocVersion = pcall(env.GetBuildInfo)
  return ok and type(tocVersion) == "number" and tocVersion <= 30300
end

function Timer.Schedule(delay, callback, env)
  env = env or _G
  if type(callback) ~= "function" then
    return false
  end
  if Timer.IsWrath(env) then
    if sharedScheduler == nil then
      sharedScheduler = Timer.Create(env)
    end
    if sharedScheduler == nil then
      return false
    end
    sharedScheduler.After(delay, callback)
    return true
  end

  local clientTimer = env.C_Timer
  if type(clientTimer) == "table" and type(clientTimer.After) == "function" then
    clientTimer.After(delay, callback)
    return true
  end

  return false
end

function Timer.AfterOn(clientTimer, delay, callback)
  if Timer.IsWrath(_G) then
    return Timer.Schedule(delay, callback)
  end
  if type(clientTimer) == "table" and type(clientTimer.After) == "function" then
    clientTimer.After(delay, callback)
    return true
  end
  return false
end

function Timer.TimerOn(clientTimer, delay, callback)
  if Timer.IsWrath(_G) then
    local scheduler = getScheduler()
    return scheduler and scheduler.NewTimer(delay, callback)
  end
  if type(clientTimer) == "table" and type(clientTimer.NewTimer) == "function" then
    return clientTimer.NewTimer(delay, callback)
  end
  return nil
end

function Timer.TickerOn(clientTimer, interval, callback, iterations)
  if Timer.IsWrath(_G) then
    local scheduler = getScheduler()
    return scheduler and scheduler.NewTicker(interval, callback, iterations)
  end
  if type(clientTimer) == "table" and type(clientTimer.NewTicker) == "function" then
    return clientTimer.NewTicker(interval, callback, iterations)
  end
  return nil
end

function Timer.Install(env)
  env = env or _G
  if type(env.C_Timer) == "table" and type(env.C_Timer.After) == "function" then
    return false
  end
  env.C_Timer = Timer.Create(env)
  return true
end

ns.WrathCompatTimer = Timer

return Timer
