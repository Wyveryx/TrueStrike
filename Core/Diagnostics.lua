------------------------------------------------------------------------
-- TrueStrike Battle Text - Diagnostics
-- Debug output and SavedVariables event logging.
------------------------------------------------------------------------
local ADDON_NAME, TSBT = ...
local Addon = TSBT.Addon

------------------------------------------------------------------------
-- Pipeline Diagnostics Counters
-- Incremented by TS_CTURouter and DisplayHealWithSecret at runtime.
-- Read by the Diagnostics config tab for live display.
------------------------------------------------------------------------
TSBT.PipelineDiag = {
    ctuFired = 0,
    canRouteTrue = 0,
    canRouteFalse = 0,
    routeToDisplay = 0,
    displayCalled = 0,
    gateBlocked = 0,
    lastCtuType = "—",
    lastSpellID = 0,
    lastFamily = "—",
    lastGateResult = "—"
}

function TSBT.ResetPipelineDiag()
    local p = TSBT.PipelineDiag
    p.ctuFired = 0
    p.canRouteTrue = 0
    p.canRouteFalse = 0
    p.routeToDisplay = 0
    p.displayCalled = 0
    p.gateBlocked = 0
    p.lastCtuType = "—"
    p.lastSpellID = 0
    p.lastFamily = "—"
    p.lastGateResult = "—"
end

------------------------------------------------------------------------
-- Debug Print (respects current debug level)
------------------------------------------------------------------------
function Addon:DebugPrint(requiredLevel, ...)
    local currentLevel = self.db and self.db.profile.diagnostics.debugLevel or 0
    if currentLevel >= requiredLevel then
        self:Print("|cFF4A9EFF[Debug " .. requiredLevel .. "]|r", ...)
    end
end

------------------------------------------------------------------------
-- Log Event to SavedVariables (for post-session analysis)
------------------------------------------------------------------------
function Addon:LogEvent(eventData)
    local diag = self.db and self.db.profile.diagnostics
    if not diag or not diag.captureEnabled then return end

    -- Bounded insertion: drop oldest if at capacity
    local log = diag.log
    if #log >= diag.maxEntries then table.remove(log, 1) end

    eventData.timestamp = GetTime()
    log[#log + 1] = eventData
end

------------------------------------------------------------------------
-- Clear Diagnostic Log
------------------------------------------------------------------------
function Addon:ClearDiagnosticLog()
    if self.db and self.db.profile.diagnostics then
        wipe(self.db.profile.diagnostics.log)
        self:Print("Diagnostic log cleared.")
    end
end
