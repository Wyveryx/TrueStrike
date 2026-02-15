------------------------------------------------------------------------
-- TrueStrike Battle Text - Diagnostics
-- Debug output and SavedVariables event logging.
------------------------------------------------------------------------

local ADDON_NAME, TSBT = ...
local Addon = TSBT.Addon

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
    if not diag or not diag.captureEnabled then
        return
    end

    -- Bounded insertion: drop oldest if at capacity
    local log = diag.log
    if #log >= diag.maxEntries then
        table.remove(log, 1)
    end

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
