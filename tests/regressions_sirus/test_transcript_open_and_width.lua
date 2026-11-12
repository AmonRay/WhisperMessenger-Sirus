local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local Rig = require("tests.regressions_sirus.ui_rig")

return function()
  -- test_first_create_has_latest_history_without_any_scroll_input
  do
    local messages = Rig.Messages(60)
    local view = Rig.Create(600, 420, messages)
    view.frame:Show()
    Rig.Fire(view.frame, "OnUpdate", 0)
    assert(Rig.HasMessage(view.transcript, messages[#messages]), "first opening must bind a visible latest bubble without scrolling")
    assert(math.abs(ScrollView.GetOffset(view.transcript) - ScrollView.GetRange(view.transcript)) <= 1, "first opening must settle at history end")
  end

  -- test_reopen_with_unchanged_messages_restores_bubbles_without_scrolling
  do
    local messages = Rig.Messages(60)
    local view, _, contact, conversation = Rig.Create(600, 420, messages)
    view.frame:Hide()
    ConversationPane.Refresh(view, contact, conversation)
    view.frame:Show()
    Rig.Fire(view.frame, "OnUpdate", 0)
    assert(Rig.HasMessage(view.transcript, messages[#messages]), "reopening unchanged history must show messages without wheel input")
  end

  -- test_first_real_width_reflows_without_manual_window_resize
  do
    local messages = Rig.Messages(1)
    local view, parent = Rig.Create(0, 420, messages)
    parent:SetSize(600, 420)
    view.frame:SetSize(600, 420)
    Rig.Fire(view.frame, "OnSizeChanged", 600, 420)
    view.frame:Show()
    Rig.Fire(view.frame, "OnUpdate", 0)
    local settledWidth = view.transcript.scrollFrame:GetWidth()
    assert(settledWidth > 400, "the first real anchored width must replace the zero-width opening measurement")
    assert(Rig.HasMessage(view.transcript, messages[1]), "message must render after real width arrives without scrolling")
  end

  -- test_messages_received_while_hidden_appear_on_show_without_scroll
  do
    local messages = Rig.Messages(60)
    local view, _, contact, conversation = Rig.Create(600, 420, messages)
    view.frame:Hide()
    local incoming = Rig.Messages(1)[1]
    incoming.text = "Новое сообщение, пока окно скрыто :heart:"
    incoming.sentAt = 61
    messages[#messages + 1] = incoming
    ConversationPane.Refresh(view, contact, conversation)
    view.frame:Show()
    Rig.Fire(view.frame, "OnUpdate", 0)
    assert(Rig.HasMessage(view.transcript, incoming), "hidden incoming history must appear on show without wheel input")
  end

  -- test_repeated_layout_does_not_accumulate_height_or_hide_history
  do
    local messages = Rig.Messages(60)
    local view = Rig.Create(600, 420, messages)
    view.frame:SetSize(600, 420)
    ConversationPane.Relayout(view, 600, 420)
    local height = view.transcript.content:GetHeight()
    for _ = 1, 3 do
      ConversationPane.Relayout(view, 600, 420)
      assert(math.abs(view.transcript.content:GetHeight() - height) <= 1, "unchanged layout must not accumulate row height")
      assert(Rig.HasMessage(view.transcript, messages[#messages]), "repeat layout must retain visible latest history")
    end
  end

  -- test_width_only_change_remeasures_bubbles_even_when_height_is_unchanged
  do
    local messages = Rig.Messages(1)
    local view, parent = Rig.Create(600, 420, messages)
    view.frame:SetSize(600, 420)
    Rig.Fire(view.frame, "OnSizeChanged", 600, 420)
    Rig.Fire(view.frame, "OnUpdate", 0)
    local oldHeight = view.transcript._virtualState.rows[1].height
    parent:SetSize(300, 420)
    view.frame:SetSize(300, 420)
    Rig.Fire(view.frame, "OnSizeChanged", 300, 420)
    Rig.Fire(view.frame, "OnUpdate", 0)
    assert(view.transcript.scrollFrame:GetWidth() < 300, "same-height width change must resize the transcript")
    assert(view.transcript._virtualState.rows[1].height > oldHeight, "narrower text must reserve additional wrapped row height")
    assert(Rig.HasMessage(view.transcript, messages[1]), "width change must leave a visible message without scrolling")
  end
end
