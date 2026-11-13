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

  env.Restore()
end
