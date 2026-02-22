--[[
TrueStrike - Minimap Button
Purpose:
  Register an optional LibDataBroker/LibDBIcon minimap launcher.
Main responsibilities:
  - Provide left/right click actions for shell open/close.
  - Expose a tooltip with command hints.
  - Guard all library access for optional dependency handling.
]]

local _, ns = ...
local TrueStrike = ns.TrueStrike

function TrueStrike:InitializeMinimapButton()
  local ldb = LibStub("LibDataBroker-1.1", true)
  local dbIcon = LibStub("LibDBIcon-1.0", true)
  if not ldb or not dbIcon then
    return
  end

  self.minimapLauncher = self.minimapLauncher or ldb:NewDataObject("TrueStrike", {
    type = "launcher",
    text = "TrueStrike",
    icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    OnClick = function(_, button)
      if button == "RightButton" then
        self:HideShell()
      else
        self:ShowShell()
      end
    end,
    OnTooltipShow = function(tooltip)
      tooltip:AddLine("TrueStrike")
      tooltip:AddLine("Left-Click: Open", 1, 1, 1)
      tooltip:AddLine("Right-Click: Close", 1, 1, 1)
    end,
  })

  dbIcon:Register("TrueStrike", self.minimapLauncher, self:GetProfile().minimap)
  if self:GetProfile().minimap.hide then
    dbIcon:Hide("TrueStrike")
  else
    dbIcon:Show("TrueStrike")
  end
end
