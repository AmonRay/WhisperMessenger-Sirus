local FakeUI = require("tests.helpers.fake_ui")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local Rig = require("tests.regressions_sirus.ui_rig")

-- 3.3.5a with a scripted GetMouseFocus; both are restored afterwards.
local function onWrath(test)
  local savedWrath = FlavorCompat.isWrath335
  local savedFocus = rawget(_G, "GetMouseFocus")
  local pointer = { focus = nil }
  FlavorCompat.isWrath335 = true
  rawset(_G, "GetMouseFocus", function()
    return pointer.focus
  end)
  local ok, err = pcall(test, pointer)
  FlavorCompat.isWrath335 = savedWrath
  rawset(_G, "GetMouseFocus", savedFocus)
  if not ok then
    error(err, 0)
  end
end

local function newList(factory)
  local window = factory.CreateFrame("Frame", nil, nil)
  window:SetSize(300, 200)
  window:Show()
  local view = ScrollView.Create(factory, window, { width = 200, height = 100 })
  return window, view
end

-- One frame of the gate; whether the list takes the wheel afterwards.
local function tick(view)
  Rig.Fire(view.wheelGate, "OnUpdate", 0)
  return view.scrollFrame.mouseWheelEnabled
end

return function()
  -- test_cursor_on_the_list_scrolls_it
  onWrath(function(pointer)
    local factory = FakeUI.NewFactory()
    local window, view = newList(factory)
    assert(view.wheelGate ~= nil, "3.3.5a lists gate their wheel")
    local row = factory.CreateFrame("Button", nil, view.content)
    view.scrollFrame.mouseOver = true
    pointer.focus = row
    assert(tick(view) == true, "a row of the list under the cursor: the list scrolls")
    pointer.focus = window
    assert(tick(view) == true, "the messenger window under the cursor: the list scrolls")
    pointer.focus = nil
    assert(tick(view) == true, "nothing else under the cursor: the list keeps the wheel")
  end)

  -- test_window_over_the_list_keeps_the_wheel
  onWrath(function(pointer)
    local factory = FakeUI.NewFactory()
    local _, view = newList(factory)
    local bags = factory.CreateFrame("Frame", "OtherAddonBags", nil)
    local slot = factory.CreateFrame("Button", nil, bags)
    view.scrollFrame.mouseOver = true
    pointer.focus = slot
    assert(tick(view) == false, "another window over the messenger keeps the wheel")
  end)

  -- test_cursor_off_the_list_releases_the_wheel
  onWrath(function(pointer)
    local factory = FakeUI.NewFactory()
    local window, view = newList(factory)
    pointer.focus = window
    view.scrollFrame.mouseOver = true
    assert(tick(view) == true, "on the list: the wheel scrolls it")
    view.scrollFrame.mouseOver = false
    assert(tick(view) == false, "off the list: the wheel goes to the frame under the cursor")
  end)

  -- test_other_clients_keep_the_plain_wheel
  do
    local saved = FlavorCompat.isWrath335
    FlavorCompat.isWrath335 = false
    local ok, view = pcall(function()
      local _, created = newList(FakeUI.NewFactory())
      return created
    end)
    FlavorCompat.isWrath335 = saved
    assert(ok, tostring(view))
    assert(view.wheelGate == nil, "only 3.3.5a gates the wheel")
    assert(view.scrollFrame.mouseWheelEnabled == true, "the list takes the wheel as before")
  end
end
