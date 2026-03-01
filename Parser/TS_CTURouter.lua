local ADDON_NAME, TSBT = ...

TS_CTURouter = TS_CTURouter or {}

TS_CTURouter.CTU_SLOT_FAMILY = {
    HEAL = "Heal",
    HEAL_CRIT = "Heal",
    PERIODIC_HEAL = "HoT",
    PERIODIC_HEAL_CRIT = "HoT",
    SPELL_DAMAGE = "Damage",
    SPELL_DAMAGE_CRIT = "Damage",
    PERIODIC_DAMAGE = "DoT",
    PERIODIC_DAMAGE_CRIT = "DoT",
    DAMAGE = "Melee",
}

local _seq = 0
local _ignorable = {
    ABSORB = true,
    MISS = true,
    DODGE = true,
    BLOCK = true,
    RESIST = true,
}

local function RouteToDisplay(ctuType, valueStr)
    local profile = TSBT.db and TSBT.db.profile
    if not profile then
        return
    end

    local routing = {
        Heal = {
            areaName = profile.outgoing.healing.scrollArea,
            enabled = profile.outgoing.healing.enabled,
        },
        HoT = {
            areaName = profile.incoming.healing.scrollArea,
            enabled = profile.incoming.healing.enabled,
        },
        Damage = {
            areaName = profile.outgoing.damage.scrollArea,
            enabled = profile.outgoing.damage.enabled,
        },
        DoT = {
            areaName = profile.outgoing.damage.scrollArea,
            enabled = profile.outgoing.damage.enabled,
        },
    }

    local family = TS_CTURouter.CTU_SLOT_FAMILY[ctuType]
    if not family then
        return
    end

    if family == "Melee" then
        -- FLAGGED: Melee attribution gated.
        -- TRUESTRIKE_MELEE_ATTRIBUTION = false
        -- Outcome A confirmed. No outgoing melee API path.
        return
    end

    local route = routing[family]
    if not route then
        return
    end

    local areaName = route.areaName
    local enabled = route.enabled
    if enabled == false then
        return
    end
    if not areaName or areaName == "" then
        return
    end

    -- Secret value already converted via TS_Taint.SafeStr before
    -- this point. valueStr is display-safe. Do not unwrap further.
    local ok, err = pcall(function()
        TSBT.DisplayText(areaName, valueStr)
    end)
    if not ok then
        table.insert(
            TS_DesigConfig.EnsureLogTable("taintErrors"),
            {
                ["function"] = "RouteToDisplay",
                error = tostring(err),
                context = ctuType,
            }
        )
    end
end

local function LogUnknown(ctuType)
    table.insert(TS_DesigConfig.EnsureLogTable("unknownObserved"), {
        spellID = nil,
        spellName = nil,
        ctuType = ctuType,
        timestamp = GetServerTime(),
    })
end

function TS_CTURouter.AttributeTick(ctuType, auraSnapshot, lastSpellID, lastSpellTime)
    local expectedDesig = TS_CTURouter.CTU_SLOT_FAMILY[ctuType]
    if not expectedDesig then
        return nil
    end

    -- Earth Shield IDs are Proc in TS_Registry, so the type gate naturally prevents false HoT matching.
    if lastSpellID and lastSpellTime and (GetTime() - lastSpellTime) < (TS_DesigConfig.PROMOTION_WINDOW_SECONDS or 0.150) then
        if TS_Registry.GetDesignation(lastSpellID) == expectedDesig then
            local slot = TS_SlotManager.FindHotSlot(lastSpellID, "player")
            if slot then
                return slot.slotID, "HIGH"
            end
        end
    end

    local playerAuras = auraSnapshot and auraSnapshot.player or {}
    local inSnapshot = {}
    for _, aura in ipairs(playerAuras) do
        inSnapshot[aura.spellID] = true
    end

    for _, slot in ipairs(TS_SlotManager.GetActiveSlots()) do
        if TS_Registry.GetDesignation(slot.spellID) == expectedDesig then
            local confidence = inSnapshot[slot.spellID] and "HIGH" or "MEDIUM"
            table.insert(TS_DesigConfig.EnsureLogTable("tickAttributed"), {
                slotID = slot.slotID,
                spellID = slot.spellID,
                ctuType = ctuType,
                confidence = confidence,
                deltaPrev = 0,
            })
            return slot.slotID, confidence
        end
    end

    LogUnknown(ctuType)
    return nil
