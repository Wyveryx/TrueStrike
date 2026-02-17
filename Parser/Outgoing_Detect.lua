local ADDON_NAME, TSBT = ...

TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.Outgoing = TSBT.Parser.Outgoing or {}
local Outgoing = TSBT.Parser.Outgoing

local band = bit.band
local AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
local TYPE_PLAYER      = COMBATLOG_OBJECT_TYPE_PLAYER      or 0x00000400

local function IsPlayerSource(flags)
    return flags and (band(flags, AFFILIATION_MINE) ~= 0) and (band(flags, TYPE_PLAYER) ~= 0)
end

------------------------------------------------------------------------
-- WoW 12.0 Midnight Compliance: Named Key Access Only
------------------------------------------------------------------------
-- CRITICAL CHANGES:
-- ✓ Replaced index-based access (info[12]) with named keys (info.amount)
-- ✓ Removed tonumber() calls on Secret Values (info.amount, info.critical)
-- ✓ Pass info.amount DIRECTLY to display without arithmetic/comparisons
-- ✗ REMOVED: Numeric comparisons, overheal zeroing, amount fallbacks

function Outgoing:ProcessEvent(info)
    -- WoW 12.0: Use named keys instead of positional unpacking
    local timestamp = info.timestamp
    local subevent = info.subEvent
    local sourceName = info.sourceName
    local sourceFlags = info.sourceFlags
    local targetName = info.destName

    if not IsPlayerSource(sourceFlags) then return end

    local db = TSBT.db and TSBT.db.profile
    if not db or not db.outgoing then return end

    local ev = { timestamp = timestamp, sourceName = sourceName, targetName = targetName }

    if subevent == "SWING_DAMAGE" then
        if not (db.outgoing.damage and db.outgoing.damage.enabled) then return end
        -- WoW 12.0: Pass info.amount DIRECTLY (Secret Value - no tonumber, no math)
        ev.kind = "damage"
        ev.amount = info.amount          -- Secret Value: display only
        ev.schoolMask = info.school      -- Safe: non-secret
        ev.spellId = 6603                -- Auto-attack constant
        ev.spellName = "Auto Attack"
        ev.isAuto = true
        ev.isCrit = info.critical        -- Secret Value: use directly (truthy check only)

    elseif subevent == "RANGE_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
        if not (db.outgoing.damage and db.outgoing.damage.enabled) then return end
        ev.kind = "damage"
        ev.spellId = info.spellId        -- Safe: non-secret
        ev.spellName = info.spellName    -- Safe: non-secret
        ev.schoolMask = info.school      -- Safe: non-secret
        ev.amount = info.amount          -- Secret Value: display only
        ev.isCrit = info.critical        -- Secret Value: truthy check only
        ev.isAuto = (subevent == "RANGE_DAMAGE") or (ev.spellId == 75)

    elseif subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
        if not (db.outgoing.healing and db.outgoing.healing.enabled) then return end
        ev.kind = "heal"
        ev.spellId = info.spellId        -- Safe: non-secret
        ev.spellName = info.spellName    -- Safe: non-secret
        ev.schoolMask = info.school      -- Safe: non-secret
        ev.amount = info.amount          -- Secret Value: display only
        ev.overheal = info.overhealing   -- Secret Value: display only (no zeroing allowed)
        ev.isCrit = info.critical        -- Secret Value: truthy check only
        ev.isAuto = false
    else
        return
    end

    -- Config Gating (WoW 12.0 compliant - no amount comparisons)
    if ev.kind == "damage" then
        if not db.outgoing.damage.showTargets then ev.targetName = nil end
        if ev.isAuto then
            local mode = db.outgoing.damage.autoAttackMode or "Show All"
            -- WoW 12.0: Can still check isCrit (truthy), but cannot compare amount
            if mode == "Hide" or (mode == "Show Only Crits" and not ev.isCrit) then return end
        end
    -- WoW 12.0: REMOVED overheal zeroing - cannot perform math on Secret Values
    -- If showOverheal is false, display layer must handle via formatting/visibility
    end

    local probe = TSBT.Core and TSBT.Core.OutgoingProbe
    if probe and probe.OnOutgoingDetected then probe:OnOutgoingDetected(ev) end
end

-- Outgoing state is now enabled/disabled via the Master Listener (CombatLog_Detect.lua)
function Outgoing:Enable() self._enabled = true end
function Outgoing:Disable() self._enabled = false end

