-- The 3.3.5a client only understands its own interface number. A TOC that
-- carries the live retail number makes the client mark the addon out of date
-- (it then loads only with "Load out of date AddOns"), so the backport has to
-- keep 30300 as the base interface line.
return function()
  local interfaceLine = nil
  for line in io.lines("WhisperMessenger.toc") do
    if string.sub(line, 1, 14) == "## Interface: " then
      interfaceLine = line
      break
    end
  end

  assert(interfaceLine ~= nil, "the TOC must declare an Interface line")
  local value = string.match(interfaceLine, "^## Interface:%s*([0-9]+)")
  assert(value == "30300", "the base Interface line must be 30300 for 3.3.5a, got " .. tostring(value))
end
