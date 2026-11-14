local FakeUI = require("tests.helpers.fake_ui")
local PlayerMenuClick = require("WhisperMessenger.UI.ChatBubble.PlayerMenuClick")
local UIHelpers = require("WhisperMessenger.UI.Helpers")

local function withShift(isDown, fn)
  local original = rawget(_G, "IsShiftKeyDown")
  rawset(_G, "IsShiftKeyDown", function()
    return isDown
  end)
  fn()
  rawset(_G, "IsShiftKeyDown", original)
end

return function()
  local factory = FakeUI.NewFactory()
  local message = { direction = "in", channel = "WOW", playerName = "Bob-Realm" }

  -- test_right_click_calls_opener_with_message_frame_and_button
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local calls = {}
    PlayerMenuClick.Attach(frame, message, function(msg, anchor, button)
      calls[#calls + 1] = { message = msg, anchor = anchor, button = button }
    end)
    frame.scripts.OnMouseUp(frame, "RightButton")
    assert(#calls == 1, "right-click should call the opener once")
    assert(calls[1].message == message and calls[1].anchor == frame and calls[1].button == "RightButton")
  end

  -- test_plain_left_click_does_not_call_opener
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local calls = 0
    PlayerMenuClick.Attach(frame, message, function()
      calls = calls + 1
    end)
    withShift(false, function()
      frame.scripts.OnMouseUp(frame, "LeftButton")
    end)
    assert(calls == 0, "plain left-click must stay inert")
  end

  -- test_shift_left_click_calls_opener
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local button = nil
    PlayerMenuClick.Attach(frame, message, function(_msg, _anchor, clicked)
      button = clicked
    end)
    withShift(true, function()
      frame.scripts.OnMouseUp(frame, "LeftButton")
    end)
    assert(button == "LeftButton", "shift + left-click should reach the opener")
  end

  -- test_without_opener_right_click_opens_player_menu
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local opened = nil
    local ns = {
      ChatBubblePlayerMenu = {
        Open = function(msg, anchor)
          opened = { message = msg, anchor = anchor }
          return true
        end,
      },
    }
    local module = assert(loadfile("UI/ChatBubble/PlayerMenuClick.lua"))("WhisperMessenger", ns)
    module.Attach(frame, message, nil)
    frame.scripts.OnMouseUp(frame, "RightButton")
    assert(opened ~= nil and opened.message == message and opened.anchor == frame, "default opener should open the player menu")
  end
  -- test_shift_left_click_inserts_the_sender_name
  -- Shift + left-click on the sender's name drops it into the composer, the way
  -- a shift-clicked name works in the game's own chat; the player menu is the
  -- right-click's job.
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local inserted, opened = nil, 0
    local hookedNs = {
      UIHelpers = UIHelpers,
      ComposerLinkHooks = {
        InsertPlayerName = function(name)
          inserted = name
          return true
        end,
      },
    }
    local module = assert(loadfile("UI/ChatBubble/PlayerMenuClick.lua"))("WhisperMessenger", hookedNs)
    module.Attach(frame, message, function()
      opened = opened + 1
    end)
    withShift(true, function()
      frame.scripts.OnMouseUp(frame, "LeftButton")
    end)
    assert(inserted == "Bob-Realm", "shift + left-click should insert the sender name, got " .. tostring(inserted))
    assert(opened == 0, "an inserted name must not also open the player menu")
  end

  -- test_shift_left_click_opens_the_menu_when_the_composer_refuses
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local opened = 0
    local hookedNs = {
      UIHelpers = UIHelpers,
      ComposerLinkHooks = {
        InsertPlayerName = function()
          return false
        end,
      },
    }
    local module = assert(loadfile("UI/ChatBubble/PlayerMenuClick.lua"))("WhisperMessenger", hookedNs)
    module.Attach(frame, message, function()
      opened = opened + 1
    end)
    withShift(true, function()
      frame.scripts.OnMouseUp(frame, "LeftButton")
    end)
    assert(opened == 1, "a refused insert should still open the player menu")
  end

  -- test_shift_left_click_on_a_battlenet_name_never_inserts
  -- Battle.net names are not character names: Blizzard refuses them in chat.
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local inserted, opened = false, 0
    local hookedNs = {
      UIHelpers = UIHelpers,
      ComposerLinkHooks = {
        InsertPlayerName = function()
          inserted = true
          return true
        end,
      },
    }
    local module = assert(loadfile("UI/ChatBubble/PlayerMenuClick.lua"))("WhisperMessenger", hookedNs)
    module.Attach(frame, { direction = "in", channel = "BN", playerName = "Jaina#1234" }, function()
      opened = opened + 1
    end)
    withShift(true, function()
      frame.scripts.OnMouseUp(frame, "LeftButton")
    end)
    assert(inserted == false, "a Battle.net name must not be inserted")
    assert(opened == 1, "the Battle.net sender still gets the player menu")
  end
  -- test_shift_left_click_uses_the_display_name_when_a_channel_line_has_no_player_name
  -- Channel lines can arrive without playerName: the transcript shows
  -- senderDisplayName in that case, and that is the name to insert.
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local inserted = nil
    local hookedNs = {
      UIHelpers = UIHelpers,
      ComposerLinkHooks = {
        InsertPlayerName = function(name)
          inserted = name
          return true
        end,
      },
    }
    local module = assert(loadfile("UI/ChatBubble/PlayerMenuClick.lua"))("WhisperMessenger", hookedNs)
    module.Attach(frame, { direction = "in", channel = "CHANNEL", senderDisplayName = "Tsukoyomi" }, function() end)
    withShift(true, function()
      frame.scripts.OnMouseUp(frame, "LeftButton")
    end)
    assert(inserted == "Tsukoyomi", "expected the display name, got " .. tostring(inserted))
  end

  -- test_shift_left_click_on_the_message_inserts_the_sender_name
  -- The message line is what players aim at, not only the name above it.
  do
    local inserted = nil
    local hookedNs = {
      UIHelpers = UIHelpers,
      ComposerLinkHooks = {
        InsertPlayerName = function(name)
          inserted = name
          return true
        end,
      },
    }
    local module = assert(loadfile("UI/ChatBubble/PlayerMenuClick.lua"))("WhisperMessenger", hookedNs)
    local took
    withShift(true, function()
      took = module.InsertOnShiftClick({ direction = "in", channel = "CHANNEL", playerName = "Tsukoyomi" })
    end)
    assert(took == true, "shift + left-click on the message inserts the name")
    assert(inserted == "Tsukoyomi", "expected the sender name, got " .. tostring(inserted))
  end

  -- test_plain_left_click_on_the_message_never_inserts
  do
    local inserted = false
    local hookedNs = {
      UIHelpers = UIHelpers,
      ComposerLinkHooks = {
        InsertPlayerName = function()
          inserted = true
          return true
        end,
      },
    }
    local module = assert(loadfile("UI/ChatBubble/PlayerMenuClick.lua"))("WhisperMessenger", hookedNs)
    local took
    withShift(false, function()
      took = module.InsertOnShiftClick({ direction = "in", channel = "CHANNEL", playerName = "Tsukoyomi" })
    end)
    assert(took == false and inserted == false, "a plain left-click must not insert a name")
  end

  -- test_shift_left_click_on_a_channel_sender_inserts_the_name_too
  -- A channel or group line names a player just like a whisper does, so its
  -- shift + left-click inserts the name as well.
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local inserted, opened = nil, 0
    local hookedNs = {
      UIHelpers = UIHelpers,
      ComposerLinkHooks = {
        InsertPlayerName = function(name)
          inserted = name
          return true
        end,
      },
    }
    local module = assert(loadfile("UI/ChatBubble/PlayerMenuClick.lua"))("WhisperMessenger", hookedNs)
    module.Attach(frame, { direction = "in", channel = "GUILD", playerName = "Thrall" }, function()
      opened = opened + 1
    end)
    withShift(true, function()
      frame.scripts.OnMouseUp(frame, "LeftButton")
    end)
    assert(inserted == "Thrall", "a group sender inserts the name, got " .. tostring(inserted))
    assert(opened == 0, "the group opener is not reached once the name is in")
  end

  -- test_shift_left_click_on_a_channel_sender_falls_back_to_its_who_click
  -- With nobody to insert into, the old shift-click still happens.
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local opened = 0
    local hookedNs = {
      UIHelpers = UIHelpers,
      ComposerLinkHooks = {
        InsertPlayerName = function()
          return false
        end,
      },
    }
    local module = assert(loadfile("UI/ChatBubble/PlayerMenuClick.lua"))("WhisperMessenger", hookedNs)
    module.Attach(frame, { direction = "in", channel = "GUILD", playerName = "Thrall" }, function()
      opened = opened + 1
    end)
    withShift(true, function()
      frame.scripts.OnMouseUp(frame, "LeftButton")
    end)
    assert(opened == 1, "a refused insert leaves the /who click alone")
  end
end
