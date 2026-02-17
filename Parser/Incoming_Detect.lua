local ADDON_NAME, TSBT = ...
TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.Incoming = TSBT.Parser.Incoming or {}
local Incoming = TSBT.Parser.Incoming
local function Debug(level, ...)
    if TSBT.Core and TSBT.Core.Debug then
        TSBT.Core:Debug(level, ...)
    elseif TSBT.Debug then
        TSBT.Debug(level, ...)
    end
end
------------------------------------------------------------------------
-- WoW 12.0 Midnight Compliance: Named Key Access Only
------------------------------------------------------------------------
-- CRITICAL CHANGES:
-- ✓ Replaced index-based access (info[12]) with named keys (info.amount)
-- ✓ Removed tonumber() calls on Secret Values (info.amount, info.critical)
-- ✓ Pass info.amount DIRECTLY to display without arithmetic/comparisons
-- ✗ REMOVED: Numeric comparisons, amount fallbacks

function Incoming:ProcessEvent(info)
    -- WoW 12.0: Use named keys instead of positional indexing
    local timestamp = info.timestamp
    local subevent = info.subEvent
    local destGUID = info.destGUID

    -- Ensure we are only looking at events affecting the player
    if destGUID ~= UnitGUID("player") then return end

    local db = TSBT.db and TSBT.db.profile
    if not db or not db.incoming or not db.incoming.damage then return end

    local ev = {
        timestamp  = timestamp,
        targetName = UnitName("player"),
    }

    -- Basic categorization
    if subevent:find("_DAMAGE") then
        if not db.incoming.damage.enabled then return end
        ev.kind = "damage"
        ev.amount = info.amount          -- Secret Value: display only (no tonumber, no fallback)
        ev.schoolMask = info.school      -- Safe: non-secret
        ev.isCrit = info.critical        -- Secret Value: truthy check only

    elseif subevent:find("_HEAL") then
        if not (db.incoming.healing and db.incoming.healing.enabled) then return end
        ev.kind = "heal"
        ev.amount = info.amount          -- Secret Value: display only (no tonumber, no fallback)
        ev.isCrit = info.critical        -- Secret Value: truthy check only
    else
        return
    end

    local probe = TSBT.Core and TSBT.Core.IncomingProbe
    if probe and probe.OnIncomingDetected then
        probe:OnIncomingDetected(ev)
    end
end
-- Incoming is now managed by CombatLog_Detect.lua
function Incoming:Enable() self._enabled = true end
function Incoming:Disable() self._enabled = false end
