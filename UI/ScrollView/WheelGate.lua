local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")

-- 3.3.5a (Sirus): a list that takes the mouse wheel takes it from every frame
-- under it, so a window opened over the messenger without a wheel of its own
-- (bags, the character sheet) scrolled the messenger behind it instead. There
-- a list takes the wheel only while the cursor is over it and the frame under
-- the cursor belongs to the list's window; a small frame on the list checks
-- that every frame while the list is on screen.
local WheelGate = {}

-- Read at call time so tests can flip FlavorCompat.isWrath335.
function WheelGate.Supported()
  return FlavorCompat.isWrath335 == true
end

-- The list's window: its topmost ancestor below UIParent.
local function windowOf(frame)
  local current = frame
  while type(current.GetParent) == "function" do
    local parent = current:GetParent()
    if parent == nil or parent == rawget(_G, "UIParent") then
      break
    end
    current = parent
  end
  return current
end

local function pointerFocus()
  local getMouseFocus = rawget(_G, "GetMouseFocus")
  if type(getMouseFocus) ~= "function" then
    return nil
  end
  local ok, focus = pcall(getMouseFocus)
  if ok then
    return focus
  end
  return nil
end

-- Forbidden frames (nameplates) throw on any method but IsForbidden and are
-- never ours.
local function isWithin(region, ancestor)
  local current = region
  while current ~= nil do
    if current == ancestor then
      return true
    end
    if type(current.IsForbidden) == "function" and current:IsForbidden() then
      return false
    end
    if type(current.GetParent) ~= "function" then
      return false
    end
    current = current:GetParent()
  end
  return false
end

-- True while the wheel over `scrollFrame` should scroll it.
function WheelGate.Wants(scrollFrame)
  if type(scrollFrame.IsMouseOver) ~= "function" or scrollFrame:IsMouseOver() ~= true then
    return false
  end
  local focus = pointerFocus()
  -- Nothing under the cursor takes the mouse, or only the 3D world does.
  if focus == nil or focus == rawget(_G, "WorldFrame") then
    return true
  end
  return isWithin(focus, windowOf(scrollFrame))
end

-- The gate frame, or nil when the list has no wheel to gate.
function WheelGate.Attach(factory, scrollFrame)
  if type(scrollFrame.EnableMouseWheel) ~= "function" then
    return nil
  end
  local gate = factory.CreateFrame("Frame", nil, scrollFrame)
  if gate == nil or type(gate.SetScript) ~= "function" then
    return nil
  end
  local enabled = nil
  gate:SetScript("OnUpdate", function()
    local wants = WheelGate.Wants(scrollFrame)
    if wants ~= enabled then
      enabled = wants
      scrollFrame:EnableMouseWheel(wants)
    end
  end)
  if type(gate.Show) == "function" then
    gate:Show()
  end
  return gate
end

ns.ScrollViewWheelGate = WheelGate

return WheelGate
