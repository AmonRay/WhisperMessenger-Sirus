local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Hyperlinks = ns.UIHyperlinks or require("WhisperMessenger.UI.Hyperlinks")
local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")

-- On 3.3.5a a plain Frame (and an EditBox) never fires OnHyperlink* scripts
-- for the links in its FontStrings; only SimpleHTML and ScrollingMessageFrame
-- do. A bubble there gets a SimpleHTML twin over its text: the twin draws the
-- text and takes the link hover and clicks, while the FontString stays for
-- measuring (hidden by alpha). Shown only for text that has links.
local LinkOverlay = {}

-- Mouse scripts the twin hands on to the bubble, so the bubble's own
-- clicks (context menu, reveal) and hover still work over the text.
local FORWARDED_SCRIPTS = { "OnMouseDown", "OnMouseUp", "OnEnter", "OnLeave" }

function LinkOverlay.IsNeeded(frame)
  if type(frame) ~= "table" then
    return false
  end
  return FlavorCompat.isWrath335 == true or type(frame.SetHyperlinksEnabled) ~= "function"
end

local function call(widget, method, ...)
  if widget ~= nil and type(widget[method]) == "function" then
    return pcall(widget[method], widget, ...)
  end
  return false
end

-- Creates the twin once per bubble (cached on frame._linkHTML). Returns it,
-- or nil when the client fires link scripts on plain frames anyway.
function LinkOverlay.Attach(factory, frame)
  if frame == nil or frame._linkHTML ~= nil then
    return frame and frame._linkHTML or nil
  end
  if not LinkOverlay.IsNeeded(frame) then
    return nil
  end
  local create = (type(factory) == "table" and factory.CreateFrame) or rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, html = pcall(create, "SimpleHTML", nil, frame)
  if not ok or type(html) ~= "table" then
    return nil
  end

  call(html, "EnableMouse", true)
  Hyperlinks.SetScriptIfSupported(html, "OnHyperlinkEnter", function(self, link)
    Hyperlinks.HandleEnter(self, link)
  end)
  Hyperlinks.SetScriptIfSupported(html, "OnHyperlinkLeave", function()
    Hyperlinks.HandleLeave()
  end)
  Hyperlinks.BindClick(html)
  for _, scriptName in ipairs(FORWARDED_SCRIPTS) do
    Hyperlinks.SetScriptIfSupported(html, scriptName, function(_, ...)
      local handler = type(frame.GetScript) == "function" and frame:GetScript(scriptName) or nil
      if type(handler) == "function" then
        return handler(frame, ...)
      end
    end)
  end
  call(html, "Hide")

  frame._linkHTML = html
  return html
end

local function hasLink(text)
  return type(text) == "string" and string.find(text, "|H", 1, true) ~= nil
end

-- After the FontString got its text, width and anchor: mirrors them on the
-- twin, or hides the twin when the text has no links.
function LinkOverlay.Sync(frame, fontString, text)
  local html = frame and frame._linkHTML or nil
  if html == nil or fontString == nil then
    return false
  end
  if not hasLink(text) then
    call(html, "Hide")
    call(fontString, "SetAlpha", 1)
    return false
  end

  -- SimpleHTML needs a font before SetText.
  local fontSet = false
  if type(fontString.GetFont) == "function" then
    local okFont, font, size, flags = pcall(fontString.GetFont, fontString)
    if okFont and font then
      fontSet = call(html, "SetFont", font, size, flags or "")
    end
  end
  if not fontSet and type(fontString.GetFontObject) == "function" then
    local okObject, fontObject = pcall(fontString.GetFontObject, fontString)
    if okObject and fontObject then
      fontSet = call(html, "SetFontObject", fontObject)
    end
  end
  if not fontSet then
    call(html, "SetFontObject", rawget(_G, "ChatFontNormal") or rawget(_G, "GameFontHighlight"))
  end
  if type(fontString.GetTextColor) == "function" then
    call(html, "SetTextColor", fontString:GetTextColor())
  end

  local width = type(fontString.GetWidth) == "function" and fontString:GetWidth() or nil
  local height = type(fontString.GetStringHeight) == "function" and fontString:GetStringHeight() or nil
  if width and width > 0 then
    call(html, "SetWidth", width)
  end
  if height and height > 0 then
    call(html, "SetHeight", height)
  end
  call(html, "ClearAllPoints")
  call(html, "SetPoint", "TOPLEFT", fontString, "TOPLEFT", 0, 0)

  if not call(html, "SetText", text) then
    -- Could not render: keep the plain (unclickable) text visible.
    call(html, "Hide")
    call(fontString, "SetAlpha", 1)
    return false
  end
  call(html, "Show")
  call(fontString, "SetAlpha", 0)
  return true
end

ns.ChatBubbleLinkOverlay = LinkOverlay
return LinkOverlay
