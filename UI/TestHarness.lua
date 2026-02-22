-- TrueStrike Test Harness
-- Spawns synthetic normal/crit events for validating scroll behavior.

local _, ns = ...
local TrueStrike = ns.TrueStrike

function TrueStrike:InitializeTestHarness()
  self.activeTicker = nil
end

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
