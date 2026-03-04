local ADDON_NAME, TSBT = ...

TS_CastAnchor = TS_CastAnchor or {}

local _pendingCasts = {}
local _lastSucceededSpellID = nil
local _lastSucceededTime = nil
local _lastSentSpellID = nil
local _lastSentTime = nil

local function LogAnchor(spellID, castGUID, target)
    local desig = TS_Registry.GetDesignation(spellID)
    table.insert(TS_DesigConfig.EnsureLogTable("castAnchors"), {
        spellID = spellID,
        castGUID = castGUID,
        target = target,
        desig = desig,
        timestamp = GetServerTime()
    })

    if TS_DesigConfig and TS_DesigConfig.SafeLog then
        TS_DesigConfig.SafeLog("[TS_ANCHOR]", string.format(
                                   "CAST_ANCHOR {spellID=%s,castGUID=%s,target=%s,desig=%s,timestamp=%s}",
                                   tostring(spellID), tostring(castGUID),
                                   tostring(target), tostring(desig),
                                   tostring(GetServerTime())))
    end
end

local function Enabled()
    return TS_DesigConfig and TS_DesigConfig.TRUESTRIKE_CAST_ANCHOR_ENABLED
end

function TS_CastAnchor.GetLastSucceeded()
    return _lastSucceededSpellID, _lastSucceededTime
end

function TS_CastAnchor.GetLastSent() return _lastSentSpellID, _lastSentTime end

function TS_CastAnchor.OnSpellcastSent(unit, target, castGUID, spellID)
    if not Enabled() or unit ~= "player" or not castGUID then return end

    _pendingCasts[castGUID] = {
        spellID = spellID,
        target = TS_Taint.SafeStr(target),
        sentTime = GetTime()
    }

    _lastSentSpellID = spellID
    _lastSentTime = GetTime()

    LogAnchor(spellID, castGUID, _pendingCasts[castGUID].target)

end

function TS_CastAnchor.OnSpellcastSucceeded(unit, castGUID, spellID, castBarID)
    if not Enabled() or unit ~= "player" then return end

    local pending = _pendingCasts[castGUID]
    if not pending then return end

    -- Only update the succeeded anchor if this spell can legitimately be
    -- the source of a CTU event. Proc and Ignored spells must never overwrite
    -- the anchor — they fire SUCCEEDED instantly and will steal attribution
    -- from the actual cast spell whose CTU has already fired or is about to fire.
    -- Ancestral Awakening (382311) is the confirmed example of this race condition.
    local spellDesig = TS_Registry.GetDesignation(spellID)
    local isAttributable = spellDesig == TS_Registry.DESIGNATION.HEAL
                        or spellDesig == TS_Registry.DESIGNATION.HOT
                        or spellDesig == TS_Registry.DESIGNATION.DAMAGE
                        or spellDesig == TS_Registry.DESIGNATION.DAMAGE_AOE
                        or spellDesig == TS_Registry.DESIGNATION.DOT
                        or spellDesig == TS_Registry.DESIGNATION.MELEE
                        or spellDesig == nil  -- unknown spells may still be attributable

    if isAttributable then
        _lastSucceededSpellID = spellID
        _lastSucceededTime    = GetTime()
    end

    if TS_Registry.GetDesignation(spellID) == TS_Registry.DESIGNATION.HOT and
        TS_AuraScanner then TS_AuraScanner.ScanUnit("player") end

    if spellID == 5394 and TS_DesigConfig.TRUESTRIKE_SYNTHETIC_TOTEM_SLOTS then
        TS_SlotManager.CreateSyntheticTotemSlot(5394, 52042, "Healing Stream",
                                                15)
    end

    local synth = TS_Registry.GetSyntheticDesignation(spellID)
    if synth and TS_DesigConfig and TS_DesigConfig[synth.featureFlag] then
        TS_SlotManager.NewHotSlot(synth.auraSpellID, synth.tickSpellName,
                                  "player", nil, nil, nil,
                                  "SYNTHETIC_DESIGNATION")
    end

    _pendingCasts[castGUID] = nil
    LogAnchor(spellID, castGUID, pending.target)
end

function TS_CastAnchor.OnSpellcastFailed(unit, target, castGUID, spellID)
    if not Enabled() or unit ~= "player" then return end
    _pendingCasts[castGUID] = nil
end

function TS_CastAnchor.OnSpellcastInterrupted(unit, target, castGUID, spellID)
    if not Enabled() or unit ~= "player" then return end
    _pendingCasts[castGUID] = nil
end

function TS_CastAnchor.OnUnitAura(unit, updateInfo, spellbookCache)
    local watched = TS_DesigConfig and TS_DesigConfig.WATCHED_UNITS
    if not (watched and watched[unit]) then return end

    if unit == "player" and InCombatLockdown and InCombatLockdown() then
        TS_Taint.DetectNonSelfAuras(updateInfo, spellbookCache,
                                    function(spellIDNum, spellIDStr)
            if not TS_Registry.GetDesignation(spellIDNum) then
                TS_Registry.RegisterSpell(spellIDNum, spellIDStr,
                                          TS_Registry.DESIGNATION.UNKNOWN)
            end
        end)
        TS_SlotManager.PruneExpiredSlots()
        return
    end

    local scanned = TS_AuraScanner.ScanUnit(unit) or {}
    for _, aura in ipairs(scanned) do
        if TS_Registry.GetDesignation(aura.spellID) ==
            TS_Registry.DESIGNATION.HOT then
            if not TS_SlotManager.FindHotSlot(aura.spellID, unit) then
                TS_SlotManager.NewHotSlot(aura.spellID, aura.name, unit,
                                          aura.expirationTime,
                                          aura.computedExpiry, aura.duration,
                                          "AURA_SCAN")
            end
        end
    end

    TS_SlotManager.PruneExpiredSlots()
end

function TS_CastAnchor.Reset()
    _pendingCasts = {}
    _lastSucceededSpellID = nil
    _lastSucceededTime = nil
    _lastSentSpellID = nil
    _lastSentTime = nil
end

function TS_CastAnchor.PruneStale(maxAge)
    if not Enabled() then return end

    local cutoff = GetTime() - maxAge
    for castGUID, cast in pairs(_pendingCasts) do
        if cast.sentTime < cutoff then _pendingCasts[castGUID] = nil end
    end
end
