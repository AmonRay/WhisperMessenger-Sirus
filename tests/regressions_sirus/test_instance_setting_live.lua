local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

return function()
  local settings = {}
  local calls = 0
  local runtime = {
    store = { config = {} },
    syncInstanceChatPolicy = function()
      calls = calls + 1
      assert(type(settings.blockChatInInstances) == "boolean", "policy must be saved before synchronizing")
    end,
  }
  local change = SettingsHandler.Create({ runtime = runtime, accountSettings = settings })
  change("blockChatInInstances", true)
  assert(settings.blockChatInInstances == true and calls == 1, "enabling must synchronize immediately")
  change("blockChatInInstances", false)
  assert(settings.blockChatInInstances == false and calls == 2, "disabling must synchronize immediately")
  change("blockChatInInstances", "true")
  assert(settings.blockChatInInstances == false and calls == 3, "only boolean true enables the policy")
end
