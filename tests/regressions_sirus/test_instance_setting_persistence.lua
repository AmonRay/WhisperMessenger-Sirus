local Schema = require("WhisperMessenger.Persistence.Schema")
local Migrations = require("WhisperMessenger.Persistence.Migrations")

return function()
  -- test_new_account_defaults_to_unrestricted_messenger
  local fresh = Migrations.Apply(Schema.NewAccountState(), Schema)
  assert(type(fresh.settings) == "table", "account settings must contain the saved instance policy")
  assert(fresh.settings.blockChatInInstances == false, "new accounts must explicitly default to false")
  assert(fresh.blockChatInInstances == nil, "the policy must not be saved at account root")

  -- test_existing_settings_object_and_other_preferences_survive_migration
  for _, case in ipairs({ { value = false }, { value = true }, {}, { value = "true" }, { value = 1 }, { value = 0 }, { value = {} } }) do
    local settings = { blockChatInInstances = case.value, hideOnCombat = true, language = "ruRU" }
    local state = Schema.NewAccountState()
    state.settings = settings
    local result = Migrations.Apply(state, Schema)
    assert(result.settings == settings, "migration must reuse the existing settings object")
    assert(settings.hideOnCombat == true and settings.language == "ruRU", "other settings must remain intact")
    assert(settings.blockChatInInstances == (case.value == true), "missing policy defaults to false; explicit values survive")
    assert(Migrations.Apply(result, Schema).settings == settings, "repeated migration must preserve object identity")
    assert(settings.blockChatInInstances == (case.value == true), "repeated migration must preserve the policy")
  end
end
