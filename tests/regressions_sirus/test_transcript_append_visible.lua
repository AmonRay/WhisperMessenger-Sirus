local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local Rig = require("tests.regressions_sirus.ui_rig")

return function()
  -- test_append_while_open_at_end_binds_new_message
  do
    local messages = Rig.Messages(60)
    local view, _, contact, conversation = Rig.Create(600, 420, messages)
    view.frame:Show()
    Rig.Fire(view.frame, "OnUpdate", 0)
    local incoming = Rig.Messages(1)[1]
    incoming.sentAt = 61
    incoming.text = "brand new line"
    messages[#messages + 1] = incoming
    ConversationPane.Refresh(view, contact, conversation)
    assert(Rig.HasMessage(view.transcript, incoming), "appended message must be bound without scrolling")
    assert(math.abs(ScrollView.GetOffset(view.transcript) - ScrollView.GetRange(view.transcript)) <= 1, "appended message must settle at the end")
  end
end
