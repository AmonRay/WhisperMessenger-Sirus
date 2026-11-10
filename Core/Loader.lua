local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Loader = {}

function Loader.LoadModule(name, key)
  if ns[key] then
    return ns[key]
  end

  if type(require) == "function" then
    local ok, loaded = pcall(require, name)
    if ok then
      return loaded
    end
  end

  error(key .. " module not available")
end

local ADDON_FOLDER = "Interface\\AddOns\\WhisperMessenger\\"

local function moduleFile(name, addonToken)
  if type(name) ~= "string" then
    return nil
  end
  local prefix = addonToken .. "%."
  if string.find(name, prefix) ~= 1 then
    return nil
  end
  local relative = string.sub(name, string.len(addonToken) + 2)
  if relative == "" then
    return nil
  end
  return ADDON_FOLDER .. (string.gsub(relative, "%.", "\\")) .. ".lua"
end

function Loader.CreateRequire(env, addonToken, addonTable)
  env = env or _G
  local loaded = {}

  return function(name)
    if loaded[name] ~= nil then
      return loaded[name]
    end
    local path = moduleFile(name, addonToken)
    local chunk = path ~= nil and type(env.loadfile) == "function" and env.loadfile(path) or nil
    if type(chunk) ~= "function" then
      error("module not available: " .. tostring(name), 2)
    end
    local module = chunk(addonToken, addonTable)
    loaded[name] = module
    return module
  end
end

function Loader.InstallRequireShim(env, addonToken, addonTable)
  env = env or _G
  if type(env.require) == "function" then
    return false
  end
  env.require = Loader.CreateRequire(env, addonToken, addonTable or ns)
  return true
end

ns.Loader = Loader
rawset(_G, "WhisperMessengerLoader", Loader)

Loader.InstallRequireShim(_G, addonName, ns)

return Loader
