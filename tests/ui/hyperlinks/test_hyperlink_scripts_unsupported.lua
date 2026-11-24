-- The 3.3.5a client has no hyperlink scripts on plain frames, buttons or font
-- strings: SetScript raises "doesn't have a OnHyperlinkEnter script" there.
-- Building a surface that shows links must survive that, or the addon stops
-- halfway through startup (the minimap icon appears, the window never builds).
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")
  local frame = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
  local setScript = frame.SetScript
  frame.SetScript = function(self, name, handler)
    if string.match(name, "^OnHyperlink") then
      error('"' .. name .. '" is not a valid script for this frame', 2)
    end
    return setScript(self, name, handler)
  end

  local ok, err = pcall(Hyperlinks.EnableOn, frame, function() end)
  assert(ok, "EnableOn must survive a frame without hyperlink scripts, got: " .. tostring(err))
end
