-- The transcript layout must hand the "Repeat message" handlers to every
-- bubble it builds: the bubble's right-click menu only shows that entry when
-- it has them, and the layout used to drop them, so the player's own messages
-- had no way to send the same text again.

local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local FakeUI = require("tests.helpers.fake_ui")
local LayoutMessages = require("tests.helpers.layout_messages")

return function()
  local savedCreateBubble = BubbleFrame.CreateBubble
  local capturedOptions, capturedMessage

  -- A bubble that only records what the layout passed in.
  BubbleFrame.CreateBubble = function(factory, parent, message, options)
    capturedMessage = message
    capturedOptions = options
    return { frame = factory.CreateFrame("Frame", nil, parent), height = 18, message = message }
  end

  local ok, err = pcall(function()
    local factory = FakeUI.NewFactory()
    local content = factory.CreateFrame("Frame", nil, nil)
    content:SetSize(400, 600)

    local message = { direction = "out", kind = "user", text = "Вот это не помню", sentAt = 1 }
    local onResend = function() end
    local canResend = function()
      return true
    end

    LayoutMessages(factory, content, { message }, 400, {
      onResend = onResend,
      canResend = canResend,
    })

    assert(capturedMessage == message, "the bubble should be built for the message")
    assert(capturedOptions ~= nil, "the bubble should receive its options")
    assert(capturedOptions.onResend == onResend, "the bubble needs the resend handler for its menu")
    assert(capturedOptions.canResend == canResend, "the bubble needs the resend check for its menu")
  end)

  BubbleFrame.CreateBubble = savedCreateBubble
  if not ok then
    error(err, 0)
  end
end
