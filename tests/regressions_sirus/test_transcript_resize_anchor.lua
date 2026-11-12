local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local Rig = require("tests.regressions_sirus.ui_rig")

local function firstVisible(transcript)
  local offset = ScrollView.GetOffset(transcript)
  for _, row in ipairs(transcript._virtualState.rows) do
    if row.offset + row.height > offset then
      return row.message, offset - row.offset
    end
  end
end

return function()
  -- test_width_reflow_preserves_reading_anchor_instead_of_jumping_to_end
  local messages = Rig.Messages(80)
  local view = Rig.Create(600, 420, messages)
  ScrollView.SetVerticalScroll(view.transcript, ScrollView.GetRange(view.transcript) * 0.4)
  local message, delta = firstVisible(view.transcript)
  assert(message ~= nil and message ~= messages[#messages], "setup: reading earlier history")
  view.frame:SetSize(360, 420)
  ConversationPane.Relayout(view, 360, 420)
  local after, afterDelta = firstVisible(view.transcript)
  assert(after == message, "reflow must keep the same message at the reading position")
  assert(math.abs(afterDelta - delta) <= 1, "reflow must keep the offset inside that message")

  -- test_width_reflow_keeps_end_pinned_when_already_reading_latest
  ScrollView.SetVerticalScroll(view.transcript, ScrollView.GetRange(view.transcript))
  view.frame:SetSize(500, 420)
  ConversationPane.Relayout(view, 500, 420)
  assert(math.abs(ScrollView.GetOffset(view.transcript) - ScrollView.GetRange(view.transcript)) <= 1, "latest history must stay pinned after width reflow")
  assert(Rig.HasMessage(view.transcript, messages[#messages]), "latest bubble must remain bound without extra scroll input")
end
