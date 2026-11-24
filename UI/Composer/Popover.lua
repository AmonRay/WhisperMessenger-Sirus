local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")

-- Themed panel that pops up above a composer launcher button and closes on a
-- click outside itself or its launcher. Shared by the emoji and quick-reply
-- pickers.
local Popover = {}

function Popover.Create(factory, parent, anchorFrame)
  local frame = PickerPopup.CreatePanel(factory, parent, nil, "FULLSCREEN_DIALOG")

  local popover = { frame = frame }

  function popover.close()
    frame:Hide()
  end

  function popover.refreshTheme()
    PickerStyles.ApplyPanelTheme(frame, frame._border)
  end

  function popover.open()
    popover.refreshTheme()
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, 4)
    -- On 3.3.5a the transcript's bubbles live on deeper frames than the
    -- composer, so a panel parented to the composer can end up under them:
    -- the emoji or quick-reply rows over the messages stop taking clicks.
    if frame.SetFrameLevel and type(anchorFrame.GetFrameLevel) == "function" then
      frame:SetFrameLevel((anchorFrame:GetFrameLevel() or 1) + 100)
    end
    PickerPopup.ArmDismiss(frame)
    frame:Show()
  end

  frame:SetScript("OnEvent", function(self, event)
    PickerPopup.HandleEvent(self, event, popover.close, anchorFrame)
  end)
  frame:SetScript("OnHide", function(self)
    PickerPopup.Disarm(self)
    PickerStyles.HideTooltip()
  end)

  popover.refreshTheme()
  return popover
end

ns.ComposerPopover = Popover
return Popover
