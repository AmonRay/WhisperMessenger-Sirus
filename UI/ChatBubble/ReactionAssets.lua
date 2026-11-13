local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Protocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local RestrictedEmojis = ns.RestrictedEmojis or require("WhisperMessenger.Model.RestrictedEmojis")

local ReactionAssets = {}
local KEYS = Protocol.REACTION_KEYS

local ATLAS_WIDTH = 1024
local ATLAS_HEIGHT = 256
local SLOT_SIZE = 72
local SLOT_OFFSET_X = 28
local SLOT_OFFSET_Y = 28
local SLOT_STRIDE_X = 112
local SLOT_STRIDE_Y = 128
local PICKER_COLUMNS = 9
local PICKER_ROWS = 2

local TEX_COORDS = {}
for index, key in ipairs(KEYS) do
  local slot = index - 1
  local column = slot % PICKER_COLUMNS
  local row = math.floor(slot / PICKER_COLUMNS)
  local left = SLOT_OFFSET_X + column * SLOT_STRIDE_X
  local top = SLOT_OFFSET_Y + row * SLOT_STRIDE_Y
  TEX_COORDS[key] = {
    left / ATLAS_WIDTH,
    (left + SLOT_SIZE) / ATLAS_WIDTH,
    top / ATLAS_HEIGHT,
    (top + SLOT_SIZE) / ATLAS_HEIGHT,
  }
end

function ReactionAssets.GetTexCoords(key)
  return TEX_COORDS[key]
end

-- Inline glyphs scale with the message font; picker/badge sizes stay
-- separate. A messenger emoji reads as an emoji, not as a small icon next to
-- the text, so it is half again the font size.
local INLINE_ICON_SCALE = 1.5

local function inlineIconSize(fontSize)
  -- Only message bubbles supply a font size. Other surfaces keep their
  -- existing sizing (previews, quotes and picker copy text).
  if tonumber(fontSize) == nil then
    return ReactionAssets.GetIconSize()
  end
  return math.max(1, math.floor(tonumber(fontSize) * INLINE_ICON_SCALE + 0.5))
end

local INLINE_TEXTURE_DIR = "Interface\\AddOns\\WhisperMessenger\\Media\\emoji\\"
local INLINE_TEXTURES = {}
for _, key in ipairs(KEYS) do
  INLINE_TEXTURES[key] = INLINE_TEXTURE_DIR .. key .. ".tga"
end

-- 3.3.5a's |T markup cannot crop an atlas (no texcoords), so a subrect there
-- draws the whole sheet squeezed into the icon box and the glyph looks tiny.
-- Each key therefore ships as its own square texture; the atlas stays for the
-- picker and badges that can set texcoords on a texture object.
function ReactionAssets.GetInlineTexture(key)
  return INLINE_TEXTURES[key]
end

function ReactionAssets.GetInlineTextureMarkup(key, fontSize)
  local size = inlineIconSize(fontSize)
  local texture = INLINE_TEXTURES[key]
  if texture ~= nil then
    return string.format("|T%s:%d:%d|t", texture, size, size)
  end

  local coords = ReactionAssets.GetTexCoords(key)
  if coords == nil then
    return nil
  end

  local textureWidth, textureHeight = ATLAS_WIDTH, ATLAS_HEIGHT
  local left = math.floor(coords[1] * textureWidth + 0.5)
  local right = math.floor(coords[2] * textureWidth + 0.5)
  local top = math.floor(coords[3] * textureHeight + 0.5)
  local bottom = math.floor(coords[4] * textureHeight + 0.5)
  return string.format(
    "|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t",
    ReactionAssets.TEXTURE,
    size,
    size,
    textureWidth,
    textureHeight,
    left,
    right,
    top,
    bottom
  )
end

-- senderName: who wrote the text. Personal (restricted) emojis render only
-- when it is one of their owners; otherwise the token stays literal.
function ReactionAssets.FormatTextForDisplay(text, senderName, fontSize)
  return (
    tostring(text or ""):gsub(":([%a%d_]+):", function(key)
      if RestrictedEmojis.IsRestricted(key) then
        if RestrictedEmojis.CanUse(key, senderName) then
          return RestrictedEmojis.GetInlineTextureMarkup(key, inlineIconSize(fontSize))
        end
        return ":" .. key .. ":"
      end
      return ReactionAssets.GetInlineTextureMarkup(key, fontSize) or ":" .. key .. ":"
    end)
  )
end
function ReactionAssets.GetIconSize()
  local size = tonumber(Fonts.GetFontSize and Fonts.GetFontSize()) or 12
  return math.max(9, math.min(17, size))
end
function ReactionAssets.GetPickerIconSize()
  return math.floor(ReactionAssets.GetIconSize() * 1.5 + 0.5)
end

function ReactionAssets.GetPickerLayout()
  local iconSize = ReactionAssets.GetPickerIconSize()
  local buttonSize = iconSize + 6
  return {
    iconSize = iconSize,
    buttonSize = buttonSize,
    columns = PICKER_COLUMNS,
    rows = PICKER_ROWS,
    frameWidth = buttonSize * PICKER_COLUMNS + 12,
    frameHeight = buttonSize * PICKER_ROWS + 34,
    copyWidth = buttonSize * PICKER_COLUMNS,
    copyOffsetY = -(buttonSize * PICKER_ROWS + 8),
  }
end
function ReactionAssets.GetBadgeOverflow()
  return math.max(0, ReactionAssets.GetIconSize() - ReactionAssets.BADGE_OFFSET_Y)
end

ReactionAssets.KEYS = KEYS
ReactionAssets.TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\reactions.tga"
ReactionAssets.BADGE_OFFSET_Y = 7

ns.ChatBubbleReactionAssets = ReactionAssets
return ReactionAssets
