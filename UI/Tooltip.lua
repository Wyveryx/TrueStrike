--[[
TrueStrike - Tooltip Helper
Purpose:
  Centralize GameTooltip attachment behavior for all interactive controls in the
  UI shell milestone.
Main responsibilities:
  - Provide a single helper to attach consistent OnEnter/OnLeave scripts.
  - Standardize tooltip layout (title, spacer, wrapped body lines).
  - Fail silently when GameTooltip is unavailable.
Module interactions:
  - Called by Shell, tab modules, and runtime scroll area controls.
]]

local _, ns = ...
local TrueStrike = ns.TrueStrike

TrueStrike.UI = TrueStrike.UI or {}

-- Attach a standardized tooltip to a frame/button/editbox/slider/dropdown.
-- `title` is the first line. `lines` is an array of short body strings.
function TrueStrike.UI.AttachTooltip(frame, title, lines, anchor)
  if not frame then
    return
  end

  frame:HookScript("OnEnter", function(self)
    if not GameTooltip then
      return
    end

    GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(title or "TrueStrike", 1, 1, 1)
    GameTooltip:AddLine(" ")

    for _, line in ipairs(lines or {}) do
      GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
    end

    GameTooltip:Show()
  end)

  frame:HookScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
end
