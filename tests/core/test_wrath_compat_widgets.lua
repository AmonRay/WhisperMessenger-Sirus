local Widgets = require("WhisperMessenger.Core.WrathCompat.Widgets")

return function()
  local requestedTemplates = {}
  local originalUnitClass = function(_unit)
    return "Death Knight", "Death Knight"
  end
  local env = {
    CreateFrame = function(_frameType, _name, _parent, template)
      requestedTemplates[#requestedTemplates + 1] = template or "<none>"
      return { template = template }
    end,
    GetRealmName = function()
      return "Deathwing"
    end,
    UnitClass = originalUnitClass,
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

  assert(env.UnitClass == originalUnitClass, "the global UnitClass must stay untouched")
  local savedUnitClass = rawget(_G, "UnitClass")
  rawset(_G, "UnitClass", originalUnitClass)
  local _, _, classID, classTag = Widgets.UnitClass("player")
  rawset(_G, "UnitClass", savedUnitClass)
  assert(classTag == "DEATHKNIGHT", "expected an English class token")
  assert(classID == 6, "expected the WotLK class id")

  -- test_get_point_by_name_shim_reads_the_matching_anchor
  local uiParent = {
    GetNumPoints = function()
      return 2
    end,
    GetPoint = function(_self, index)
      if index == 1 then
        return "CENTER", nil, nil, 0, 0
      end
      return "TOPLEFT", uiParent, "TOPLEFT", 12, -34
    end,
  }
  assert(Widgets.InstallGetPointByName(uiParent) == true, "a region without GetPointByName gets the shim")
  local point, _relativeTo, _relativePoint, offsetX, offsetY = uiParent:GetPointByName("TOPLEFT")
  assert(point == "TOPLEFT" and offsetX == 12 and offsetY == -34, "the shim must report the matching anchor")
  assert(uiParent:GetPointByName("BOTTOMRIGHT") == nil, "an anchor the region does not use must stay nil")

  local own = function()
    return "own"
  end
  local existing = { GetPointByName = own }
  assert(Widgets.InstallGetPointByName(existing) == false, "an existing method must not be replaced")
  assert(existing.GetPointByName == own, "the region keeps its own implementation")

  assert(env.GetNormalizedRealmName() == "Deathwing", "expected the realm shim")
  assert(env.Ambiguate("Arthas-Deathwing", "none") == "Arthas", "expected our own realm to be dropped")
  assert(env.Ambiguate("Jaina-Proudmoore", "none") == "Jaina-Proudmoore", "expected another realm to stay")
end
