-- TrueStrike General Tab
-- Master settings and AceDB profile operations.

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

function TrueStrike:BuildGeneralTab()
  local panel = CreateFrame("Frame", nil, self.contentFrame)
  panel:SetAllPoints(self.contentFrame)
  self:RegisterTabPanel("General", panel)

  makeLabel(panel, "General", "TOPLEFT", panel, 18, -18):SetFontObject("GameFontHighlightLarge")

  local lsm = self:SafeGetLSM()
  if not lsm then
    self:PrintMissingLSMOnce()
  end

  makeLabel(panel, "Master Font", "TOPLEFT", panel, 24, -72)
  local fontDropdown = CreateFrame("Frame", "TrueStrikeGeneralFontDropdown", panel, "UIDropDownMenuTemplate")
  fontDropdown:SetPoint("TOPLEFT", panel, 14, -88)

  makeLabel(panel, "Master Font Size", "TOPLEFT", panel, 24, -136)
  local sizeSlider = CreateFrame("Slider", "TrueStrikeMasterFontSizeSlider", panel, "OptionsSliderTemplate")
  sizeSlider:SetPoint("TOPLEFT", panel, 24, -152)
  sizeSlider:SetWidth(260)
  sizeSlider:SetMinMaxValues(8, 64)
  sizeSlider:SetValueStep(1)
  _G[sizeSlider:GetName() .. "Low"]:SetText("8")
  _G[sizeSlider:GetName() .. "High"]:SetText("64")

  local colorButton = makeButton(panel, "Master Font Color", 140, 24, "TOPLEFT", panel, 24, -224)

  local disableFCT = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  disableFCT:SetPoint("TOPLEFT", panel, 24, -264)
  disableFCT.text:SetText("Disable Blizzard floating combat text (store only)")

  local enableSound = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  enableSound:SetPoint("TOPLEFT", panel, 24, -294)
  enableSound.text:SetText("Enable sound")

  makeLabel(panel, "Profiles", "TOPLEFT", panel, 24, -340):SetFontObject("GameFontHighlight")

  local newBtn = makeButton(panel, "New", 84, 24, "TOPLEFT", panel, 24, -364)
  local copyBtn = makeButton(panel, "Copy From", 84, 24, "TOPLEFT", newBtn, "TOPRIGHT", 8, 0)
  local resetBtn = makeButton(panel, "Reset", 84, 24, "TOPLEFT", copyBtn, "TOPRIGHT", 8, 0)
  local delBtn = makeButton(panel, "Delete", 84, 24, "TOPLEFT", resetBtn, "TOPRIGHT", 8, 0)

  panel.widgets = {
    fontDropdown = fontDropdown,
    sizeSlider = sizeSlider,
    colorButton = colorButton,
    disableFCT = disableFCT,
    enableSound = enableSound,
  }

  UIDropDownMenu_SetWidth(fontDropdown, 230)
  UIDropDownMenu_Initialize(fontDropdown, function(_, level)
    local lsmLocal = self:SafeGetLSM()
    if not lsmLocal then return end

    for _, key in ipairs(lsmLocal:List("font") or {}) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = key
      info.value = key
      info.func = function(btn)
        self:GetGeneralSettings().masterFont = btn.value
        UIDropDownMenu_SetText(fontDropdown, btn.value)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  sizeSlider:SetScript("OnValueChanged", function(slider, value)
    local iv = math.floor(value + 0.5)
    self:GetGeneralSettings().masterFontSize = iv
    _G[slider:GetName() .. "Text"]:SetText("Master Font Size: " .. iv)
  end)

  colorButton:SetScript("OnClick", function()
    local color = self:GetGeneralSettings().masterFontColor
    local function setColor(new)
      color.r, color.g, color.b, color.a = new.r, new.g, new.b, new.a
    end
    ColorPickerFrame:SetupColorPickerAndShow({
      r = color.r, g = color.g, b = color.b, opacity = 1 - color.a,
      hasOpacity = true,
      swatchFunc = function()
        local info = ColorPickerFrame:GetColorAlpha()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        setColor({ r = r, g = g, b = b, a = 1 - info })
      end,
      opacityFunc = function()
        local info = ColorPickerFrame:GetColorAlpha()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        setColor({ r = r, g = g, b = b, a = 1 - info })
      end,
      cancelFunc = function(previous)
        setColor({ r = previous.r, g = previous.g, b = previous.b, a = previous.a })
      end,
      previousValues = { r = color.r, g = color.g, b = color.b, a = color.a },
    })
  end)

  disableFCT:SetScript("OnClick", function(btn)
    self:GetGeneralSettings().disableBlizzardFCT = btn:GetChecked() and true or false
  end)

  enableSound:SetScript("OnClick", function(btn)
    self:GetGeneralSettings().enableSound = btn:GetChecked() and true or false
  end)

  local function promptProfile(titleText, acceptText, callback)
    StaticPopupDialogs["TRUESTRIKE_PROFILE_INPUT"] = {
      text = titleText,
      button1 = acceptText,
      button2 = CANCEL,
      hasEditBox = true,
      editBoxWidth = 220,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      OnAccept = function(dialog)
        local name = dialog.editBox:GetText()
        if name and name ~= "" then callback(name) end
      end,
    }
    StaticPopup_Show("TRUESTRIKE_PROFILE_INPUT")
  end

  newBtn:SetScript("OnClick", function()
    promptProfile("Create profile", "Create", function(name)
      self.db:SetProfile(name)
      self:RefreshAfterDbChange()
    end)
  end)

  copyBtn:SetScript("OnClick", function()
    promptProfile("Copy from profile name", "Copy", function(name)
      local profiles = self.db:GetProfiles()
      for _, p in ipairs(profiles) do
        if p == name then
          self.db:CopyProfile(name)
          self:RefreshAfterDbChange()
          return
        end
      end
      self:Print("Profile not found: " .. name)
    end)
  end)

  resetBtn:SetScript("OnClick", function()
    self.db:ResetProfile()
    self:RefreshAfterDbChange()
  end)

  delBtn:SetScript("OnClick", function()
    promptProfile("Delete profile", "Delete", function(name)
      if self.db:GetCurrentProfile() == name then
        self:Print("Cannot delete the active profile.")
        return
      end
      self.db:DeleteProfile(name, true)
      self:RefreshAfterDbChange()
    end)
  end)

  function self:RefreshGeneralTab()
    if not panel:IsShown() and self.activeTab ~= "General" then return end

    local settings = self:GetGeneralSettings()
    UIDropDownMenu_SetText(fontDropdown, settings.masterFont or "Unavailable")
    fontDropdown:EnableMouse(lsm ~= nil)

    sizeSlider:SetValue(settings.masterFontSize or 24)
    disableFCT:SetChecked(settings.disableBlizzardFCT)
    enableSound:SetChecked(settings.enableSound)
  end
end
