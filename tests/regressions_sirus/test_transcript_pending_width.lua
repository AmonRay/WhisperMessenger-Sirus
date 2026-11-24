local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")

-- On 3.3.5a a chat opened mid-layout can be rendered while its scroll frame
-- still reports width 0. That render is deferred, and it used to stay deferred
-- until the player scrolled, leaving an empty pane above existing history.
-- It must retry by itself once the frame has a width.

local function messages()
  local list = {}
  for index = 1, 20 do
    list[index] = {
      direction = "in",
      kind = "user",
      playerName = "Lyndaa",
      sentAt = index,
      text = "message " .. index,
    }
  end
  return list
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 120)
  local transcript = ScrollView.Create(factory, parent, { width = 400, height = 120, step = TranscriptView.TRANSCRIPT_SCROLL_STEP })
  transcript.factory = factory
  TranscriptSetup.ConfigureTranscript(factory, transcript, 400)

  -- The frame has no width yet, then settles a couple of calls later.
  local widthCalls = 0
  transcript.scrollFrame.GetWidth = function()
    widthCalls = widthCalls + 1
    return widthCalls > 2 and 400 or 0
  end

  TranscriptView.RenderTranscript(transcript, messages())

  assert(transcript._virtualState ~= nil, "the deferred render must retry until the scroll frame has a width")
  assert(transcript._virtualState.firstIndex ~= nil, "the retried render must bind visible rows")
  assert(transcript._renderPendingWidth ~= true, "the pending-width flag must be cleared after the retry")
end
