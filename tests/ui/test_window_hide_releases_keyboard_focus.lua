local FakeUI = require("tests.helpers.fake_ui")
local ScriptBindings = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.ScriptBindings")

-- 3.3.5a keeps keyboard focus on a hidden EditBox: closing the window with
-- the composer focused left every key (C, P, B, ESC...) going to that hidden
-- box, so no other window could open. Hiding the window must drop the focus.

local SAVED_NAMES = {
  "CreateFrame",
  "GetBindingKey",
  "SetOverrideBindingClick",
  "ClearOverrideBindings",
  "InCombatLockdown",
  "UISpecialFrames",
  "GetCurrentKeyBoardFocus",
}

local function noop() end

local function makeResizeStub()
  return {
    isResizing = function()
      return false
    end,
    stop = noop,
    reset = noop,
    start = noop,
    setHighlight = noop,
    updateFromCursor = noop,
  }
end

-- Runs fn(env) with a hidden window holding a composer input and a second
-- input; GetCurrentKeyBoardFocus reports whichever box has focus.
local function withWindow(fn)
  local saved = {}
  for _, name in ipairs(SAVED_NAMES) do
    saved[name] = rawget(_G, name)
  end
  local factory = FakeUI.NewFactory()
  local env = { boxes = {} }
  rawset(_G, "CreateFrame", factory.CreateFrame)
  rawset(_G, "GetBindingKey", function()
    return "ESCAPE"
  end)
  rawset(_G, "SetOverrideBindingClick", noop)
  rawset(_G, "ClearOverrideBindings", noop)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  rawset(_G, "UISpecialFrames", {})
  rawset(_G, "GetCurrentKeyBoardFocus", function()
    for _, box in ipairs(env.boxes) do
      if box:HasFocus() then
        return box
      end
    end
    return env.outsideFocus
  end)

  local ok, err = pcall(function()
    local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
    uiParent:Show()
    env.frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", uiParent)
    env.frame:Hide()
    local pane = factory.CreateFrame("Frame", nil, env.frame)
    env.composerInput = factory.CreateFrame("EditBox", nil, pane)
    env.searchInput = factory.CreateFrame("EditBox", nil, pane)
    env.boxes = { env.composerInput, env.searchInput }
    local resizeStub = makeResizeStub()
    ScriptBindings.Bind({
      frame = env.frame,
      frameTheme = { WINDOW_ALPHA_UPDATE_INTERVAL = 0.1 },
      windowResize = resizeStub,
      contactsResize = resizeStub,
      relayoutWindow = noop,
      isSuppressSizeChangedRelayout = function()
        return false
      end,
      refreshWindowAlpha = noop,
      composerInput = env.composerInput,
      getAutoFocusChatInput = function()
        return true
      end,
      buildState = function()
        return {}
      end,
    })
    fn(env)
  end)
  for _, name in ipairs(SAVED_NAMES) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

return function()
  -- test_hiding_the_window_drops_composer_focus
  withWindow(function(env)
    env.frame:Show()
    assert(env.composerInput:HasFocus(), "auto-focus must focus the composer on show")
    env.frame:Hide()
    assert(not env.composerInput:HasFocus(), "a hidden composer must not keep keyboard focus")
  end)

  -- test_hiding_the_window_drops_focus_of_any_box_inside_it
  withWindow(function(env)
    env.frame:Show()
    env.composerInput:ClearFocus()
    env.searchInput:SetFocus()
    env.frame:Hide()
    assert(not env.searchInput:HasFocus(), "a hidden search box must not keep keyboard focus")
  end)

  -- test_hiding_the_window_leaves_focus_outside_it_alone
  withWindow(function(env)
    local cleared = false
    env.outsideFocus = {
      GetParent = function()
        return nil
      end,
      ClearFocus = function()
        cleared = true
      end,
    }
    env.frame:Show()
    env.composerInput:ClearFocus()
    env.frame:Hide()
    assert(cleared == false, "the chat box or another addon's input keeps its focus")
  end)
end
