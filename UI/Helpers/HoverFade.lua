local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Short alpha fade for hover highlights. The AnimationGroup is created once
-- per region at attach time (no OnUpdate, no per-hover allocation). Clients
-- or test stubs without CreateAnimationGroup fall back to instant show/hide.
--
-- On a Texture, the colour / vertex alpha and Region:SetAlpha can end up in
-- the same channel, so fading a faint colour "to 1" made hovers solid white.
-- The faded region therefore carries its colour at full alpha (paintColor /
-- paintVertex) and the fade itself runs 0 <-> peak, where peak is the
-- colour's intended alpha. Correct whether or not the channels are shared.
local Base = ns.UIHelpersBase or require("WhisperMessenger.UI.Helpers.Base")

local HoverFade = {}

HoverFade.DURATION = 0.1

-- Returns a controller: set(shown), paintColor(color), paintVertex(color).
function HoverFade.Attach(region)
  local peak = 1
  local visible = region:IsShown()
  local group, anim
  if type(region.CreateAnimationGroup) == "function" then
    group = region:CreateAnimationGroup()
    anim = group:CreateAnimation("Alpha")
    local hasFromTo = type(anim) == "table" and type(anim.SetFromAlpha) == "function" and type(anim.SetToAlpha) == "function"
    if hasFromTo or (type(anim) == "table" and type(anim.SetChange) == "function") then
      anim:SetDuration(HoverFade.DURATION)
      if group.SetToFinalAlpha then
        group:SetToFinalAlpha(true)
      end
      if type(group.SetScript) == "function" then
        group:SetScript("OnFinished", function()
          region:SetAlpha(visible and peak or 0)
          if not visible then
            region:Hide()
          end
        end)
      end
    else
      group, anim = nil, nil
    end
  end

  local controller = {}

  local function isAnimating()
    return group ~= nil and group:IsPlaying()
  end

  -- Writing the colour at alpha 1 can also raise the region alpha to 1. Put
  -- the alpha back: the settled peak when fully shown, otherwise whatever it
  -- was (mid-fade or hidden). Without this, a repaint during a fade (hover
  -- handlers repaint before set()) left the next fade starting at 1.
  local function repaint(paint, color)
    local alpha = region:GetAlpha()
    peak = color[4] or 1
    paint(color[1], color[2], color[3], 1)
    if visible and region:IsShown() and not isAnimating() then
      alpha = peak
    end
    region:SetAlpha(alpha)
  end

  function controller.paintColor(color)
    repaint(function(r, g, b, a)
      Base.paintSolid(region, r, g, b, a)
    end, color)
  end

  function controller.paintVertex(color)
    repaint(function(r, g, b, a)
      if region.SetVertexColor then
        region:SetVertexColor(r, g, b, a)
      end
    end, color)
  end

  function controller.set(shown)
    shown = shown == true
    if shown == visible and (region:IsShown() == shown or isAnimating()) then
      return
    end
    visible = shown

    if group == nil then
      if shown then
        region:SetAlpha(peak)
        region:Show()
      else
        region:Hide()
      end
      return
    end

    local from = region:IsShown() and region:GetAlpha() or 0
    local target = shown and peak or 0
    group:Stop()
    region:SetAlpha(from)
    region:Show()
    if type(anim.SetFromAlpha) == "function" then
      anim:SetFromAlpha(from)
      anim:SetToAlpha(target)
    else
      anim:SetChange(target - from)
    end
    group:Play()
  end

  return controller
end

ns.UIHelpersHoverFade = HoverFade
return HoverFade
