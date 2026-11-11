local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local DropdownSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")
local DropdownSkin = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSkin")
local FindUI = require("tests.helpers.find_ui")

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  for i = 1, 4 do
    if math.abs((actual[i] or 1) - (expected[i] or 1)) > 0.0001 then
      return false
    end
  end
  return true
end

local function newDropdown(factory)
  local parent = factory.CreateFrame("Frame", nil, nil)
  return DropdownSelector.Create(factory, parent, {
    labelText = "Font Family",
    optionsList = { { key = "default", label = "Default" }, { key = "b", label = "Other" } },
    fallbackKey = "default",
    initial = "default",
    rowWidth = 300,
  })
end

-- First closed-button texture painted with `color` (a rounded-surface fill).
local function fillColored(dd, color)
  local fill = FindUI.find(dd.button, function(node)
    return node.frameType == "Texture" and colorsMatch(node.color, color)
  end)
  return assert(fill, "no closed-button fill painted with the expected colour")
end

local function chevron(dd)
  local glyph = FindUI.find(dd.button, function(node)
    return node.texturePath == DropdownSkin.CHEVRON_TEXTURE
  end)
  return assert(glyph, "closed button has no chevron glyph")
end

local function rightInset(label)
  for _, pt in ipairs(label.points or {}) do
    if pt[1] == "RIGHT" then
      return pt[4]
    end
  end
  return nil
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()

  Theme.SetPreset("wow_default")

  -- test_modern_menu_is_opaque_and_above_sibling_rows
  -- The open list used the translucent option fill, so the rows below
  -- (font size slider, outline) showed through it.
  do
    local dd = newDropdown(factory)
    local menu = assert(FindUI.dropdownMenu(dd.row), "modern dropdown has a menu")
    local bg = FindUI.ofType(menu, "Texture")[1]
    assert(bg and type(bg.color) == "table", "menu has a painted background")
    assert((bg.color[4] or 1) >= 0.999, "open menu background must be opaque, alpha " .. tostring(bg.color[4]))
    assert(menu.frameStrata == "DIALOG", "open menu must sit above sibling rows, strata " .. tostring(menu.frameStrata))
    Theme.SetPreset("plumber_warm")
    dd.applyTheme(Theme)
    assert((bg.color[4] or 1) >= 0.999, "menu stays opaque after a theme change")
    Theme.SetPreset("wow_default")
  end

  -- test_open_menu_hangs_off_the_screen_root_above_every_row
  -- On 3.3.5a the list, still inside the settings scroll child, drew under
  -- the rows below it whatever strata it asked for. Open, it hangs off the
  -- screen root at the top dialog strata, as big as the scaled window, and a
  -- screen-wide catcher right under it closes it on an outside click.
  do
    local savedRoot = rawget(_G, "UIParent")
    local root = factory.CreateFrame("Frame", "UIParent", nil)
    rawset(_G, "UIParent", root)
    local window = factory.CreateFrame("Frame", nil, root)
    window:SetScale(1.25)
    local dd = DropdownSelector.Create(factory, window, {
      labelText = "Message Retention",
      optionsList = { { key = 1, label = "1 hour" }, { key = 2, label = "1 day" } },
      fallbackKey = 2,
      initial = 2,
      rowWidth = 300,
    })
    local menu = assert(FindUI.dropdownMenu(dd.row), "modern dropdown has a menu")
    FindUI.click(dd.button)
    assert(menu:IsShown(), "menu opens")
    assert(menu:GetParent() == root, "open menu hangs off the screen root")
    assert(menu.frameStrata == DropdownSelector.OPEN_STRATA, "open menu sits in the top dialog strata")
    assert(math.abs(menu:GetEffectiveScale() - dd.button:GetEffectiveScale()) < 0.0001, "open menu keeps the window scale")
    assert(#FindUI.dropdownOptions(dd.row) == 2, "options stay listed while open")
    local catcher = FindUI.find(root, function(node)
      return node.frameType == "Button" and node.allPoints == root and node.mouseEnabled == true
    end)
    assert(catcher and catcher:IsShown(), "screen-wide catcher shown under the open menu")
    assert(catcher.frameStrata == DropdownSelector.OPEN_STRATA, "catcher shares the menu strata")
    assert(catcher.frameLevel < menu.frameLevel, "catcher sits under the menu")
    FindUI.click(catcher)
    assert(not menu:IsShown(), "outside click closes the menu")
    assert(not catcher:IsShown(), "catcher hides with the menu")
    assert(menu:GetParent() == dd.row, "closed menu returns to its row")
    assert(menu:GetScale() == 1, "closed menu drops the lift scale")
    rawset(_G, "UIParent", savedRoot)
  end

  -- test_modern_dropdown_uses_input_surface
  do
    local dd = newDropdown(factory)
    local surfaceFill = fillColored(dd, Theme.COLORS.bg_input)
    assert(surfaceFill.shown == true, "rounded input surface shown")
  end

  -- test_modern_dropdown_has_down_chevron
  do
    local dd = newDropdown(factory)
    local glyph = chevron(dd)
    assert(glyph.shown == true, "chevron shown")
    assert(glyph.texturePath == DropdownSkin.CHEVRON_TEXTURE, "chevron reuses the back glyph")
    local tc = glyph.texCoords
    assert(tc and #tc == 8 and tc[1] == 1 and tc[2] == 0 and tc[3] == 0 and tc[4] == 0, "back glyph rotated to point down")
    assert(glyph.point[1] == "RIGHT", "chevron sits on the right")
    assert(colorsMatch(glyph.vertexColor, Theme.COLORS.text_secondary), "chevron rests secondary")
    local inset = rightInset(dd.button.label)
    assert(inset and inset <= -(DropdownSkin.CHEVRON_SIZE + 8), "label leaves room for the chevron")
  end

  -- test_modern_dropdown_hover_state
  do
    assert(not colorsMatch(Theme.COLORS.bg_input, Theme.COLORS.bg_contact_hover), "hover wash must differ from the surface")
    local dd = newDropdown(factory)
    local hoverFill = fillColored(dd, Theme.COLORS.bg_contact_hover)
    dd.button.scripts.OnEnter(dd.button)
    assert(hoverFill.shown == true, "hover wash shown")
    assert(colorsMatch(chevron(dd).vertexColor, Theme.COLORS.text_primary), "chevron brightens on hover")
    dd.button.scripts.OnLeave(dd.button)
    assert(hoverFill.shown ~= true, "hover wash hidden on leave")
    assert(colorsMatch(chevron(dd).vertexColor, Theme.COLORS.text_secondary), "chevron restores on leave")
  end

  local function newGrouped(changes)
    local parent = factory.CreateFrame("Frame", nil, nil)
    return DropdownSelector.Create(factory, parent, {
      labelText = "Notification sound",
      optionsList = {
        { header = true, label = "Group A" },
        { key = "a1", label = "A1" },
        { header = true, label = "Group B" },
        { key = "b1", label = "B1" },
      },
      fallbackKey = "missing",
      initial = "b1",
      onChange = function(key)
        changes.count = (changes.count or 0) + 1
        changes[#changes + 1] = key
      end,
    })
  end

  -- test_modern_dropdown_header_rows_are_not_choices
  do
    local changes = {}
    local dd = newGrouped(changes)
    local rows = FindUI.dropdownOptions(dd.row)
    assert(#rows == 4 and rows[3].label.text == "Group B", "header rows are listed in order")
    FindUI.click(rows[3])
    assert((changes.count or 0) == 0, "clicking a header picks nothing")
    assert(dd.button.label.text == "B1", "selection stays on the chosen sound")
  end

  -- test_modern_dropdown_headers_use_secondary_text
  do
    local dd = newGrouped({})
    local header = FindUI.dropdownOptions(dd.row)[1]
    header.scripts.OnEnter(header)
    assert(colorsMatch(header.label.textColor, Theme.COLORS.text_secondary), "header text stays secondary, even hovered")
  end

  -- test_hud_without_any_menu_api_keeps_the_modern_dropdown
  do
    local saved = rawget(_G, "MenuUtil")
    rawset(_G, "MenuUtil", nil)
    Hud.Configure("classic")
    local dd = newDropdown(FakeUI.NewFactory())
    Hud.Configure("off")
    rawset(_G, "MenuUtil", saved)
    assert(dd.button.template == nil, "no menu API: modern closed button")
    assert(FindUI.dropdownMenu(dd.row) ~= nil, "no menu API: custom menu")
  end

  -- test_modern_dropdown_ignores_the_blizzard_api
  do
    local base = FakeUI.NewFactory()
    local blizzardFactory = {
      CreateFrame = function(frameType, name, parent, template)
        local frame = base.CreateFrame(frameType, name, parent, template)
        if template == "WowStyle1DropdownTemplate" then
          function frame:SetupMenu() end
          function frame:GenerateMenu() end
        end
        return frame
      end,
    }
    local dd = newDropdown(blizzardFactory)
    assert(dd.button.template == nil, "modern: custom dropdown")
  end

  Theme.SetPreset(previousPreset)
  print("  All modern dropdown tests passed")
end
