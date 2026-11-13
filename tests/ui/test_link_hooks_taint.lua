local LinkHooksEnv = require("tests.helpers.link_hooks_env")

-- Any assignment from addon code to a Blizzard global or ChatFrameUtil field
-- taints that slot for the rest of the session, even when the value written
-- back is Blizzard's own function. Blizzard's Enter/send path then runs
-- tainted and SendChatMessage is blocked in an encounter. LinkHooks may only
-- post-hook through hooksecurefunc; it must never assign these slots.
--
-- ChatEdit_GetActiveWindow is the one exception: the game's own click handlers
-- (quest log, achievements, adventure guide, battle pass) ask it before they
-- hand a link to ChatEdit_InsertLink, and a post-hook cannot reach a button
-- that stored its handler before we hooked it. The composer answers as the
-- active window only while it has focus and Blizzard has no box of its own
-- open; the test below pins that down.
return function()
  local env = LinkHooksEnv.New()
  local input = env.NewInput()
  env.LinkHooks.RegisterInput(input)

  -- Whatever hooksecurefunc put in the slots is the expected state from now on.
  local expectedGlobalInsertLink = env.globals.ChatEdit_InsertLink
  local expectedUtilInsertLink = env.chatFrameUtilBacking.InsertLink

  -- env.writes records every assignment to the watched Blizzard globals and
  -- ChatFrameUtil fields, including one that writes the same function back.
  -- The active-window answer is the single documented replacement.
  local ALLOWED_WRITES = { ChatEdit_GetActiveWindow = true }
  local function assertUntouched(when)
    for _, slot in ipairs(env.writes) do
      assert(ALLOWED_WRITES[slot], when .. ": LinkHooks assigned " .. slot)
    end
    assert(env.globals.ChatEdit_InsertLink == expectedGlobalInsertLink, when .. ": ChatEdit_InsertLink was replaced")
    assert(env.chatFrameUtilBacking.GetActiveWindow == env.originalGetActiveWindow, when .. ": ChatFrameUtil.GetActiveWindow was replaced")
    assert(env.chatFrameUtilBacking.InsertLink == expectedUtilInsertLink, when .. ": ChatFrameUtil.InsertLink was replaced")
  end

  -- test_register_input_assigns_no_blizzard_slot
  do
    assertUntouched("after RegisterInput")
  end

  -- test_focus_gained_assigns_no_blizzard_slot
  do
    input.focused = true
    env.Fire(input, "OnEditFocusGained")
    assertUntouched("while the composer is focused")
  end

  -- test_focus_lost_assigns_no_blizzard_slot
  do
    input.focused = false
    env.Fire(input, "OnEditFocusLost")
    assertUntouched("after the composer lost focus")
  end

  -- test_insert_links_are_post_hooked_through_hooksecurefunc
  do
    assert(env.hooks["ChatFrameUtil.InsertLink"] ~= nil, "ChatFrameUtil.InsertLink should be post-hooked")
    assert(env.hooks.ChatEdit_InsertLink ~= nil, "ChatEdit_InsertLink should be post-hooked")
  end

  -- test_the_active_window_answer_is_the_composer_only_while_focused
  do
    local blizzardBox = { name = "BlizzardChatEditBox" }
    env.blizzardActiveWindow = blizzardBox
    assert(_G.ChatEdit_GetActiveWindow() == blizzardBox, "an open Blizzard chat box keeps its own answer")
    env.blizzardActiveWindow = nil
    input.focused = false
    env.Fire(input, "OnEditFocusLost")
    assert(_G.ChatEdit_GetActiveWindow() == nil, "without focus the answer is Blizzard's")
    input.focused = true
    env.Fire(input, "OnEditFocusGained")
    assert(_G.ChatEdit_GetActiveWindow() == input, "the focused composer answers as the active chat window")
    rawset(_G, "_wmSuspended", true)
    assert(_G.ChatEdit_GetActiveWindow() == nil, "a suspended addon answers nothing")
    rawset(_G, "_wmSuspended", nil)
    env.Fire(input, "OnEditFocusLost")
  end

  env.Restore()
end
