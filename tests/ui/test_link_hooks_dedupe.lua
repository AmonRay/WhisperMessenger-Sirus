-- LinkHooks only post-hooks ChatEdit_InsertLink / SetItemRef. It never
-- replaces them: assigning those globals from addon code tainted secure
-- callers such as the spellbook (ADDON_ACTION_FORBIDDEN CastSpell()).
-- A single shift-click fans out into several insert paths; only one insert per
-- frame may land in the composer.
return function()
  local savedHook = _G.hooksecurefunc
  local savedSetItemRef = _G.SetItemRef
  local savedChatEditGetActiveWindow = _G.ChatEdit_GetActiveWindow
  local savedChatEditInsertLink = _G.ChatEdit_InsertLink
  local savedGetTime = _G.GetTime

  local hooks = {}
  _G.hooksecurefunc = function(name, fn)
    hooks[name] = fn
  end
  _G.SetItemRef = function() end
  _G.ChatEdit_GetActiveWindow = function()
    return nil
  end
  _G.ChatEdit_InsertLink = function()
    return false
  end

  local frameTime = 100
  _G.GetTime = function()
    return frameTime
  end

  package.loaded["WhisperMessenger.UI.Composer.LinkHooks"] = nil
  local LinkHooks = require("WhisperMessenger.UI.Composer.LinkHooks")

  local inserts = {}
  local input = {
    focused = false,
    shown = true,
    IsVisible = function(self)
      return self.shown
    end,
    IsShown = function(self)
      return self.shown
    end,
    HasFocus = function(self)
      return self.focused
    end,
    Insert = function(_self, link)
      table.insert(inserts, link)
    end,
  }
  LinkHooks.RegisterInput(input)

  assert(type(hooks.ChatEdit_InsertLink) == "function", "expected a ChatEdit_InsertLink post-hook")
  assert(type(hooks.SetItemRef) == "function", "expected a SetItemRef post-hook")
  local insertLink = hooks.ChatEdit_InsertLink
  local setItemRef = hooks.SetItemRef

  local function reset()
    input.focused = false
    inserts = {}
  end

  -- test_shift_click_fanout_inserts_once
  do
    reset()
    input.focused = true
    frameTime = 200

    insertLink("Gammer-Kazzak")
    insertLink("|Hplayer:Gammer-Kazzak:1:WHISPER|h[Gammer]|h")
    setItemRef("player:Gammer-Kazzak:1:WHISPER", "|cff3fc7eb|Hplayer:Gammer-Kazzak:1:WHISPER|hGammer|h|r")

    assert(#inserts == 1, "expected exactly one insert from the shift-click fanout, got " .. #inserts)
    assert(inserts[1] == "Gammer-Kazzak", "expected the plain name to land, got: " .. tostring(inserts[1]))
  end

  -- test_next_frame_inserts_again
  do
    frameTime = 201
    insertLink("|Hitem:1|h[Item]|h")
    assert(#inserts == 2, "expected a second insert on the next frame, got " .. #inserts)
    assert(inserts[2] == "|Hitem:1|h[Item]|h", "expected the item link to land, got: " .. tostring(inserts[2]))
  end

  -- test_unfocused_composer_gets_nothing
  do
    reset()
    frameTime = 400
    insertLink("x")
    assert(#inserts == 0, "unfocused composer should not receive an insert, got " .. #inserts)
  end

  -- test_blizzard_editbox_focused_wins
  do
    reset()
    input.focused = true
    frameTime = 450
    _G.ChatEdit_GetActiveWindow = function()
      return {
        HasFocus = function()
          return true
        end,
      }
    end
    insertLink("|Hitem:2|h[Other]|h")
    assert(#inserts == 0, "a focused Blizzard editbox already got the link, got " .. #inserts)
    _G.ChatEdit_GetActiveWindow = function()
      return nil
    end
  end

  -- test_no_gettime_keeps_legacy_behavior
  do
    reset()
    _G.GetTime = nil
    input.focused = true
    insertLink("Gammer-Kazzak")
    insertLink("|Hplayer:Gammer-Kazzak:1:WHISPER|h[Gammer]|h")
    assert(#inserts == 2, "without GetTime both same-frame inserts should land, got " .. #inserts)
  end

  _G.hooksecurefunc = savedHook
  _G.SetItemRef = savedSetItemRef
  _G.ChatEdit_GetActiveWindow = savedChatEditGetActiveWindow
  _G.ChatEdit_InsertLink = savedChatEditInsertLink
  _G.GetTime = savedGetTime
  package.loaded["WhisperMessenger.UI.Composer.LinkHooks"] = nil
end
