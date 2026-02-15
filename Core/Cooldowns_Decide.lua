------------------------------------------------------------------------
-- TrueStrike - Cooldowns Decision Layer (Skeleton)
-- Responsibility: decide whether a cooldown event should be emitted.
------------------------------------------------------------------------
local ADDON_NAME, TSBT = ...

TSBT.Core = TSBT.Core or {}
TSBT.Core.Cooldowns = TSBT.Core.Cooldowns or {}
local Cooldowns = TSBT.Core.Cooldowns
local Addon     = TSBT.Addon

function Cooldowns:Enable()
    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(1, "Cooldowns:Enable()")
    end
end

function Cooldowns:Disable()
    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(1, "Cooldowns:Disable()")
    end
end

-- Contract for Parser -> Core handoff (not used yet)
function Cooldowns:OnCooldownReady(event)
    -- event is expected to be a normalized table later.
    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(3, "Cooldowns:OnCooldownReady() (stub)")
    end
end
