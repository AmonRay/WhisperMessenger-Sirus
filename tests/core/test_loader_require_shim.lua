local Loader = require("WhisperMessenger.Core.Loader")

return function()
  -- test_require_shim_is_not_installed_when_the_client_has_one
  do
    local env = {
      require = function()
        return "client"
      end,
    }
    assert(Loader.InstallRequireShim(env, "WhisperMessenger", {}) == false, "an existing require must stay untouched")
    assert(env.require() == "client", "the client's require must keep working")
  end

  -- test_require_shim_loads_a_module_file_with_the_addon_table
  do
    local ns = {}
    local requested = {}
    local env = {
      loadfile = function(path)
        requested[#requested + 1] = path
        return function(addonName, addonTable)
          assert(addonName == "WhisperMessenger", "the module must receive the addon name")
          assert(addonTable == ns, "the module must receive the shared addon table")
          addonTable.WrathCompatSocial = { loaded = true }
          return addonTable.WrathCompatSocial
        end
      end,
    }

    assert(Loader.InstallRequireShim(env, "WhisperMessenger", ns) == true, "a client without require gets the shim")
    local module = env.require("WhisperMessenger.Core.WrathCompat.Social")
    assert(module ~= nil and module.loaded == true, "the shim must return what the module returns")
    assert(
      requested[1] == "Interface\\AddOns\\WhisperMessenger\\Core\\WrathCompat\\Social.lua",
      "expected the module path, got " .. tostring(requested[1])
    )

    env.require("WhisperMessenger.Core.WrathCompat.Social")
    assert(#requested == 1, "a module must be loaded once")
  end

  -- test_require_shim_rejects_unknown_modules
  do
    local env = {
      loadfile = function()
        return nil
      end,
    }
    Loader.InstallRequireShim(env, "WhisperMessenger", {})
    local ok = pcall(env.require, "WhisperMessenger.Missing.Module")
    assert(ok == false, "a missing module must raise")
    local okForeign = pcall(env.require, "SomeOtherAddon.Module")
    assert(okForeign == false, "the shim must not serve other addons")
  end
end
