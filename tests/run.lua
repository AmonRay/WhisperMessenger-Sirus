package.path = table.concat({
  "./?.lua",
  "./?/init.lua",
  package.path,
}, ";")

local rawLoadfile, rawDofile = loadfile, dofile
local function portablePath(path)
  if type(path) == "string" then
    return (string.gsub(path, "\\", "/"))
  end
  return path
end
loadfile = function(path, ...)
  return rawLoadfile(portablePath(path), ...)
end
dofile = function(path)
  return rawDofile(portablePath(path))
end
_G.loadfile, _G.dofile = loadfile, dofile

local rawRequire = require

local function normalizeModuleName(name)
  if type(name) == "string" and string.find(name, "WhisperMessenger.", 1, true) == 1 then
    return string.sub(name, string.len("WhisperMessenger.") + 1)
  end

  return name
end

require = function(name)
  return rawRequire(normalizeModuleName(name))
end
_G.require = require

local path = ...
assert(path, "expected a test file path")

local ok, testFn = pcall(dofile, path)
if not ok then
  error(testFn)
end

if type(testFn) == "function" then
  testFn()
end

print("PASS " .. path)
