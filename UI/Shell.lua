--[[
TrueStrike - Shell
Purpose:
  Build and manage the custom LCARS-like configuration shell.
Main responsibilities:
  - Construct the movable root frame and left-side navigation.
  - Swap tab content panels and persist active tab state to AceDB.
  - Wire high-level show/hide/toggle behavior used by slash commands.
Module interactions:
  - Tab modules call RegisterTabPanel during shell initialization.
  - Core/Slash invokes ToggleShell/ShowShell/HideShell.
  - UI/Tooltip helper provides consistent tooltips for nav controls.
]]

local _, ns = ...
local TrueStrike = ns.TrueStrike

local TAB_ORDER = {
  "General",
  "ScrollAreas",
  "Incoming",
  "Outgoing",
  "Features",
  "Diagnostics",
}

local TAB_TOOLTIPS = {
  General = {
    "Global (applies to all areas).",
    "Configure master font, sound, and profile operations.",
  },
  ScrollAreas = {
    "Group mode applies to all enabled areas; per-area overrides take precedence.",
    "Configure placement, motion paths, crit effects, and test controls.",
  },
  Incoming = {
    "Placeholder tab for future incoming features.",
    "Not implemented in UI shell milestone.",
  },
  Outgoing = {
    "Placeholder tab for future outgoing features.",
    "Not implemented in UI shell milestone.",
  },
  Features = {
    "Placeholder tab for feature roadmap controls.",
    "Not implemented in UI shell milestone.",
  },
  Diagnostics = {
    "Placeholder tab for diagnostics tools.",
    "Not implemented in UI shell milestone.",
  },
}

function TrueStrike:InitializeShell()
  if self.shell then return end

  -- Root shell container.
  local shell = CreateFrame("Frame", "TrueStrikeShell", UIParent, "BackdropTemplate")
  shell:SetSize(980, 620)
  shell:SetPoint("CENTER")
  shell:SetMovable(true)
  shell:EnableMouse(true)
  shell:RegisterForDrag("LeftButton")
  shell:SetScript("OnDragStart", shell.StartMoving)
  shell:SetScript("OnDragStop", shell.StopMovingOrSizing)
  shell:SetFrameStrata("DIALOG")
  shell:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Buttons/WHITE8x8",
    edgeSize = 2,
  })
  shell:SetBackdropColor(0.04, 0.05, 0.09, 0.97)
  shell:SetBackdropBorderColor(0.92, 0.46, 0.2, 0.95)
  shell:Hide()

  local title = shell:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", 28, -22)
  title:SetText("TRUESTRIKE // LCARS CONTROL")


  local headerBar = CreateFrame("Frame", nil, shell, "BackdropTemplate")
  headerBar:SetPoint("TOPLEFT", 12, -12)
  headerBar:SetPoint("TOPRIGHT", -54, -12)
  headerBar:SetHeight(34)
  headerBar:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
  headerBar:SetBackdropColor(0.92, 0.46, 0.2, 0.95)

  local navSpine = CreateFrame("Frame", nil, shell, "BackdropTemplate")
  navSpine:SetPoint("TOPLEFT", 12, -52)
  navSpine:SetPoint("BOTTOMLEFT", 12, 12)
  navSpine:SetWidth(24)
  navSpine:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
  navSpine:SetBackdropColor(0.81, 0.36, 0.62, 0.92)

  local close = CreateFrame("Button", nil, shell, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -8, -8)
  TrueStrike.UI.AttachTooltip(close, "Close", {
    "Close the TrueStrike shell.",
  })

  local nav = CreateFrame("Frame", nil, shell, "BackdropTemplate")
  nav:SetPoint("TOPLEFT", 40, -56)
  nav:SetPoint("BOTTOMLEFT", 40, 12)
  nav:SetWidth(214)
  nav:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
  nav:SetBackdropColor(0.12, 0.1, 0.17, 0.95)

  local content = CreateFrame("Frame", nil, shell, "BackdropTemplate")
  content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 16, 0)
  content:SetPoint("BOTTOMRIGHT", -14, 12)
  content:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
  content:SetBackdropColor(0.02, 0.03, 0.06, 0.94)

  self.shell = shell
  self.navFrame = nav
  self.contentFrame = content
  self.tabButtons = {}
  self.tabPanels = {}

  -- Build left nav and attach hover + click interactions.
  for idx, tabName in ipairs(TAB_ORDER) do
    local btn = CreateFrame("Button", nil, nav, "BackdropTemplate")
    btn:SetSize(188, 46)
    btn:SetPoint("TOP", 0, -14 - (idx - 1) * 52)
    btn:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
    btn:SetBackdropColor(0.23, 0.13, 0.24, 0.96)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.label:SetPoint("CENTER")
    btn.label:SetText(tabName)

    btn:SetScript("OnEnter", function()
      if self.activeTab ~= tabName then
        btn:SetBackdropColor(0.92, 0.46, 0.2, 0.95)
      end
    end)

    btn:SetScript("OnLeave", function()
      self:UpdateTabButtonState(tabName)
    end)

    btn:SetScript("OnClick", function()
      self:SetActiveTab(tabName)
    end)

    TrueStrike.UI.AttachTooltip(btn, tabName, TAB_TOOLTIPS[tabName])
    self.tabButtons[tabName] = btn
  end

  -- Build all tab panels once, then swap visibility by active tab.
  self:BuildGeneralTab()
  self:BuildScrollAreasTab()
  self:BuildIncomingTab()
  self:BuildOutgoingTab()
  self:BuildFeaturesTab()
  self:BuildDiagnosticsTab()

  local wantedTab = self:GetProfile().lastActiveMainTab or "General"
  self:SetActiveTab(wantedTab)
end

-- Keep nav button visuals synchronized with active tab selection.
function TrueStrike:UpdateTabButtonState(tabName)
  local btn = self.tabButtons[tabName]
  if not btn then return end

  if self.activeTab == tabName then
    btn:SetBackdropColor(0.95, 0.63, 0.24, 0.98)
  else
    btn:SetBackdropColor(0.23, 0.13, 0.24, 0.96)
  end
end

function TrueStrike:RegisterTabPanel(tabName, panel)
  panel:Hide()
  self.tabPanels[tabName] = panel
end

-- Swap active panel, persist tab key, and refresh panel-specific controls.
function TrueStrike:SetActiveTab(tabName)
  if not self.tabPanels[tabName] then
    tabName = "General"
  end

  for key, panel in pairs(self.tabPanels) do
    panel:SetShown(key == tabName)
  end

  self.activeTab = tabName
  self:GetProfile().lastActiveMainTab = tabName

  for key in pairs(self.tabButtons) do
    self:UpdateTabButtonState(key)
  end

  if tabName == "General" and self.RefreshGeneralTab then
    self:RefreshGeneralTab()
  elseif tabName == "ScrollAreas" and self.RefreshScrollAreasTab then
    self:RefreshScrollAreasTab()
  end
end

function TrueStrike:ToggleShell()
  if not self.shell then return end
  if self.shell:IsShown() then
    self:HideShell()
  else
    self:ShowShell()
  end
end

function TrueStrike:ShowShell()
  if not self.shell then return end
  self.shell:Show()
  self:SetActiveTab(self:GetProfile().lastActiveMainTab)
end

function TrueStrike:HideShell()
  if self.shell then
    self.shell:Hide()
  end
end
