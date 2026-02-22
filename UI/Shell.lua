-- TrueStrike Shell
-- Custom LCARS-like shell with left navigation and swappable content panels.

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

function TrueStrike:InitializeShell()
  if self.shell then return end

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
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 14,
  })
  shell:SetBackdropColor(0.05, 0.07, 0.12, 0.95)
  shell:SetBackdropBorderColor(0.18, 0.62, 1, 1)
  shell:Hide()

  local title = shell:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("TrueStrike UI Shell")

  local close = CreateFrame("Button", nil, shell, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -8, -8)

  local nav = CreateFrame("Frame", nil, shell, "BackdropTemplate")
  nav:SetPoint("TOPLEFT", 12, -44)
  nav:SetPoint("BOTTOMLEFT", 12, 12)
  nav:SetWidth(190)
  nav:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
  nav:SetBackdropColor(0.08, 0.11, 0.17, 0.95)

  local content = CreateFrame("Frame", nil, shell, "BackdropTemplate")
  content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 10, 0)
  content:SetPoint("BOTTOMRIGHT", -12, 12)
  content:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
  content:SetBackdropColor(0.03, 0.04, 0.08, 0.92)

  self.shell = shell
  self.navFrame = nav
  self.contentFrame = content
  self.tabButtons = {}
  self.tabPanels = {}

  for idx, tabName in ipairs(TAB_ORDER) do
    local btn = CreateFrame("Button", nil, nav, "BackdropTemplate")
    btn:SetSize(170, 42)
    btn:SetPoint("TOP", 0, -12 - (idx - 1) * 48)
    btn:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
    btn:SetBackdropColor(0.14, 0.16, 0.22, 0.95)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.label:SetPoint("CENTER")
    btn.label:SetText(tabName)

    btn:SetScript("OnEnter", function()
      if self.activeTab ~= tabName then
        btn:SetBackdropColor(0.22, 0.27, 0.38, 0.95)
      end
    end)

    btn:SetScript("OnLeave", function()
      self:UpdateTabButtonState(tabName)
    end)

    btn:SetScript("OnClick", function()
      self:SetActiveTab(tabName)
    end)

    self.tabButtons[tabName] = btn
  end

  self:BuildGeneralTab()
  self:BuildScrollAreasTab()
  self:BuildIncomingTab()
  self:BuildOutgoingTab()
  self:BuildFeaturesTab()
  self:BuildDiagnosticsTab()

  local wantedTab = self:GetProfile().lastActiveMainTab or "General"
  self:SetActiveTab(wantedTab)
end

function TrueStrike:UpdateTabButtonState(tabName)
  local btn = self.tabButtons[tabName]
  if not btn then return end

  if self.activeTab == tabName then
    btn:SetBackdropColor(0.26, 0.53, 0.92, 0.95)
  else
    btn:SetBackdropColor(0.14, 0.16, 0.22, 0.95)
  end
end

function TrueStrike:RegisterTabPanel(tabName, panel)
  panel:Hide()
  self.tabPanels[tabName] = panel
end

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
