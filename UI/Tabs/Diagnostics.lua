--[[
TrueStrike - Placeholder Tab
Purpose:
  Provide a stable navigable panel for milestone scope completeness.
Main responsibilities:
  - Render heading and placeholder text.
  - Avoid runtime errors when switching tabs.
Module interactions:
  - Registered by UI/Shell tab construction.
]]

local _, ns = ...
local TrueStrike = ns.TrueStrike

function TrueStrike:BuildDiagnosticsTab()
  local panel = CreateFrame("Frame", nil, self.contentFrame)
  panel:SetAllPoints(self.contentFrame)
  self:RegisterTabPanel("Diagnostics", panel)

  local h = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  h:SetPoint("TOPLEFT", 18, -18)
  h:SetText("Diagnostics")

  local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("TOPLEFT", 22, -58)
  t:SetText("Not implemented in UI shell milestone.")
end
