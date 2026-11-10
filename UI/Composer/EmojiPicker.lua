local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local Assets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local Popover = ns.ComposerPopover or require("WhisperMessenger.UI.Composer.Popover")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local RestrictedEmojis = ns.RestrictedEmojis or require("WhisperMessenger.Model.RestrictedEmojis")

local EmojiPicker = {}

-- Gap between the panel edge and the emoji grid, on every side.
local PADDING = 6

function EmojiPicker.Create(factory, parent, anchorFrame, onSelect)
  local popover = Popover.Create(factory, parent, anchorFrame)
  local frame = popover.frame

  local picker = {
    frame = frame,
    buttons = {},
    enabled = true,
  }

  local layout = Assets.GetPickerLayout()
  local iconSize = layout.iconSize
  local buttonSize = layout.buttonSize
  -- A tooltip-border (HUD) panel shifts its cells clear of the border.
  local inset = PickerPopup.BorderInset(frame)
  local pad = PADDING + inset
  local function applyFrameSize(rows)
    frame:SetSize(layout.frameWidth + inset * 2, buttonSize * rows + PADDING * 2 + inset * 2)
  end
  applyFrameSize(layout.rows)

  local function createButton(index, key, texture, coords)
    local slot = index - 1
    local column = slot % layout.columns
    local row = math.floor(slot / layout.columns)
    local button = factory.CreateFrame("Button", nil, frame)
    button:SetSize(buttonSize, buttonSize)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + column * buttonSize, -pad - row * buttonSize)

    local highlight = Hud.IsOn() and NativeArt.AddHighlight(button, PickerPopup.ICON_HIGHLIGHT) or PickerPopup.CreateHoverFill(button)
    highlight:Hide()
    button._highlight = highlight

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetSize(iconSize, iconSize)
    icon:SetTexture(texture)
    icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])

    button:SetScript("OnEnter", function(self)
      if picker.enabled then
        highlight:Show()
        PickerStyles.ShowTooltip(self, key)
      end
    end)
    button:SetScript("OnLeave", function()
      highlight:Hide()
      PickerStyles.HideTooltip()
    end)
    button:SetScript("OnClick", function()
      PickerStyles.HideTooltip()
      if not picker.enabled then
        return
      end
      popover.close()
      onSelect(key)
    end)
    picker.buttons[index] = button
    return button
  end

  for index, key in ipairs(Assets.KEYS) do
    createButton(index, key, Assets.TEXTURE, Assets.GetTexCoords(key))
  end

  -- Personal emojis are appended after the shared set, only for their
  -- owners. Built on first open: the player name isn't reliable at load.
  picker.restrictedKeys = nil
  local function ensureRestrictedButtons()
    if picker.restrictedKeys ~= nil then
      return
    end
    local playerName = RestrictedEmojis.LocalPlayerName()
    if playerName == nil then
      return
    end
    picker.restrictedKeys = RestrictedEmojis.KeysFor(playerName)
    local count = #Assets.KEYS
    for _, key in ipairs(picker.restrictedKeys) do
      count = count + 1
      createButton(count, key, RestrictedEmojis.GetTexture(key), { 0, 1, 0, 1 })
    end
    applyFrameSize(math.max(layout.rows, math.ceil(count / layout.columns)))
  end
  picker.ensureRestrictedButtons = ensureRestrictedButtons

  function picker:open()
    if not self.enabled then
      return false
    end
    ensureRestrictedButtons()
    popover.open()
    return true
  end

  function picker:close()
    popover.close()
  end

  function picker:toggle()
    if frame:IsShown() then
      popover.close()
      return false
    end
    return self:open()
  end

  function picker:setEnabled(enabled)
    self.enabled = enabled == true
    if not self.enabled then
      popover.close()
    end
  end

  function picker:refreshTheme()
    popover.refreshTheme()
    local highlightColor = PickerStyles.HighlightColor(PickerStyles.HOVER_ALPHA)
    for _, button in ipairs(self.buttons) do
      PickerStyles.ApplyColor(button._highlight, highlightColor)
    end
  end

  return picker
end

ns.ComposerEmojiPicker = EmojiPicker
return EmojiPicker
