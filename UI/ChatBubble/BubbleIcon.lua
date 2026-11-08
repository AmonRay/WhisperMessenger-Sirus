local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local PlayerMenuClick = ns.ChatBubblePlayerMenuClick or require("WhisperMessenger.UI.ChatBubble.PlayerMenuClick")

local BubbleIcon = {}

function BubbleIcon.CreateIcon(factory, parent, bubbleFrame, message, direction, options)
  options = options or {}
  local bubbleIcon = UIHelpers.createCircularIcon(factory, parent, Theme.LAYOUT.BUBBLE_ICON_SIZE)
  local iconFrame = bubbleIcon.frame
  local icon = bubbleIcon.texture

  local gap = Theme.LAYOUT.BUBBLE_ICON_GAP or 8
  if direction == "in" then
    iconFrame:SetPoint("TOPRIGHT", bubbleFrame, "TOPLEFT", -gap, 0)
  else
    iconFrame:SetPoint("TOPLEFT", bubbleFrame, "TOPRIGHT", gap, 0)
  end

  local iconPath
  local classTag
  if direction == "out" then
    -- Stored class of the character that actually sent this message. Prefer
    -- this over the live UnitClass so relogging to another char doesn't
    -- rewrite history bubbles with the new char's class icon.
    classTag = message.senderClassTag
    if not classTag and type(_G.UnitClass) == "function" then
      local _, englishClass, _, playerTag = _G.UnitClass("player")
      classTag = playerTag or englishClass
    end
    iconPath = "Interface\\CHATFRAME\\UI-ChatIcon-ArmoryChat"
  else
    classTag = message.classTag or message.senderClassTag or options.fallbackClassTag
    iconPath = Theme.TEXTURES.bnet_icon
  end

  if not (classTag and Theme.ApplyClassIcon and Theme.ApplyClassIcon(icon, classTag)) then
    if icon.SetTexture then
      icon:SetTexture(iconPath)
    end
  end

  if direction == "in" then
    PlayerMenuClick.Attach(iconFrame, message, options.openPlayerMenu)
  end

  return { frame = iconFrame, texture = icon }
end

ns.ChatBubbleBubbleIcon = BubbleIcon
return BubbleIcon
