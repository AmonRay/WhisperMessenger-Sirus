local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor

-- White radial texture, transparent centre fading up to the host's inner
-- edge and back to zero at the rim. Pinned to the host's edges and never
-- scaled, so the glow stays inside the host (no outer halo). Shared by the widget,
-- minimap icon and What's New button.
local INNER_GLOW_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\inner-glow.tga"
local PULSE_FADE_IN = 0.5
local PULSE_PEAK_HOLD = 0.25 -- keeps the original 1.75s cycle (0.75s + 1.0s)
local PULSE_FADE_OUT = 1.0
local PULSE_PEAK_ALPHA = 0.8
local PULSE_CYCLE = PULSE_FADE_IN + PULSE_PEAK_HOLD + PULSE_FADE_OUT

local PulseGlow = {}

PulseGlow.TEXTURE = INNER_GLOW_TEXTURE

local function pulseAlphaAt(elapsed)
  local t = elapsed % PULSE_CYCLE
  if t < PULSE_FADE_IN then
    return PULSE_PEAK_ALPHA * (t / PULSE_FADE_IN)
  end
  t = t - PULSE_FADE_IN
  if t < PULSE_PEAK_HOLD then
    return PULSE_PEAK_ALPHA
  end
  t = t - PULSE_PEAK_HOLD
  return PULSE_PEAK_ALPHA * (1 - t / PULSE_FADE_OUT)
end

function PulseGlow.Create(factory, frame, options)
  options = options or {}
  local theme = options.theme or Theme
  local accent = options.accent or theme.COLORS.accent
  local glowFrame = factory.CreateFrame("Frame", nil, frame)
  -- Follows the host's size, including hosts sized after Create (title-bar buttons) and widget resizes.
  glowFrame:SetAllPoints(frame)
  glowFrame:SetAlpha(0)
  if type(frame.GetFrameLevel) == "function" then
    glowFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
  end

  local glowTexture = glowFrame:CreateTexture(nil, "ARTWORK")
  glowTexture:SetAllPoints(glowFrame)
  glowTexture:SetTexture(INNER_GLOW_TEXTURE)
  if glowTexture.SetBlendMode then
    glowTexture:SetBlendMode("ADD")
  end
  applyVertexColor(glowTexture, accent)
  glowFrame:Hide()

  local pulseAnim = nil
  if type(glowFrame.CreateAnimationGroup) == "function" then
    local ag = glowFrame:CreateAnimationGroup()
    if type(ag) == "table" and type(ag.CreateAnimation) == "function" then
      ag:SetLooping("REPEAT")

      local fadeIn = ag:CreateAnimation("Alpha")
      local fadeOut = ag:CreateAnimation("Alpha")
      if type(fadeIn) == "table" and type(fadeIn.SetFromAlpha) == "function" and type(fadeOut) == "table" then
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(PULSE_PEAK_ALPHA)
        fadeIn:SetDuration(PULSE_FADE_IN)
        fadeIn:SetEndDelay(PULSE_PEAK_HOLD)
        fadeIn:SetOrder(1)

        fadeOut:SetFromAlpha(PULSE_PEAK_ALPHA)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(PULSE_FADE_OUT)
        fadeOut:SetOrder(2)

        if ag.SetScript then
          ag:SetScript("OnPlay", function()
            glowFrame:Show()
            glowFrame:SetAlpha(0)
          end)
          ag:SetScript("OnStop", function()
            glowFrame:SetAlpha(0)
            glowFrame:Hide()
          end)
        end

        pulseAnim = ag
      end
    end
  end

  local pulseElapsed = 0
  local fallbackActive = false

  local function startFallbackPulse()
    if fallbackActive then
      return
    end
    fallbackActive = true
    pulseElapsed = 0
    glowFrame:Show()
    glowFrame:SetAlpha(0)
    glowFrame:SetScript("OnUpdate", function(_, elapsed)
      pulseElapsed = pulseElapsed + (tonumber(elapsed) or 0)
      glowFrame:SetAlpha(pulseAlphaAt(pulseElapsed))
    end)
  end

  local function stopFallbackPulse()
    if not fallbackActive then
      return
    end
    fallbackActive = false
    glowFrame:SetScript("OnUpdate", nil)
    glowFrame:SetAlpha(0)
    glowFrame:Hide()
  end

  local pulseActive = false
  local function startPulse()
    if pulseAnim then
      if not pulseActive then
        pulseActive = true
        pulseAnim:Play()
      end
      return
    end
    startFallbackPulse()
  end

  local function stopPulse()
    if pulseAnim then
      if pulseActive then
        pulseActive = false
        pulseAnim:Stop()
      end
      return
    end
    stopFallbackPulse()
  end

  local function applyTheme(activeTheme)
    activeTheme = activeTheme or theme
    if glowTexture and glowTexture.SetVertexColor then
      applyVertexColor(glowTexture, activeTheme.COLORS.accent)
    end
  end

  return {
    glowFrame = glowFrame,
    glowTexture = glowTexture,
    animation = pulseAnim,
    start = startPulse,
    stop = stopPulse,
    applyTheme = applyTheme,
  }
end

ns.ToggleIconPulseGlow = PulseGlow

return PulseGlow
