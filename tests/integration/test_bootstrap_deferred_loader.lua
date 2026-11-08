local FakeUI = require("tests.helpers.fake_ui")

local function loadTocExceptBootstrap(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    local path = string.gsub(line, "\r", "")
    if path ~= "" and string.sub(path, 1, 2) ~= "##" and not string.match(path, "%.xml$") and path ~= "Bootstrap.lua" then
      local chunk = assert(loadfile(path))
      chunk(addonName, ns)
    end
  end
end

return function()
  local savedLoadfile = loadfile
  local savedRequire = require
  local factory = FakeUI.NewFactory()
  local createdFrames = {}

  _G.WOW_PROJECT_ID = nil
  _G.GetBuildInfo = function()
    return "3.3.5", "12340", "Feb 1 2010", 30300
  end
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.SlashCmdList = {}
  _G.C_ChatInfo = nil
  _G.C_FriendList = nil
  _G.C_BattleNet = nil
  _G.C_GuildInfo = nil
  _G.C_AddOns = nil
  _G.C_DateAndTime = nil
  _G.C_Timer = nil
  _G.C_Club = nil
  _G.CreateColor = nil
  _G.Ambiguate = nil
  _G.UnitFullName = nil
  _G.GetNormalizedRealmName = nil
  _G.CLASS_ICON_TCOORDS = nil

  rawset(_G, "UnitName", function()
    return "Arthas"
  end)
  rawset(_G, "UnitClass", function()
    return "Warrior", "Warrior"
  end)
  rawset(_G, "GetRealmName", function()
    return "Deathwing"
  end)
  rawset(_G, "time", function()
    return 12345
  end)

  _G.WhisperMessengerDB = {
    conversations = {},
    contacts = {},
    pendingHydration = {},
    schemaVersion = 1,
  }
  _G.WhisperMessengerCharacterDB = {
    window = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 920, height = 580 },
    icon = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
  }

  rawset(_G, "CreateFrame", function(frameType, name, parent, template)
    local frame = factory.CreateFrame(frameType, name, parent, template)
    createdFrames[#createdFrames + 1] = frame
    function frame:RegisterEvent(eventName)
      self.events = self.events or {}
      self.events[eventName] = true
    end
    function frame:UnregisterEvent(eventName)
      if self.events then
        self.events[eventName] = nil
      end
    end
    function frame:UnregisterAllEvents()
      self.events = {}
    end
    return frame
  end)

  _G.require = nil
  _G.loadfile = nil

  local ns = {}
  local bootstrap = assert(savedLoadfile("Bootstrap.lua"))
  bootstrap("WhisperMessenger", ns)
  assert(ns.Bootstrap ~= nil, "expected Bootstrap to register without the loader")

  _G.loadfile = savedLoadfile
  loadTocExceptBootstrap("WhisperMessenger", ns)

  local waiter = nil
  for _, frame in ipairs(createdFrames) do
    if frame.events and frame.events.ADDON_LOADED then
      waiter = frame
      break
    end
  end
  assert(waiter ~= nil, "expected a frame waiting for ADDON_LOADED")

  waiter.scripts.OnEvent(waiter, "ADDON_LOADED", "WhisperMessenger")
  assert(ns.Bootstrap.runtime ~= nil, "expected the runtime to start once the modules were available")

  _G.require = savedRequire
end
