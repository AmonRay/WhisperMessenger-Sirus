local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local Textures = require("WhisperMessenger.UI.Theme.Textures")

local SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

local function fakeTexture()
  return {
    SetTexture = function(self, path)
      self.path = path
    end,
    SetTexCoord = function(self, left, right, top, bottom)
      self.coords = { left, right, top, bottom }
    end,
  }
end

return function()
  local savedWrath = FlavorCompat.isWrath335

  FlavorCompat.isWrath335 = false
  assert(
    Textures.ClassIcon("Death Knight") == Textures.TEXTURES.class_icon_prefix .. "DEATHKNIGHT",
    "expected an English class name to map to a token"
  )
  assert(Textures.ClassIcon(2) == Textures.TEXTURES.class_icon_prefix .. "PALADIN", "expected a class id to map to a token")
  assert(Textures.ClassIcon("Peasant") == nil, "expected an unknown class to have no icon")

  local texture = fakeTexture()
  assert(Textures.ApplyClassIcon(texture, "paladin") == true, "expected the icon to apply")
  assert(texture.path == Textures.TEXTURES.class_icon_prefix .. "PALADIN", "expected the per-class file on modern clients")
  assert(texture.coords[1] == 0 and texture.coords[4] == 1, "expected full texture coordinates")

  FlavorCompat.isWrath335 = true
  _G.CLASS_ICON_TCOORDS = { PALADIN = { 0.1, 0.2, 0.3, 0.4 } }
  assert(Textures.ClassIcon("PALADIN") == nil, "expected no per-class file on 3.3.5")
  assert(Textures.ApplyClassIcon(texture, "Paladin") == true, "expected the shared sheet to be applied")
  assert(texture.path == SHEET, "expected the character-create sheet")
  assert(texture.coords[1] == 0.1 and texture.coords[4] == 0.4, "expected the class crop coordinates")

  _G.CLASS_ICON_TCOORDS = nil
  assert(Textures.ApplyClassIcon(texture, "PALADIN") == false, "expected no icon when the client has no class art")
  assert(Textures.ApplyClassIcon(texture, nil) == false, "expected no icon for an unknown class")

  FlavorCompat.isWrath335 = savedWrath
end
