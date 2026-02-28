local ADDON_NAME, TSBT = ...

TS_AuraScanner = TS_AuraScanner or {}

local _watchedUnits = { "player", "target", "party1", "party2", "party3", "party4" }
local _auraSnapshot = {}

function TS_AuraScanner.ScanUnit(unit)
    if InCombatLockdown and InCombatLockdown() then
        return _auraSnapshot[unit]
    end

    local nextSnapshot = {}
    for index = 1, 40 do
        local aura = TS_Taint.SafeAuraExtract(unit, index)
        if not aura then
            break
        end

        table.insert(nextSnapshot, {
            spellID = aura.spellID,
            name = aura.name,
            expirationTime = aura.expirationTime,
            duration = aura.duration,
        })
    end

    _auraSnapshot[unit] = nextSnapshot
    return nextSnapshot
end

function TS_AuraScanner.ScanAllWatchedUnits()
    if not (TS_DesigConfig and TS_DesigConfig.TRUESTRIKE_PRECOMBAT_AURA_SCAN) then
        return _auraSnapshot
    end

    if InCombatLockdown and InCombatLockdown() then
        return _auraSnapshot
    end

    for _, unit in ipairs(_watchedUnits) do
        TS_AuraScanner.ScanUnit(unit)
    end

    return _auraSnapshot
end

function TS_AuraScanner.SnapshotAllWatchedUnits()
    return _auraSnapshot
end

local function IsWatchedUnit(unit)
    for _, watched in ipairs(_watchedUnits) do
        if watched == unit then
            return true
        end
    end
    return false
end

function TS_AuraScanner.OnUnitAura(unit)
    if not IsWatchedUnit(unit) then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        --[[ FLAGGED: GetAuraDataByAuraInstanceID in-combat HoT creation
             Why flagged:         GetAuraDataByAuraInstanceID Q2 probe fired in v12 but the
                                  DB verdict field (CLEAN/TAINTED) was not manually verified.
             Evidence gap:        Manual DB review of Q2 verdict required from a dungeon
                                  session with >= 100 PERIODIC_HEAL events.
             Acceptance criteria: registry shows verdict="CLEAN" for Q2 probe.
             Default behavior:    In-combat HoT creation disabled. Lease-clock lifecycle only
                                  (UnitAura pre-combat scan).
             Feature flag:        TRUESTRIKE_INCOMBAT_HOT_CREATION = false
        --]]

        --[[ DISPROVEN: GetBuffDataByIndex in combat
             Do not implement. Reason: Calling GetBuffDataByIndex in combat is unsafe under WoW 12.0.1 constraints.
             Source: TrueStrike_DesignationEngine_Handoff_v1.md
        --]]
        return
    end

    local previous = _auraSnapshot[unit] or {}
    local hadSpell = {}
    for _, aura in ipairs(previous) do
        hadSpell[aura.spellID] = true
    end

    local updated = TS_AuraScanner.ScanUnit(unit) or {}
    for _, aura in ipairs(updated) do
        local desig = TS_Registry.GetDesignation(aura.spellID)
        if desig == TS_Registry.DESIGNATION.HOT and not hadSpell[aura.spellID] then
            if not TS_SlotManager.FindHotSlot(aura.spellID, unit) then
                TS_SlotManager.NewHotSlot(aura.spellID, aura.name, unit, aura.expirationTime, aura.duration, "AURA_SCAN")
            end
        end
    end
end
