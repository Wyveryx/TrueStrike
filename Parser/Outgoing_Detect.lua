local ADDON_NAME, TSBT = ...

TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.Outgoing = TSBT.Parser.Outgoing or {}
local Outgoing = TSBT.Parser.Outgoing

local band = bit.band
local AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
local TYPE_PLAYER      = COMBATLOG_OBJECT_TYPE_PLAYER      or 0x00000400

local function Debug(level, ...)
    if TSBT.Core and TSBT.Core.Debug then
        TSBT.Core:Debug(level, ...)
    elseif TSBT.Debug then
        TSBT.Debug(level, ...)
    end
end

local function IsPlayerSource(flags)
    if not flags then return false end
    return band(flags, AFFILIATION_MINE) ~= 0 and band(flags, TYPE_PLAYER) ~= 0
end

local function DB()
    return TSBT.db and TSBT.db.profile
end

local function Emit(evt)
    local probe = TSBT.Core and TSBT.Core.OutgoingProbe
    if probe and probe.OnOutgoingDetected then
        probe:OnOutgoingDetected(evt)
    end
end

local function Normalize(info)
    local ts       = info[1]
    local subevent = info[2]
    local sourceFlags = info[6]
    if not IsPlayerSource(sourceFlags) then return nil end

    local db = DB()
    if not db or not db.outgoing then return nil end

    local ev = {
        timestamp  = ts,
        sourceName = info[5],
        targetName = info[9],
    }

    if subevent == "SWING_DAMAGE" then
        if not (db.outgoing.damage and db.outgoing.damage.enabled) then return nil end
        ev.kind       = "damage"
        ev.amount     = tonumber(info[12]) or 0
        ev.schoolMask = tonumber(info[14]) or 1
        ev.spellId    = 6603
        ev.spellName  = "Auto Attack"
        ev.isAuto     = true
        ev.isCrit     = info[18] and true or false

    elseif subevent == "RANGE_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
        if not (db.outgoing.damage and db.outgoing.damage.enabled) then return nil end
        local spellId = tonumber(info[12])
        ev.kind       = "damage"
        ev.spellId    = spellId
        ev.spellName  = info[13]
        ev.schoolMask = tonumber(info[14]) or 1
        ev.amount     = tonumber(info[15]) or 0
        ev.isCrit     = info[20] and true or false
        ev.isAuto     = (subevent == "RANGE_DAMAGE") or (spellId == 75)

    elseif subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
        if not (db.outgoing.healing and db.outgoing.healing.enabled) then return nil end
        ev.kind       = "heal"
        ev.spellId    = tonumber(info[12])
        ev.spellName  = info[13]
        ev.schoolMask = tonumber(info[14]) or 1
        ev.amount     = tonumber(info[15]) or 0
        ev.overheal   = tonumber(info[16]) or 0
        ev.isCrit     = info[18] and true or false
        ev.isAuto     = false

    else
        return nil
    end

    -- Outgoing tab gating relevant to probe visibility
    if ev.kind == "damage" then
        local dmg = db.outgoing.damage or {}
        if not dmg.showTargets then
            ev.targetName = nil
        end

        if ev.isAuto then
            local mode = dmg.autoAttackMode or "Show All"
            if mode == "Hide" then return nil end
            if mode == "Show Only Crits" and not ev.isCrit then return nil end
        end
    else
        local heal = db.outgoing.healing or {}
        if not heal.showOverheal then
            ev.overheal = 0
        end
    end

    return ev
end

-- Frame wiring (no AceEvent)
local f = CreateFrame("Frame")
Outgoing._frame = f
Outgoing._enabled = false

f:SetScript("OnEvent", function()
    if not Outgoing._enabled then return end
    local info = { CombatLogGetCurrentEventInfo() }
    if #info == 0 then return end

    local ok, evtOrErr = pcall(Normalize, info)
    if not ok then
        Debug(1, "Parser.Outgoing normalize error:", tostring(evtOrErr))
        return
    end

    local evt = evtOrErr
    if evt then Emit(evt) end
end)

function Outgoing:Enable()
    if self._enabled then return end
    self._enabled = true
    f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    Debug(1, "Parser.Outgoing enabled.")
end

function Outgoing:Disable()
    if not self._enabled then return end
    self._enabled = false
    f:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    Debug(1, "Parser.Outgoing disabled.")
end
