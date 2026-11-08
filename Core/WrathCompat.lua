local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WrathCompat = {}

WrathCompat.WRATH_TOC = 30300

local installed = false

function WrathCompat.TocVersion(env)
  local getBuildInfo = env and env.GetBuildInfo
  if type(getBuildInfo) ~= "function" then
    return nil
  end
  local ok, _, _, _, tocVersion = pcall(getBuildInfo)
  if not ok or type(tocVersion) ~= "number" then
    return nil
  end
  return tocVersion
end

function WrathCompat.IsWrath335(env)
  env = env or _G
  if env.WOW_PROJECT_ID ~= nil then
    return false
  end
  local tocVersion = WrathCompat.TocVersion(env)
  return tocVersion ~= nil and tocVersion <= WrathCompat.WRATH_TOC
end

function WrathCompat.IsInstalled()
  return installed
end

function WrathCompat.Install(env, force)
  env = env or _G
  if installed and not force then
    return false
  end
  if not (force or WrathCompat.IsWrath335(env)) then
    return false
  end

  local modules = {
    ns.WrathCompatTimer,
    ns.WrathCompatChatInfo,
    ns.WrathCompatSocial,
    ns.WrathCompatWidgets,
  }
  for _, module in ipairs(modules) do
    if type(module) == "table" and type(module.Install) == "function" then
      module.Install(env)
    end
  end

  installed = true
  return true
end

ns.WrathCompat = WrathCompat

WrathCompat.Install(_G)

return WrathCompat
