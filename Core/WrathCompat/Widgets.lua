local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Widgets = {}

local nativeCreateFrame

local UNSUPPORTED_TEMPLATES = {
  BackdropTemplate = true,
  TooltipBackdropTemplate = true,
  BasicFrameTemplateWithInset = true,
  ButtonFrameTemplate = true,
  DialogBorderTemplate = true,
  PortraitFrameTemplate = true,
  MinimalSliderWithSteppersTemplate = true,
  InsetFrameTemplate = true,
  InsetFrameTemplate2 = true,
  InsetFrameTemplate3 = true,
  InsetFrameTemplate4 = true,
}

local CLASS_IDS = {
  WARRIOR = 1,
  PALADIN = 2,
  HUNTER = 3,
  ROGUE = 4,
  PRIEST = 5,
  DEATHKNIGHT = 6,
  SHAMAN = 7,
  MAGE = 8,
  WARLOCK = 9,
  DRUID = 11,
}

local function stripTemplates(template)
  if type(template) ~= "string" then
    return template
  end
  local kept = {}
  for part in string.gmatch(template, "[^,]+") do
    local name = string.gsub(part, "^%s*(.-)%s*$", "%1")
    if name ~= "" and not UNSUPPORTED_TEMPLATES[name] then
      kept[#kept + 1] = name
    end
  end
  if #kept == 0 then
    return nil
  end
  return table.concat(kept, ",")
end

local function realmWithoutSeparators(env)
  local getRealmName = env.GetRealmName
  if type(getRealmName) == "function" then
    local ok, realm = pcall(getRealmName)
    if ok and type(realm) == "string" and realm ~= "" then
      return (string.gsub(realm, "[%s%-]", ""))
    end
  end
  return nil
end

local function normalizedRealm(env)
  local getNormalized = env.GetNormalizedRealmName
  if type(getNormalized) == "function" and env._wmWrathNormalizedShim ~= getNormalized then
    local ok, realm = pcall(getNormalized)
    if ok and type(realm) == "string" and realm ~= "" then
      return realm
    end
  end
  return realmWithoutSeparators(env)
end

local function ambiguate(env, name)
  if type(name) ~= "string" then
    return name
  end
  local base, realm = string.match(name, "^(.-)%-(.+)$")
  if base == nil then
    return name
  end
  local ownRealm = normalizedRealm(env)
  if ownRealm ~= nil and (string.gsub(realm, "[%s%-]", "")) == ownRealm then
    return base
  end
  return name
end

function Widgets.CreateColor(r, g, b, a)
  return {
    r = r,
    g = g,
    b = b,
    a = a or 1,
    GetRGB = function(self)
      return self.r, self.g, self.b
    end,
    GetRGBA = function(self)
      return self.r, self.g, self.b, self.a
    end,
  }
end

function Widgets.CreateFrame(frameType, name, parent, template, id)
  if type(nativeCreateFrame) ~= "function" then
    return nil
  end
  return nativeCreateFrame(frameType, name, parent, stripTemplates(template), id)
end

function Widgets.WrapFactory(env)
  env = env or _G
  if type(nativeCreateFrame) ~= "function" then
    return env
  end
  local proxy = { CreateFrame = Widgets.CreateFrame }
  return setmetatable(proxy, { __index = env })
end

function Widgets.Install(env)
  env = env or _G

  if type(env.CreateColor) ~= "function" then
    env.CreateColor = Widgets.CreateColor
  end

  if type(env.CreateFrame) == "function" then
    nativeCreateFrame = env.CreateFrame
  end

  local unitClass = env.UnitClass
  if type(unitClass) == "function" and env._wmWrathUnitClass ~= true then
    env._wmWrathUnitClass = true
    env.UnitClass = function(unit)
      local localized, english, classID, classTag = unitClass(unit)
      if classTag == nil and type(english) == "string" then
        classTag = string.upper((string.gsub(english, "%s+", "")))
        classID = CLASS_IDS[classTag]
      end
      return localized, english, classID, classTag
    end
  end

  if type(env.Ambiguate) ~= "function" then
    env.Ambiguate = function(name, _context)
      return ambiguate(env, name)
    end
  end

  if type(env.GetNormalizedRealmName) ~= "function" then
    local shim = function()
      return realmWithoutSeparators(env)
    end
    env.GetNormalizedRealmName = shim
    env._wmWrathNormalizedShim = shim
  end

  return true
end

ns.WrathCompatWidgets = Widgets

return Widgets
