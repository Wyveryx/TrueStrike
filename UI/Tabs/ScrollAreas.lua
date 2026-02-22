--[[
TrueStrike - Scroll Areas Tab
Purpose:
  Configure group/per-area runtime scroll settings and expose test harness controls.
Main responsibilities:
  - Edit area enablement, naming, font overrides, motion/justify/crit settings.
  - Toggle lock state used by runtime move/resize controls.
  - Trigger synthetic normal/crit entry tests and stop behavior.
Module interactions:
  - Persists settings through Core/DB accessors.
  - Calls UI/ScrollEngine refresh functions for immediate runtime updates.
  - Calls UI/TestHarness run/stop methods.
]]

local _, ns = ...
local TrueStrike = ns.TrueStrike

local function makeLabel(parent, text, point, rel, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint(point, rel, x, y)
  fs:SetText(text)
  return fs
end

local function makeButton(parent, text, w, h, point, rel, x, y)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, h)
  b:SetPoint(point, rel, x, y)
  b:SetText(text)
  return b
end

local function setupDropdown(dropdown, width, initializer)
  UIDropDownMenu_SetWidth(dropdown, width)
  UIDropDownMenu_Initialize(dropdown, initializer)
end

function TrueStrike:BuildScrollAreasTab()
  local panel = CreateFrame("Frame", nil, self.contentFrame)
  panel:SetAllPoints(self.contentFrame)
  self:RegisterTabPanel("ScrollAreas", panel)

  makeLabel(panel, "Scroll Areas", "TOPLEFT", panel, 18, -18):SetFontObject("GameFontHighlightLarge")

  local selector = CreateFrame("Frame", "TrueStrikeAreaSelectorDropdown", panel, "UIDropDownMenuTemplate")
  selector:SetPoint("TOPLEFT", panel, 14, -52)
  makeLabel(panel, "Edit target", "TOPLEFT", panel, 24, -70)
  TrueStrike.UI.AttachTooltip(selector, "Edit Target", {
    "Group mode applies to all enabled areas; per-area overrides take precedence.",
    "Choose Group, Area1, Area2, or Area3.",
  })

  local unlockToggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  unlockToggle:SetPoint("TOPLEFT", panel, 24, -104)
  unlockToggle.text:SetText("Unlock area move/resize handles")
  TrueStrike.UI.AttachTooltip(unlockToggle, "Unlock Handles", {
    "Global (applies to all areas).",
    "Shows drag handle and resize grip on runtime area frames.",
  })

  local enabledToggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  enabledToggle:SetPoint("TOPLEFT", panel, 24, -134)
  enabledToggle.text:SetText("Enabled")
  TrueStrike.UI.AttachTooltip(enabledToggle, "Enabled", {
    "Per-area (only this scroll area).",
    "In Group mode this toggles all enabled areas together.",
  })

  local nameBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  nameBox:SetSize(180, 24)
  nameBox:SetAutoFocus(false)
  nameBox:SetPoint("TOPLEFT", panel, 24, -166)
  TrueStrike.UI.AttachTooltip(nameBox, "Area Name", {
    "Per-area (only this scroll area).",
    "Press Enter to save a display name for the runtime frame.",
  })

  local overrideToggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  overrideToggle:SetPoint("TOPLEFT", panel, 24, -198)
  overrideToggle.text:SetText("Use per-area font override")
  TrueStrike.UI.AttachTooltip(overrideToggle, "Per-Area Font Override", {
    "Per-area (only this scroll area).",
    "When enabled, this area ignores Global master font settings.",
  })

  local fontDropdown = CreateFrame("Frame", "TrueStrikeAreaFontDropdown", panel, "UIDropDownMenuTemplate")
  fontDropdown:SetPoint("TOPLEFT", panel, 14, -224)
  TrueStrike.UI.AttachTooltip(fontDropdown, "Area Font", {
    "Per-area (only this scroll area).",
    "Requires per-area font override to be enabled.",
  })

  local fontSlider = CreateFrame("Slider", "TrueStrikeAreaFontSizeSlider", panel, "OptionsSliderTemplate")
  fontSlider:SetPoint("TOPLEFT", panel, 24, -272)
  fontSlider:SetWidth(220)
  fontSlider:SetMinMaxValues(8, 64)
  fontSlider:SetValueStep(1)
  _G[fontSlider:GetName() .. "Low"]:SetText("8")
  _G[fontSlider:GetName() .. "High"]:SetText("64")
  TrueStrike.UI.AttachTooltip(fontSlider, "Area Font Size", {
    "Per-area (only this scroll area).",
    "Requires per-area font override to be enabled.",
  })

  local colorBtn = makeButton(panel, "Area Font Color", 130, 24, "TOPLEFT", panel, 24, -334)
  TrueStrike.UI.AttachTooltip(colorBtn, "Area Font Color", {
    "Per-area (only this scroll area).",
    "Requires per-area font override to be enabled.",
  })

  local modeDD = CreateFrame("Frame", "TrueStrikeAreaModeDropdown", panel, "UIDropDownMenuTemplate")
  modeDD:SetPoint("TOPLEFT", panel, 292, -88)
  makeLabel(panel, "Scroll Mode", "TOPLEFT", panel, 302, -74)
  TrueStrike.UI.AttachTooltip(modeDD, "Scroll Mode", {
    "Per-area (only this scroll area).",
    "Select UP, DOWN, or PARABOLA motion path.",
  })

  local justifyDD = CreateFrame("Frame", "TrueStrikeAreaJustifyDropdown", panel, "UIDropDownMenuTemplate")
  justifyDD:SetPoint("TOPLEFT", panel, 292, -150)
  makeLabel(panel, "Justify", "TOPLEFT", panel, 302, -136)
  TrueStrike.UI.AttachTooltip(justifyDD, "Justify", {
    "Per-area (only this scroll area).",
    "Align entries left, center, or right inside the area.",
  })

  local critDD = CreateFrame("Frame", "TrueStrikeAreaCritEffectDropdown", panel, "UIDropDownMenuTemplate")
  critDD:SetPoint("TOPLEFT", panel, 292, -212)
  makeLabel(panel, "Crit Effect", "TOPLEFT", panel, 302, -198)
  TrueStrike.UI.AttachTooltip(critDD, "Crit Effect", {
    "Per-area (only this scroll area).",
    "Choose NONE, WIGGLE, POW, or FLASH for synthetic crit entries.",
  })

  local critSoundToggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  critSoundToggle:SetPoint("TOPLEFT", panel, 302, -254)
  critSoundToggle.text:SetText("Crit sound enabled")
  TrueStrike.UI.AttachTooltip(critSoundToggle, "Crit Sound Enabled", {
    "Per-area (only this scroll area).",
    "Requires Sound enabled in General.",
  })

  local soundDD = CreateFrame("Frame", "TrueStrikeAreaSoundDropdown", panel, "UIDropDownMenuTemplate")
  soundDD:SetPoint("TOPLEFT", panel, 292, -286)
  TrueStrike.UI.AttachTooltip(soundDD, "Crit Sound", {
    "Per-area (only this scroll area).",
    "Requires Sound enabled in General.",
  })

  local testNormal = makeButton(panel, "Test Normal", 110, 28, "BOTTOMLEFT", panel, 24, 24)
  local testCrit = makeButton(panel, "Test Crit", 110, 28, "LEFT", testNormal, "RIGHT", 8, 0)
  local stopBtn = makeButton(panel, "Stop", 110, 28, "LEFT", testCrit, "RIGHT", 8, 0)
  TrueStrike.UI.AttachTooltip(testNormal, "Test Normal", {
    "Spawns synthetic entries for UI testing only.",
    "Emits 10 non-crit events across all enabled areas.",
  })
  TrueStrike.UI.AttachTooltip(testCrit, "Test Crit", {
    "Spawns synthetic entries for UI testing only.",
    "Emits 10 crit events and triggers configured crit effects.",
  })
  TrueStrike.UI.AttachTooltip(stopBtn, "Stop Test", {
    "Stops synthetic test scheduling and clears active entries.",
  })

  local selection = "Group"

  local function getCurrentArea()
    local index = tonumber(selection:match("Area(%d)"))
    if index then return self:GetScrollAreaSettings(index), index end
    return nil, nil
  end

  -- Apply per-area changes or fan out group edits to all areas.
  local function apply(key, value)
    if selection == "Group" then
      self:ApplyGroupSetting(key, value)
    else
      local area = getCurrentArea()
      if area then area[key] = value end
    end
    self:RefreshAreaFrames()
  end

  setupDropdown(selector, 110, function(_, level)
    for _, item in ipairs({ "Group", "Area1", "Area2", "Area3" }) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = item
      info.value = item
      info.func = function(btn)
        selection = btn.value
        UIDropDownMenu_SetText(selector, selection)
        self:RefreshScrollAreasTab()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  setupDropdown(modeDD, 110, function(_, level)
    for _, opt in ipairs({ "UP", "DOWN", "PARABOLA" }) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = opt
      info.value = opt
      info.func = function(btn) apply("scrollMode", btn.value); self:RefreshScrollAreasTab() end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  setupDropdown(justifyDD, 110, function(_, level)
    for _, opt in ipairs({ "LEFT", "CENTER", "RIGHT" }) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = opt
      info.value = opt
      info.func = function(btn) apply("justify", btn.value); self:RefreshScrollAreasTab() end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  setupDropdown(critDD, 110, function(_, level)
    for _, opt in ipairs({ "NONE", "WIGGLE", "POW", "FLASH" }) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = opt
      info.value = opt
      info.func = function(btn) apply("critEffect", btn.value); self:RefreshScrollAreasTab() end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  setupDropdown(fontDropdown, 190, function(_, level)
    local lsmLocal = self:SafeGetLSM()
    if not lsmLocal then return end
    for _, key in ipairs(lsmLocal:List("font") or {}) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = key
      info.value = key
      info.func = function(btn)
        local area = getCurrentArea()
        if area then area.font = btn.value end
        UIDropDownMenu_SetText(fontDropdown, btn.value)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  setupDropdown(soundDD, 190, function(_, level)
    local lsmLocal = self:SafeGetLSM()
    if not lsmLocal then return end
    for _, key in ipairs(lsmLocal:List("sound") or {}) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = key
      info.value = key
      info.func = function(btn)
        local area = getCurrentArea()
        if area then area.critSoundKey = btn.value end
        UIDropDownMenu_SetText(soundDD, btn.value)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  unlockToggle:SetScript("OnClick", function(btn)
    self:GetAllScrollAreaSettings().unlocked = btn:GetChecked() and true or false
    self:RefreshAreaFrames()
  end)

  enabledToggle:SetScript("OnClick", function(btn)
    local checked = btn:GetChecked() and true or false
    if selection == "Group" then
      self:ForEachArea(function(_, area) area.enabled = checked end)
    else
      local area = getCurrentArea()
      if area then area.enabled = checked end
    end
    self:RefreshAreaFrames()
  end)

  nameBox:SetScript("OnEnterPressed", function(edit)
    local area = getCurrentArea()
    if area then
      area.name = edit:GetText()
      self:RefreshAreaFrames()
      self:RefreshScrollAreasTab()
    end
    edit:ClearFocus()
  end)

  overrideToggle:SetScript("OnClick", function(btn)
    local area = getCurrentArea()
    if area then
      area.useFontOverride = btn:GetChecked() and true or false
    end
    self:RefreshScrollAreasTab()
  end)

  fontSlider:SetScript("OnValueChanged", function(slider, value)
    local area = getCurrentArea()
    if area then
      local iv = math.floor(value + 0.5)
      area.fontSize = iv
      _G[slider:GetName() .. "Text"]:SetText("Area Font Size: " .. iv)
    end
  end)

  colorBtn:SetScript("OnClick", function()
    local area = getCurrentArea()
    if not area then return end

    local c = area.fontColor
    ColorPickerFrame:SetupColorPickerAndShow({
      r = c.r, g = c.g, b = c.b, opacity = 1 - c.a,
      hasOpacity = true,
      swatchFunc = function()
        local opacity = ColorPickerFrame:GetColorAlpha()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        c.r, c.g, c.b, c.a = r, g, b, 1 - opacity
      end,
      opacityFunc = function()
        local opacity = ColorPickerFrame:GetColorAlpha()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        c.r, c.g, c.b, c.a = r, g, b, 1 - opacity
      end,
      previousValues = { r = c.r, g = c.g, b = c.b, a = c.a },
      cancelFunc = function(prev)
        c.r, c.g, c.b, c.a = prev.r, prev.g, prev.b, prev.a
      end,
    })
  end)

  critSoundToggle:SetScript("OnClick", function(btn)
    apply("critSoundEnabled", btn:GetChecked() and true or false)
  end)

  testNormal:SetScript("OnClick", function() self:RunTestSequence(false) end)
  testCrit:SetScript("OnClick", function() self:RunTestSequence(true) end)
  stopBtn:SetScript("OnClick", function() self:StopTestSequence() end)

  function self:RefreshScrollAreasTab()
    local lsmLocal = self:SafeGetLSM()
    UIDropDownMenu_SetText(selector, selection)

    unlockToggle:SetChecked(self:GetAllScrollAreaSettings().unlocked)

    local area, index = getCurrentArea()
    if selection == "Group" then
      local first = self:GetScrollAreaSettings(1)
      enabledToggle:SetChecked(first.enabled)
      nameBox:SetText("Group edits apply to all enabled areas")
      nameBox:Disable()
      overrideToggle:SetChecked(false)
      overrideToggle:Disable()
      fontDropdown:EnableMouse(false)
      fontSlider:Disable()
      colorBtn:Disable()
      UIDropDownMenu_SetText(modeDD, self:GetAllScrollAreaSettings().group.scrollMode)
      UIDropDownMenu_SetText(justifyDD, self:GetAllScrollAreaSettings().group.justify)
      UIDropDownMenu_SetText(critDD, self:GetAllScrollAreaSettings().group.critEffect)
      critSoundToggle:SetChecked(self:GetAllScrollAreaSettings().group.critSoundEnabled)
      UIDropDownMenu_SetText(soundDD, self:GetAllScrollAreaSettings().group.critSoundKey)
    else
      enabledToggle:SetChecked(area.enabled)
      nameBox:Enable()
      nameBox:SetText(area.name)
      overrideToggle:Enable()
      overrideToggle:SetChecked(area.useFontOverride)

      local fontEnabled = lsmLocal and area.useFontOverride
      fontDropdown:EnableMouse(fontEnabled)
      fontSlider:SetEnabled(fontEnabled)
      colorBtn:SetEnabled(fontEnabled)
      UIDropDownMenu_SetText(fontDropdown, area.font)
      fontSlider:SetValue(area.fontSize)

      UIDropDownMenu_SetText(modeDD, area.scrollMode)
      UIDropDownMenu_SetText(justifyDD, area.justify)
      UIDropDownMenu_SetText(critDD, area.critEffect)
      critSoundToggle:SetChecked(area.critSoundEnabled)
      UIDropDownMenu_SetText(soundDD, area.critSoundKey)
    end

    soundDD:EnableMouse(lsmLocal ~= nil)
    if not lsmLocal then
      self:PrintMissingLSMOnce()
    end

    self:RefreshAreaFrames()

    if index and self.areaFrames and self.areaFrames[index] then
      self.areaFrames[index].label:SetText(area.name)
    end
  end
end
