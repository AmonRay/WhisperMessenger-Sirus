local FakeUI = require("tests.helpers.fake_ui")

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" and not string.match(line, "%.xml$") then
      local chunk = assert(loadfile(line))
      chunk(addonName, ns)
    end
  end
end

return function()
  local savedRequire = require
  local factory = FakeUI.NewFactory()
  local createdFrames = {}
  local conversationKey = "wow::WOW::jaina-proudmoore"

  _G.require = nil
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
    conversations = {
      [conversationKey] = {
        displayName = "Jaina-Proudmoore",
        channel = "WOW",
        messages = { { text = "hello" } },
        unreadCount = 0,
        lastActivityAt = 10,
        conversationKey = conversationKey,
      },
    },
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
    return frame
  end)

  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)

  assert(ns.WrathCompat and ns.WrathCompat.IsInstalled(), "expected the 3.3.5a compat layer to install")
  assert(type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function", "expected the timer shim")
  assert(type(_G.C_ChatInfo) == "table", "expected the chat shim")
  assert(type(_G.C_ChatInfo.SendChatMessage) == "function", "expected chat sending")
  assert(type(_G.C_FriendList) == "table", "expected the friend list shim")
  assert(type(_G.CreateColor) == "function", "expected CreateColor")
  assert(_G.Ambiguate("Arthas-Deathwing", "none") == "Arthas", "expected own-realm names to be shortened")
  assert(_G.GetNormalizedRealmName() == "Deathwing", "expected the normalized realm shim")

  local _, englishClass, globalClassID = _G.UnitClass("player")
  assert(englishClass == "Warrior" and globalClassID == nil, "the global UnitClass must stay untouched")
  local _, _, classID, classTag = ns.WrathCompatWidgets.UnitClass("player")
  assert(classTag == "WARRIOR" and classID == 1, "expected Widgets.UnitClass to expose the class token")

  local eventFrame = nil
  for _, frame in ipairs(createdFrames) do
    if frame.scripts and frame.scripts.OnEvent then
      eventFrame = frame
      break
    end
  end
  assert(eventFrame ~= nil, "expected addon load event frame")
  eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "WhisperMessenger")

  local runtime = ns.Bootstrap.runtime
  assert(runtime ~= nil, "expected runtime after addon load")

  runtime.toggle()
  assert(runtime.window ~= nil, "expected the messenger window to build on 3.3.5a")
  assert(runtime.window.contacts.rows[1] ~= nil, "expected a contact row for the preloaded conversation")
  assert(runtime.window.frame.template == nil, "expected BackdropTemplate to be dropped for this client")

  runtime.window.contacts.rows[1].scripts.OnClick()
  assert(runtime.activeConversationKey == conversationKey, "expected the contact click to select the conversation")

  _G.require = savedRequire
end
