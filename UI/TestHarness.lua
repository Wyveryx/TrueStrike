--[[
TrueStrike - Test Harness
Purpose:
  Provide synthetic event generation for validating UI-only scroll behavior.
Main responsibilities:
  - Schedule short bursts of normal or crit test entries.
  - Route generated entries to all enabled scroll areas.
  - Stop active scheduling and clear existing entries on demand.
Module interactions:
  - Triggered from Scroll Areas tab buttons.
  - Uses ScrollEngine:SpawnTestEntry and ScrollEngine:StopAllEntries.
]]

local _, ns = ...
local TrueStrike = ns.TrueStrike

function TrueStrike:InitializeTestHarness()
  self.activeTicker = nil
end

-- Spawn 10 entries at 0.15s intervals for quick UI validation.
function TrueStrike:RunTestSequence(isCrit)
  self:StopTestSequence()

  local count = 0
  self.activeTicker = C_Timer.NewTicker(0.15, function(ticker)
    count = count + 1

    local amount = math.random(1200, 9800)
    local text = (isCrit and "CRIT " or "") .. "Fireball " .. amount

    self:ForEachArea(function(index, area)
      if area.enabled then
        self:SpawnTestEntry(index, text, isCrit)
      end
    end)

    if count >= 10 then
      ticker:Cancel()
      if self.activeTicker == ticker then
        self.activeTicker = nil
      end
    end
  end)
end

function TrueStrike:StopTestSequence()
  if self.activeTicker then
    self.activeTicker:Cancel()
    self.activeTicker = nil
  end

  self:StopAllEntries()
end
