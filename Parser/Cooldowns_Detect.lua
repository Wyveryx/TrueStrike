------------------------------------------------------------------------
-- TrueStrike - Cooldowns Detection (Skeleton)
-- Responsibility: detect raw cooldown state changes and forward them.
------------------------------------------------------------------------
local ADDON_NAME, TSBT = ...

TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.Cooldowns = TSBT.Parser.Cooldowns or {}
local Cooldowns = TSBT.Parser.Cooldowns
local Addon     = TSBT.Addon

function Cooldowns:Enable()
    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(1, "Parser.Cooldowns:Enable()")
    end

    -- Do not register events yet (skeleton only).
end

function Cooldowns:Disable()
    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(1, "Parser.Cooldowns:Disable()")
    end
end
