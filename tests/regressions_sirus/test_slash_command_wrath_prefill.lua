local ChatPrefill = require("WhisperMessenger.Util.ChatPrefill")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local ManualCopyCapture = require("tests.helpers.manual_copy_capture")
local SlashCommand = require("WhisperMessenger.UI.Composer.SlashCommand")

-- The Sirus client (3.3.5a) still runs a protected command the player sends
-- from a chat box addon code prefilled, so it keeps that hand-off. Newer
-- clients block that Enter, and there the copy dialog is the only way.
return function()
  local saved = {
    DEFAULT_CHAT_FRAME = rawget(_G, "DEFAULT_CHAT_FRAME"),
    IsSecureCmd = rawget(_G, "IsSecureCmd"),
    hash_SlashCmdList = rawget(_G, "hash_SlashCmdList"),
    issecurevariable = rawget(_G, "issecurevariable"),
    SlashCmdList = rawget(_G, "SlashCmdList"),
  }
  local savedWrath = FlavorCompat.isWrath335

  local function fakeChatEditBox()
    local editBox = { text = "", ran = {} }
    function editBox:SetText(text)
      self.text = text
    end
    function editBox:GetText()
      return self.text
    end
    function editBox:GetScript(name)
      if name ~= "OnEnterPressed" then
        return nil
      end
      return function(box)
        table.insert(box.ran, box:GetText())
        box:SetText("")
      end
    end
    return editBox
  end

  local ok, err = pcall(function()
    local editBox = fakeChatEditBox()
    rawset(_G, "DEFAULT_CHAT_FRAME", { editBox = editBox })
    rawset(_G, "IsSecureCmd", function(command)
      return string.upper(command) == "/USE"
    end)
    rawset(_G, "SlashCmdList", {})

    -- test_wrath_client_prefills_a_protected_command_into_the_game_chat
    FlavorCompat.isWrath335 = true
    ManualCopyCapture.With(function(capture)
      local handled = SlashCommand.Run("/use Hearthstone")
      assert(handled == true, "the command must be handed off")
      assert(capture.count == 0, "3.3.5a keeps the chat hand-off, got a copy dialog")
    end)
    assert(editBox.ran[1] == "/use Hearthstone", "the chat box runs it, got " .. tostring(editBox.ran[1]))

    -- test_modern_client_still_shows_the_copy_dialog
    editBox.ran = {}
    editBox.text = ""
    FlavorCompat.isWrath335 = false
    ManualCopyCapture.With(function(capture)
      SlashCommand.Run("/use Hearthstone")
      assert(capture.count == 1 and capture.text == "/use Hearthstone", "newer clients get the copy dialog")
    end)
    assert(#editBox.ran == 0 and editBox.text == "", "newer clients never touch the chat box")

    -- test_wrath_client_treats_a_protected_command_as_safe_to_prefill
    -- (/ginvite from the contact list: prefill on 3.3.5a, copy dialog elsewhere)
    rawset(_G, "hash_SlashCmdList", { GINVITE = function() end })
    rawset(_G, "issecurevariable", function()
      return true
    end)
    rawset(_G, "IsSecureCmd", function(command)
      local key = string.upper(command)
      return key == "/USE" or key == "/GINVITE"
    end)
    FlavorCompat.isWrath335 = true
    assert(ChatPrefill.IsSafe("/ginvite Arthas") == true, "3.3.5a still prefills a protected command")
    FlavorCompat.isWrath335 = false
    assert(ChatPrefill.IsSafe("/ginvite Arthas") == false, "newer clients never prefill a protected command")
  end)

  FlavorCompat.isWrath335 = savedWrath
  for name, value in pairs(saved) do
    rawset(_G, name, value)
  end
  assert(ok, err)
end
