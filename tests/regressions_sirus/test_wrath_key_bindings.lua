local FakeUI = require("tests.helpers.fake_ui")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local EscapeKey = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.EscapeKey")
local ComposerSendFocus = require("WhisperMessenger.UI.Composer.ComposerSendFocus")

-- Counts the binding calls and frames a module asks the game for.
local function recorder(factory, key)
  local log = { bindings = 0, frames = 0 }
  log.deps = {
    createFrame = function(...)
      log.frames = log.frames + 1
      return factory.CreateFrame(...)
    end,
    getBindingKey = function()
      return key
    end,
    setOverrideBindingClick = function()
      log.bindings = log.bindings + 1
    end,
    clearOverrideBindings = function()
      log.bindings = log.bindings + 1
    end,
    inCombat = function()
      return false
    end,
  }
  return log
end

local function onWrath(test)
  local saved = FlavorCompat.isWrath335
  FlavorCompat.isWrath335 = true
  local ok, err = pcall(test)
  FlavorCompat.isWrath335 = saved
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_wrath_escape_leaves_the_game_menu_key_alone
  onWrath(function()
    local factory = FakeUI.NewFactory()
    local window = factory.CreateFrame("Frame", "WhisperMessengerKeyTestWindow", nil)
    window:Show()
    local log = recorder(factory, "ESCAPE")
    local escapeKey = EscapeKey.New(window, log.deps)
    escapeKey.setFocused(true)
    escapeKey.setFocused(false)
    escapeKey.setFocused(true)
    assert(log.bindings == 0, "3.3.5a: ESC stays the game's key, binding calls: " .. log.bindings)
    assert(log.frames == 0, "3.3.5a: no hidden ESC button or event frame, frames: " .. log.frames)
  end)

  -- test_escape_override_path_is_unchanged_when_allowed
  onWrath(function()
    local factory = FakeUI.NewFactory()
    local window = factory.CreateFrame("Frame", "WhisperMessengerKeyTestWindow2", nil)
    window:Show()
    local log = recorder(factory, "ESCAPE")
    log.deps.overrideBindings = true
    local escapeKey = EscapeKey.New(window, log.deps)
    escapeKey.setFocused(true)
    assert(log.bindings > 0, "an explicit override still binds ESC")
  end)

  -- test_wrath_send_focus_leaves_enter_alone_and_still_deselects
  onWrath(function()
    local factory = FakeUI.NewFactory()
    local pane = factory.CreateFrame("Frame", nil, nil)
    pane:Show()
    local input = factory.CreateFrame("EditBox", nil, pane)
    local log = recorder(factory, "ENTER")
    local sendFocus = ComposerSendFocus.Create(pane, input, {
      isOn = function()
        return true
      end,
      isEnabled = function()
        return true
      end,
    }, log.deps)
    sendFocus.sync()
    pane:Hide()
    pane:Show()
    assert(log.bindings == 0, "3.3.5a: Enter stays the game's key, binding calls: " .. log.bindings)
    assert(log.frames == 0, "3.3.5a: no Enter button or event frame, frames: " .. log.frames)
    input:SetFocus()
    sendFocus.afterSend()
    assert(input:HasFocus() == false, "a send still takes the cursor out of the composer")
  end)
end
