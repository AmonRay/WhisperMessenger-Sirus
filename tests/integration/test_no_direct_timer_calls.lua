local SCANNED_CALLS = { ".After(", ".NewTicker(", ".NewTimer(" }
local WRAPPER = "Core/WrathCompat/Timer.lua"

local function normalized(path)
  return (path:gsub("\\", "/"))
end

return function()
  local checked = 0
  for entry in io.lines("WhisperMessenger.toc") do
    if entry ~= "" and string.sub(entry, 1, 2) ~= "##" and not string.match(entry, "%.xml$") then
      local path = normalized(entry)
      if path ~= WRAPPER then
        local file = assert(io.open(path, "r"))
        local lineNumber = 0
        for line in file:lines() do
          lineNumber = lineNumber + 1
          local trimmed = string.match(line, "^%s*(.-)%s*$")
          if string.sub(trimmed, 1, 2) ~= "--" then
            for _, call in ipairs(SCANNED_CALLS) do
              local pattern = "%." .. string.sub(call, 2, -2):gsub("%%", "%%%%") .. "%("
              if string.find(line, pattern) then
                file:close()
                error(path .. ":" .. lineNumber .. " must schedule through Core/WrathCompat/Timer instead of calling the client timer directly", 0)
              end
            end
          end
        end
        file:close()
        checked = checked + 1
      end
    end
  end
  assert(checked > 400, "expected the TOC to list the addon files, checked " .. checked)
end
