-- Regression for ADDON_ACTION_FORBIDDEN "CastSpell()": LinkHooks must never
-- assign Blizzard's chat globals, not at load and not on composer focus.
-- Links reach the focused composer through post-hooks only.
return function()
  local savedHook = _G.hooksecurefunc
  local savedSetItemRef = _G.SetItemRef
  local savedChatEditGetActiveWindow = _G.ChatEdit_GetActiveWindow
  local savedChatEditInsertLink = _G.ChatEdit_InsertLink
  local savedGetTime = _G.GetTime
  local savedSuspended = _G._wmSuspended

  local hooks = {}
  _G.hooksecurefunc = function(name, fn)
    hooks[name] = fn
  end

  local originalGetActiveWindow = function()
    return nil
  end
  local originalInsertLink = function(_link)
    return false
  end
  local originalSetItemRef = function() end
  _G.ChatEdit_GetActiveWindow = originalGetActiveWindow
  _G.ChatEdit_InsertLink = originalInsertLink
  _G.SetItemRef = originalSetItemRef
  _G.GetTime = nil
  _G._wmSuspended = nil

  package.loaded["WhisperMessenger.UI.Composer.LinkHooks"] = nil
  local LinkHooks = require("WhisperMessenger.UI.Composer.LinkHooks")

  local input = {
    focused = false,
    shown = true,
    lastInsert = nil,
    IsVisible = function(self)
      return self.shown
    end,
    IsShown = function(self)
      return self.shown
    end,
    HasFocus = function(self)
      return self.focused
    end,
    Insert = function(self, link)
      self.lastInsert = link
    end,
  }
  LinkHooks.RegisterInput(input)

  local function reset()
    input.focused = false
    input.shown = true
    input.lastInsert = nil
  end

  local function assertGlobalsUntouched(context)
    assert(_G.ChatEdit_GetActiveWindow == originalGetActiveWindow, "ChatEdit_GetActiveWindow must never be replaced (" .. context .. ")")
    assert(_G.ChatEdit_InsertLink == originalInsertLink, "ChatEdit_InsertLink must never be replaced (" .. context .. ")")
    assert(_G.SetItemRef == originalSetItemRef, "SetItemRef must never be replaced (" .. context .. ")")
  end

  -- test_globals_untouched_at_load
  assertGlobalsUntouched("load")
  assert(type(hooks.ChatEdit_InsertLink) == "function", "expected a ChatEdit_InsertLink post-hook")
  assert(type(hooks.SetItemRef) == "function", "expected a SetItemRef post-hook")

  -- test_globals_untouched_while_focused
  do
    reset()
    input.focused = true
    hooks.ChatEdit_InsertLink("|Hitem:1|h[A]|h")
    assertGlobalsUntouched("focused")
  end

  -- test_insert_link_hook_routes_into_focused_composer
  do
    reset()
    input.focused = true
    hooks.ChatEdit_InsertLink("|Hitem:12345|h[Test Item]|h")
    assert(input.lastInsert == "|Hitem:12345|h[Test Item]|h", "focused input should receive the link, got: " .. tostring(input.lastInsert))
  end

  -- test_insert_link_hook_ignores_unfocused_or_hidden
  do
    reset()
    hooks.ChatEdit_InsertLink("|Hitem:12345|h[Test Item]|h")
    assert(input.lastInsert == nil, "unfocused input must not receive the link")

    reset()
    input.focused = true
    input.shown = false
    hooks.ChatEdit_InsertLink("|Hitem:12345|h[Test Item]|h")
    assert(input.lastInsert == nil, "hidden input must not receive the link")
  end

  -- test_suspended_addon_inserts_nothing
  do
    reset()
    input.focused = true
    _G._wmSuspended = true
    hooks.ChatEdit_InsertLink("|Hitem:12345|h[Test Item]|h")
    _G._wmSuspended = nil
    assert(input.lastInsert == nil, "suspended addon must not insert")
  end

  -- test_set_item_ref_hook_does_nothing_when_unfocused
  do
    reset()
    hooks.SetItemRef("quest:12345", "[Some Quest]")
    assert(input.lastInsert == nil, "SetItemRef hook should not insert quest link when unfocused")
  end

  -- test_set_item_ref_hook_inserts_when_focused
  do
    reset()
    input.focused = true
    hooks.SetItemRef("|Hitem:12345|h[Test Item]|h", "|Hitem:12345|h[Test Item]|h")
    assert(input.lastInsert ~= nil, "SetItemRef hook should insert when focused")
  end

  -- test_set_item_ref_hook_skips_our_url_links_when_focused
  do
    reset()
    input.focused = true
    local urlText = "|cff71d5ff|Haddon:WhisperMessenger:url:https://example.com|hhttps://example.com|h|r"
    hooks.SetItemRef("addon:WhisperMessenger:url:https://example.com", urlText)
    assert(input.lastInsert == nil, "SetItemRef hook should not insert our URL links, got: " .. tostring(input.lastInsert))
  end

  _G.hooksecurefunc = savedHook
  _G.SetItemRef = savedSetItemRef
  _G.ChatEdit_GetActiveWindow = savedChatEditGetActiveWindow
  _G.ChatEdit_InsertLink = savedChatEditInsertLink
  _G.GetTime = savedGetTime
  _G._wmSuspended = savedSuspended
  package.loaded["WhisperMessenger.UI.Composer.LinkHooks"] = nil
end
