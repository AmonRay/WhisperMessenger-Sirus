local ChatLinkHookUtil = require("WhisperMessenger.UI.Composer.ChatLinkHookUtil")

-- The game's own shift-click check: IsModifiedClick("CHATLINK"). 3.3.5a answers
-- 1 rather than true, so a strict comparison made every shift-click look plain.
return function()
  local saved = rawget(_G, "IsModifiedClick")

  -- test_missing_is_modified_click_is_not_a_chat_link_click
  rawset(_G, "IsModifiedClick", nil)
  assert(ChatLinkHookUtil.IsChatLinkClick() == false, "no IsModifiedClick is no chat-link click")

  -- test_the_clients_one_is_a_chat_link_click
  rawset(_G, "IsModifiedClick", function(action)
    return action == "CHATLINK" and 1 or nil
  end)
  assert(ChatLinkHookUtil.IsChatLinkClick() == true, "the client's 1 counts as shift-click")

  -- test_true_is_a_chat_link_click
  rawset(_G, "IsModifiedClick", function(action)
    return action == "CHATLINK" and true or nil
  end)
  assert(ChatLinkHookUtil.IsChatLinkClick() == true, "true counts as shift-click")

  -- test_a_plain_click_is_not_a_chat_link_click
  rawset(_G, "IsModifiedClick", function()
    return nil
  end)
  assert(ChatLinkHookUtil.IsChatLinkClick() == false, "a plain click is no chat-link click")

  -- test_zero_and_false_are_not_a_chat_link_click
  rawset(_G, "IsModifiedClick", function()
    return 0
  end)
  assert(ChatLinkHookUtil.IsChatLinkClick() == false, "0 is no chat-link click")
  rawset(_G, "IsModifiedClick", function()
    return false
  end)
  assert(ChatLinkHookUtil.IsChatLinkClick() == false, "false is no chat-link click")

  rawset(_G, "IsModifiedClick", saved)
end
