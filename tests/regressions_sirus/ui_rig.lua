local FakeUI = require("tests.helpers.fake_ui")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")

local Rig = {}

-- FakeUI's default text height ignores wrapping. Add only a deterministic
-- FontString metric; production measurement and virtualization remain real.
function Rig.NewFactory()
  local factory = FakeUI.NewFactory()
  local createFrame = factory.CreateFrame
  factory.CreateFrame = function(...)
    local frame = createFrame(...)
    local createFontString = frame.CreateFontString
    frame.CreateFontString = function(self, ...)
      local fontString = createFontString(self, ...)
      fontString.GetStringHeight = function(target)
        local width = math.max(target:GetWidth(), 1)
        local text = tostring(target:GetText() or "")
        local lines = 0
        for line in (text .. "\n"):gmatch("(.-)\n") do
          lines = lines + math.max(1, math.ceil(#line * 7 / width))
        end
        return lines * 16
      end
      return fontString
    end
    return frame
  end
  return factory
end

function Rig.Fire(frame, event, ...)
  local script = frame.scripts and frame.scripts[event]
  if script then
    script(frame, ...)
  end
  for _, hook in ipairs(frame._hookScripts and frame._hookScripts[event] or {}) do
    hook(frame, ...)
  end
end

function Rig.Messages(count)
  local messages = {}
  for index = 1, count do
    messages[index] = {
      kind = "user",
      direction = "in",
      channel = "WOW",
      playerName = "Thrall",
      sentAt = index,
      text = "History " .. index .. ": " .. string.rep("wrapped message ", 12),
    }
  end
  return messages
end

function Rig.Create(width, height, messages)
  local factory = Rig.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(width, height)
  local contact = { displayName = "Thrall", conversationKey = "wow::WOW::thrall", channel = "WOW" }
  local conversation = { messages = messages }
  local view = ConversationPane.Create(factory, parent, contact, conversation)
  return view, parent, contact, conversation
end

function Rig.HasMessage(transcript, message)
  for _, frame in ipairs(transcript.content._activeFrames or {}) do
    if frame._wmMessage == message and frame:IsShown() and frame._textFS and frame._textFS:IsShown() then
      return true
    end
  end
  return false
end

return Rig
