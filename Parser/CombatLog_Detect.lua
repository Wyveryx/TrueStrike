------------------------------------------------------------------------
-- TrueStrike - Combat Log Detection (Skeleton)
-- Responsibility: listen to raw combat events and forward normalized data.
------------------------------------------------------------------------
local ADDON_NAME, TSBT = ...

TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.CombatLog = TSBT.Parser.CombatLog or {}
local CombatLog = TSBT.Parser.CombatLog
local Addon     = TSBT.Addon

function CombatLog:Enable()
    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(1, "Parser.CombatLog:Enable()")
    end

    -- Do not register events yet (skeleton only).
end

function CombatLog:Disable()
    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(1, "Parser.CombatLog:Disable()")
    end
end
