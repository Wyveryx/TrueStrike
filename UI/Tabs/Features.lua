-- TrueStrike Features Tab Placeholder

local _, ns = ...
local TrueStrike = ns.TrueStrike

function TrueStrike:BuildFeaturesTab()
  local panel = CreateFrame("Frame", nil, self.contentFrame)
  panel:SetAllPoints(self.contentFrame)
  self:RegisterTabPanel("Features", panel)

  local h = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  h:SetPoint("TOPLEFT", 18, -18)
  h:SetText("Features")

  local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("TOPLEFT", 22, -58)
  t:SetText("Not implemented in UI shell milestone.")
end
