local Widgets = require("WhisperMessenger.Core.WrathCompat.Widgets")

return function()
  local requestedTemplates = {}
  local env = {
    CreateFrame = function(_frameType, _name, _parent, template)
      requestedTemplates[#requestedTemplates + 1] = template or "<none>"
      return { template = template }
    end,
    GetRealmName = function()
      return "Deathwing"
    end,
    UnitClass = function(_unit)
      return "Death Knight", "Death Knight"
    end,
  }

  Widgets.Install(env)

  local wrapped = Widgets.WrapFactory(env)
  wrapped.CreateFrame("Frame", "WMWindow", nil, "BackdropTemplate")
  assert(requestedTemplates[1] == "<none>", "expected BackdropTemplate to be dropped")

  wrapped.CreateFrame("Button", nil, nil, "BasicFrameTemplateWithInset,UIPanelButtonTemplate")
  assert(requestedTemplates[2] == "UIPanelButtonTemplate", "expected the supported template to survive")

  env.CreateFrame("Frame", "DetailsCopyPasteWindow", nil, "ButtonFrameTemplate")
  assert(requestedTemplates[3] == "ButtonFrameTemplate", "the global CreateFrame must stay untouched")

  local color = env.CreateColor(0.1, 0.2, 0.3, 0.4)
  local r, g, b, a = color:GetRGBA()
  assert(r == 0.1 and g == 0.2 and b == 0.3 and a == 0.4, "expected CreateColor to keep its components")

  local _, _, classID, classTag = env.UnitClass("player")
  assert(classTag == "DEATHKNIGHT", "expected an English class token")
  assert(classID == 6, "expected the WotLK class id")

  assert(env.GetNormalizedRealmName() == "Deathwing", "expected the realm shim")
  assert(env.Ambiguate("Arthas-Deathwing", "none") == "Arthas", "expected our own realm to be dropped")
  assert(env.Ambiguate("Jaina-Proudmoore", "none") == "Jaina-Proudmoore", "expected another realm to stay")
end
