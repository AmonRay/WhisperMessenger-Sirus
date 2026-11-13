local Localization = require("WhisperMessenger.Locale.Localization")
local ToggleSpecs = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings.ToggleSpecs")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

local function findSpec(specs, key)
  for _, spec in ipairs(specs) do
    if spec.key == key then
      return spec
    end
  end
  return nil
end

return function()
  local savedGetInstanceInfo = _G.GetInstanceInfo
  local ok, err = pcall(function()
    -- test_block_chat_setting_uses_symbolic_locale_keys
    Localization.Configure({ language = "enUS" })
    local english = findSpec(ToggleSpecs.Build({}, function() end), "blockChatInInstances")
    assert(english ~= nil, "Behavior settings must list the blockChatInInstances toggle")
    assert(english.labelKey == "BLOCK_CHAT_IN_INSTANCES", "toggle must use the BLOCK_CHAT_IN_INSTANCES locale key")
    assert(english.label == "Block chat in Mythic+, battlegrounds and arenas", "English label must not show the raw key")
    assert(
      english.tooltipLines[2] == Localization.ENGLISH.BLOCK_CHAT_IN_INSTANCES_TOOLTIP,
      "English tooltip must come from BLOCK_CHAT_IN_INSTANCES_TOOLTIP"
    )
    assert(english.initial == false, "setting must default to off")

    Localization.Configure({ language = "ruRU" })
    local russian = findSpec(ToggleSpecs.Build({ blockChatInInstances = true }, function() end), "blockChatInInstances")
    assert(russian.label ~= "BLOCK_CHAT_IN_INSTANCES" and russian.label:find("М+", 1, true), "Russian label must be translated")
    assert(russian.tooltipLines[2] ~= "BLOCK_CHAT_IN_INSTANCES_TOOLTIP", "Russian tooltip must be translated")
    assert(russian.initial == true, "strict true must show the toggle as on")
    assert(
      findSpec(ToggleSpecs.Build({ blockChatInInstances = "yes" }, function() end), "blockChatInInstances").initial == false,
      "only strict true enables the setting"
    )

    -- Unknown keys still pass through untouched.
    assert(Localization.Text("Some untranslated text") == "Some untranslated text")

    -- test_instance_probe_reads_type_and_difficulty_without_unused_locals
    _G.GetInstanceInfo = function()
      return "Arena", "arena", 0, 8
    end
    assert(RestrictedActions.InMythicInstance() == true, "difficulty 8 is the provisional M+ probe")
    assert(RestrictedActions.IsCompetitiveContent({ accountState = { settings = { blockChatInInstances = true } } }, nil) == true)
    assert(RestrictedActions.IsCompetitiveContent({ accountState = { settings = { blockChatInInstances = false } } }, nil) == false)
    assert(RestrictedActions.IsCompetitiveContent({ accountState = { settings = {} } }, nil) == false, "nil means off")
    _G.GetInstanceInfo = function()
      error("boom")
    end
    assert(RestrictedActions.InMythicInstance() == false, "an erroring API reads as outside M+")
    _G.GetInstanceInfo = nil
    assert(RestrictedActions.InMythicInstance() == false, "a missing API reads as outside M+")
  end)
  _G.GetInstanceInfo = savedGetInstanceInfo
  Localization.Configure({ language = "auto" })
  assert(ok, err)
end
