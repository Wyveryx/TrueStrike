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

-- ============================================================
-- Incoming Spell Attribution State
-- ============================================================
local SPELL_EXPIRE = 2.0
local MAX_PENDING_SPELLS = 5
local pendingSpells = {}
local incomingFrame = CreateFrame("Frame")

-- ============================================================
-- Pending Queue Helpers
-- ============================================================
local function PrunePendingSpells(now)
    -- Remove stale entries outside the spell correlation window.
    local i = 1
    while i <= #pendingSpells do
        local entry = pendingSpells[i]
        if (now - entry.time) > SPELL_EXPIRE then
            table.remove(pendingSpells, i)
        else
            i = i + 1
        end
    end
end

local function PushPendingSpell(spellID)
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then return end

    -- Store spell cast metadata for upcoming UNIT_COMBAT damage correlation.
    pendingSpells[#pendingSpells + 1] = {
        spellID = spellID,
        name = spellInfo.name,
        icon = spellInfo.iconID,
        time = GetTime(),
    }

    -- Keep queue bounded to avoid memory bloat.
    while #pendingSpells > MAX_PENDING_SPELLS do
        table.remove(pendingSpells, 1)
    end
end

local function AttachPendingSpell(ev, now)
    local bestIndex
    local bestDelta

    -- Find the closest recent spell cast inside the attribution window.
    for i = #pendingSpells, 1, -1 do
        local entry = pendingSpells[i]
        local delta = now - entry.time
        if delta >= 0 and delta <= SPELL_EXPIRE then
            if not bestDelta or delta < bestDelta then
                bestDelta = delta
                bestIndex = i
            end
        end
    end

    if not bestIndex then return end

    local match = pendingSpells[bestIndex]
    ev.spellID = match.spellID
    ev.spellName = match.name
    ev.spellIcon = match.icon
    table.remove(pendingSpells, bestIndex)
end

-- ============================================================
-- UNIT_SPELLCAST_SUCCEEDED Listener
-- ============================================================
incomingFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event ~= "UNIT_SPELLCAST_SUCCEEDED" then return end
    if not Incoming._enabled then return end

    -- Capture hostile casts from target and nameplates only.
    if unit ~= "target" and not (unit and unit:match("^nameplate")) then return end
    if not UnitCanAttack("player", unit) then return end
    if not spellID then return end

    -- Prune old entries on every cast before inserting fresh metadata.
    local now = GetTime()
    PrunePendingSpells(now)
    PushPendingSpell(spellID)
end)
------------------------------------------------------------------------
-- WoW 12.0 Midnight Compliance: Named Key Access Only
------------------------------------------------------------------------
-- CRITICAL CHANGES:
-- ✓ Replaced index-based access (info[12]) with named keys (info.amount)
-- ✓ Removed tonumber() calls on Secret Values (info.amount, info.critical)
-- ✓ Pass info.amount DIRECTLY to display without arithmetic/comparisons
-- ✗ REMOVED: Numeric comparisons, amount fallbacks

function Incoming:ProcessEvent(info)
    if not self._enabled then return end
    if not info or type(info) ~= "table" then return end

    local db = TSBT.db and TSBT.db.profile
    if not db or not db.incoming then return end

    local ev = nil

    -- Pulse engine normalized path.
    if info.kind == "damage" or info.kind == "heal" then
        if info.kind == "damage" then
            if not (db.incoming.damage and db.incoming.damage.enabled) then return end
        else
            if not (db.incoming.healing and db.incoming.healing.enabled) then return end
        end

        ev = {
            kind = info.kind,
            amount = info.amount,
            amountText = info.amountText,
            spellID = info.spellId,
            spellName = info.spellName,
            spellIcon = info.spellIcon,
            schoolMask = info.schoolMask,
            isCrit = info.isCrit,
            isPeriodic = info.isPeriodic == true,
            timestamp = info.timestamp,
            targetName = info.targetName or UnitName("player"),
            confidence = info.confidence,
        }

    -- Legacy combat-log shaped payload path.
    else
        local timestamp = info.timestamp
        local subevent = info.subEvent
        local destGUID = info.destGUID

        -- Ensure we are only looking at events affecting the player
        if destGUID ~= UnitGUID("player") then return end
        if type(subevent) ~= "string" then return end

        ev = {
            timestamp  = timestamp,
            targetName = UnitName("player"),
        }

        -- Basic categorization
        if subevent:find("_DAMAGE") then
            if not (db.incoming.damage and db.incoming.damage.enabled) then return end
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
    end

    -- Correlate recent hostile casts to incoming direct damage events.
    if ev.kind == "damage" then
        AttachPendingSpell(ev, GetTime())
    end

    local probe = TSBT.Core and TSBT.Core.IncomingProbe
    if probe and probe.OnIncomingDetected then
        probe:OnIncomingDetected(ev)
    end
end
-- Incoming is now managed by CombatLog_Detect.lua
function Incoming:Enable()
    self._enabled = true
    incomingFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end

function Incoming:Disable()
    self._enabled = false
    incomingFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end
