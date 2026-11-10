local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

-- On 3.3.5a a dual-anchored pane resolves its rect lazily: while the window
-- shrinks, the pane can still report its old, taller height, so the
-- transcript got sized past the composer and bubbles drew outside the
-- window. Once the pane's real size lands (OnSizeChanged) the transcript
-- must be re-fitted to it.

local PANE_W, OLD_H, NEW_H = 600, 420, 260

local function newPane(factory)
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(PANE_W, OLD_H)
  local view = ConversationPane.Create(factory, parent, { displayName = "Arthas" }, { messages = {} })
  view.frame:SetSize(PANE_W, OLD_H)
  ConversationPane.Relayout(view, PANE_W, OLD_H)
  return view
end

local function fireSizeChanged(frame, width, height)
  if frame.scripts and frame.scripts.OnSizeChanged then
    frame.scripts.OnSizeChanged(frame, width, height)
  end
  local hooks = frame._hookScripts and frame._hookScripts.OnSizeChanged or {}
  for _, hook in ipairs(hooks) do
    hook(frame, width, height)
  end
end

local function transcriptH(view)
  return view.transcript.scrollFrame:GetHeight()
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_shrink_refits_transcript_when_real_pane_height_lands
  do
    local view = newPane(factory)
    -- The window commits the smaller size, but the pane still reads stale.
    ConversationPane.Relayout(view, PANE_W, NEW_H)
    assert(transcriptH(view) > NEW_H - Theme.HeaderHeight(), "precondition: stale pane height oversizes the transcript")

    view.frame:SetSize(PANE_W, NEW_H)
    fireSizeChanged(view.frame, PANE_W, NEW_H)

    local limit = NEW_H - Theme.HeaderHeight()
    assert(
      transcriptH(view) <= limit,
      "transcript must shrink to the pane's real height, got " .. tostring(transcriptH(view)) .. " > " .. tostring(limit)
    )
  end

  -- test_size_change_without_height_change_does_not_relayout
  do
    local view = newPane(factory)
    local calls = 0
    local original = ConversationPane.RenderTranscript
    local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")
    local originalRender = TranscriptView.RenderTranscript
    TranscriptView.RenderTranscript = function(...)
      calls = calls + 1
      return originalRender(...)
    end
    local ok, err = pcall(fireSizeChanged, view.frame, PANE_W, OLD_H)
    TranscriptView.RenderTranscript = originalRender
    ConversationPane.RenderTranscript = original
    assert(ok, err)
    assert(calls == 0, "an unchanged pane height must not re-render the transcript")
  end
end