end

function TS_CTURouter.OnCombatTextUpdate(ctuType)
    TS_CastAnchor.PruneStale(10)
    TS_SlotManager.PruneExpiredSlots()

    local _, _, _, arg3 = C_CombatText.GetCurrentEventInfo()
    local valueStr = TS_Taint.SafeStr(arg3)

    --[[ DISPROVEN: Arithmetic on CTU secret values
         Do not implement. Reason: CTU value must be treated as opaque in WoW 12.0.1.
         Source: TrueStrike_DesignationEngine_Handoff_v1.md
    --]]

    --[[ DISPROVEN: tonumber(value)
         Do not implement. Reason: Numeric conversion of CTU secret value is forbidden.
         Source: TrueStrike_DesignationEngine_Handoff_v1.md
    --]]

    --[[ DISPROVEN: value as table key
         Do not implement. Reason: CTU value cannot be used as a map key safely.
         Source: TrueStrike_DesignationEngine_Handoff_v1.md
    --]]

    local expectedDesig = TS_CTURouter.CTU_SLOT_FAMILY[ctuType]
    if not expectedDesig and not _ignorable[ctuType] then
        LogUnknown(ctuType)
    end

    --[[ FLAGGED: UNIT_COMBAT outgoing melee probe
         Why flagged:         UNIT_COMBAT confirmed Outcome A (incoming-only for
                              RegisterUnitEvent("UNIT_COMBAT","player")). Outgoing melee
                              via this path is disproven for RegisterUnitEvent.
                              Flag preserved in case a new API path is discovered.
         Evidence gap:        No new API path identified. UNIT_COMBAT delivers
                              player-targeted incoming events only.
         Acceptance criteria: New empirical probe demonstrates outgoing WOUND+PHYSICAL
                              events accessible from a non-UNIT_COMBAT API.
         Default behavior:    No UNIT_COMBAT handler registered. Melee attribution
                              entirely inactive.
         Feature flag:        TRUESTRIKE_MELEE_ATTRIBUTION = false
    --]]

    --[[ FLAGGED: Non-self incoming heals via CTU
         Why flagged:         Does CTU fire for heals received FROM other players?
                              Completely untested.
         Evidence gap:        No session data exists for CTU HEAL events where the
                              player cast nothing.
         Acceptance criteria: Observed CTU HEAL event confirmed from external source
                              in at least one session.
         Default behavior:    HEAL/HEAL_CRIT routing proceeds as self-cast only.
                              External heals will attribute as Unknown if no SENT anchor
                              or HoT slot matches.
         Feature flag:        TRUESTRIKE_INCOMING_HEAL_PROBE = false
    --]]

    local auraSnapshot = TS_AuraScanner.SnapshotAllWatchedUnits()
    local lastSpellID, lastSpellTime = TS_CastAnchor.GetLastSucceeded()
    local slotID, confidence = TS_CTURouter.AttributeTick(ctuType, auraSnapshot, lastSpellID, lastSpellTime)

    _seq = _seq + 1
    table.insert(TS_DesigConfig.EnsureLogTable("ctuCaptured"), {
        seq = _seq,
        ctuType = ctuType,
        valueStr = valueStr,
        correlatedSpellID = slotID,
        desig = expectedDesig,
    })

    if slotID then
        RouteToDisplay(ctuType, valueStr)
    end
end
