local LinkHooksEnv = require("tests.helpers.link_hooks_env")

-- On Sirus a bag or bank shift-click only calls ChatEdit_TryInsertChatLink,
-- which does nothing while no Blizzard chat box is open: the link must still
-- reach a focused messenger composer.
return function()
  local env = LinkHooksEnv.New()
  local input = env.NewInput()
  env.LinkHooks.RegisterInput(input)
  local itemLink = "|Hitem:12345|h[Test Item]|h"

  local function reset()
    env.Reset()
    input.focused = true
    input.shown = true
    env.blizzardActiveWindow = nil
    rawset(_G, "_wmSuspended", nil)
  end

  -- test_gated_try_insert_reaches_the_focused_composer
  do
    reset()
    _G.ChatEdit_TryInsertChatLink(itemLink)
    assert(#env.inserts == 1, "a gated ChatEdit_TryInsertChatLink must still reach the composer, got " .. #env.inserts)
    assert(env.inserts[1] == itemLink, "expected the item link, got " .. tostring(env.inserts[1]))
  end

  -- test_modified_item_click_reaches_the_focused_composer
  do
    reset()
    _G.HandleModifiedItemClick(itemLink)
    assert(#env.inserts == 1, "a bag shift-click must reach the composer, got " .. #env.inserts)
  end

  -- test_both_entry_points_insert_one_copy
  do
    reset()
    _G.ChatEdit_TryInsertChatLink(itemLink)
    _G.HandleModifiedItemClick(itemLink)
    assert(#env.inserts == 1, "one shift-click must insert one link, got " .. #env.inserts)
  end

  -- test_item_click_ignored_without_the_chatlink_modifier
  do
    reset()
    local savedIsModifiedClick = _G.IsModifiedClick
    rawset(_G, "IsModifiedClick", function()
      return false
    end)
    local ok, err = pcall(function()
      _G.HandleModifiedItemClick(itemLink)
    end)
    rawset(_G, "IsModifiedClick", savedIsModifiedClick)
    assert(ok, err)
    assert(#env.inserts == 0, "a plain click must not insert, got " .. #env.inserts)
  end

  -- test_item_click_ignored_when_the_composer_is_unfocused
  do
    reset()
    input.focused = false
    _G.ChatEdit_TryInsertChatLink(itemLink)
    assert(#env.inserts == 0, "an unfocused composer must not receive the link, got " .. #env.inserts)
  end

  -- test_item_click_ignored_while_a_blizzard_chat_box_is_open
  do
    reset()
    env.blizzardActiveWindow = {}
    _G.HandleModifiedItemClick(itemLink)
    assert(#env.inserts == 0, "Blizzard's open chat box keeps the link, got " .. #env.inserts)
  end

  -- test_shift_click_still_lands_after_the_click_moved_keyboard_focus
  -- Blizzard's own chat box stays active the same way: the click that opens a
  -- bag or a quest takes the keyboard focus before the link is inserted.
  do
    reset()
    env.Fire(input, "OnEditFocusGained")
    input.focused = false
    env.Fire(input, "OnEditFocusLost")
    _G.ChatEdit_TryInsertChatLink(itemLink)
    assert(#env.inserts == 1, "the composer the player was typing in must keep the link, got " .. #env.inserts)
  end

  -- test_remembered_composer_is_forgotten_when_the_window_hides
  do
    reset()
    env.Fire(input, "OnEditFocusGained")
    input.focused = false
    env.Fire(input, "OnEditFocusLost")
    input.shown = false
    env.Fire(input, "OnHide")
    _G.ChatEdit_TryInsertChatLink(itemLink)
    assert(#env.inserts == 0, "a closed messenger must not collect links, got " .. #env.inserts)
    input.shown = true
  end

  -- test_insert_falls_back_when_the_client_editbox_ignores_insert
  do
    reset()
    local text = ""
    rawset(input, "GetText", function()
      return text
    end)
    rawset(input, "SetText", function(_self, value)
      text = value
    end)
    rawset(input, "Insert", function() end)
    rawset(input, "SetCursorPosition", function() end)
    _G.ChatEdit_TryInsertChatLink(itemLink)
    assert(text == itemLink, "a client that ignores Insert still gets the link, got " .. tostring(text))
  end

  -- test_shift_click_trail_is_recorded_without_any_flag
  do
    reset()
    rawset(_G, "WMLinkDebug", nil)
    _G.HandleModifiedItemClick(itemLink)
    local trail = _G.WMLinkDebug
    assert(type(trail) == "table" and #trail > 0, "a shift-click must leave a trail for /dump WMLinkDebug")
    local text = table.concat(trail, " | ")
    assert(text:find("HandleModifiedItemClick", 1, true), "the trail names the Blizzard path: " .. text)
    rawset(_G, "WMLinkDebug", nil)
  end

  env.Restore()
end
