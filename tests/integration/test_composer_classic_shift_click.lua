local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

-- Regression: vanilla-style shift-click of a quest passes plain
-- `[Name (id)]` text to ChatEdit_InsertLink. Our post-hook must rewrite it to
-- a real quest hyperlink before it lands in the focused composer.
return function()
  local savedHooksecurefunc = _G.hooksecurefunc
  local savedChatEditGetActiveWindow = _G.ChatEdit_GetActiveWindow
  local savedChatEditInsertLink = _G.ChatEdit_InsertLink

  local hooks = {}
  rawset(_G, "hooksecurefunc", function(target, fn)
    if type(target) == "string" and type(fn) == "function" then
      hooks[target] = fn
    end
  end)

  -- Blizzard's ChatEdit_InsertLink with no Blizzard editbox open.
  _G.ChatEdit_InsertLink = function()
    return false
  end
  _G.ChatEdit_GetActiveWindow = function()
    return nil
  end

  local baseFactory = FakeUI.NewFactory()
  local factory = {}
  factory.CreateFrame = function(frameType, name, parent, template)
    local frame = baseFactory.CreateFrame(frameType, name, parent, template)
    if frameType == "EditBox" then
      frame._textValue = ""
      frame._hasFocus = false
      rawset(frame, "SetText", function(self, value)
        self._textValue = value
      end)
      rawset(frame, "GetText", function(self)
        return self._textValue
      end)
      rawset(frame, "HasFocus", function(self)
        return self._hasFocus == true
      end)
      local baseSetFocus = frame.SetFocus
      rawset(frame, "SetFocus", function(self)
        self._hasFocus = true
        if baseSetFocus then
          baseSetFocus(self)
        end
      end)
      local baseClearFocus = frame.ClearFocus
      rawset(frame, "ClearFocus", function(self)
        self._hasFocus = false
        if baseClearFocus then
          baseClearFocus(self)
        end
      end)
      rawset(frame, "Insert", function(self, text)
        self:SetText((self:GetText() or "") .. text)
      end)
    end
    return frame
  end

  local parent = factory.CreateFrame("Frame", "ComposerParent", nil)
  parent:SetSize(600, 200)

  local composer = Composer.Create(factory, parent, {
    conversationKey = "me::WOW::arthas-area52",
    displayName = "Arthas-Area52",
    channel = "WOW",
  }, function() end)

  assert(type(hooks.ChatEdit_InsertLink) == "function", "expected a ChatEdit_InsertLink post-hook")

  parent:Show()
  composer.frame:Show()
  composer.input:Show()
  composer.input:SetFocus()

  composer.input:SetText("")
  local plainText = "[Apprentice's Duties (471)]"
  _G.ChatEdit_InsertLink(plainText)
  hooks.ChatEdit_InsertLink(plainText)
  local expected = "|cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r"
  assert(
    composer.input:GetText() == expected,
    "expected classic shift-click plain text to be rewritten to a real hyperlink, got: " .. tostring(composer.input:GetText())
  )

  rawset(_G, "hooksecurefunc", savedHooksecurefunc)
  _G.ChatEdit_GetActiveWindow = savedChatEditGetActiveWindow
  _G.ChatEdit_InsertLink = savedChatEditInsertLink
end
