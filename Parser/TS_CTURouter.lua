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
    DAMAGE = "Melee"
}

local _seq = 0
local _ignorable = {
    ABSORB = true,
    MISS = true,
    DODGE = true,
    BLOCK = true,
    RESIST = true
}

local function RouteToDisplay(ctuType, valueStr, spellID, isCrit, arg3_secret)
    local profile = TSBT.db and TSBT.db.profile
    if not profile then return end

    if TSBT.PipelineDiag then
        TSBT.PipelineDiag.routeToDisplay = TSBT.PipelineDiag.routeToDisplay + 1
        TSBT.PipelineDiag.lastFamily = TS_CTURouter.CTU_SLOT_FAMILY[ctuType] or
                                           "nil"
    end

    local routing = {
        Heal = {
            areaName = profile.outgoing.healing.scrollArea,
            enabled = profile.outgoing.healing.enabled
        },
        HoT = {
            areaName = profile.incoming.healing.scrollArea,
            enabled = profile.incoming.healing.enabled
        },
        Damage = {
            areaName = profile.outgoing.damage.scrollArea,
            enabled = profile.outgoing.damage.enabled
        },
        DoT = {
            areaName = profile.outgoing.damage.scrollArea,
            enabled = profile.outgoing.damage.enabled
        }
    }

    local family = TS_CTURouter.CTU_SLOT_FAMILY[ctuType]
    if not family then return end

    if family == "Melee" then
        -- FLAGGED: Melee attribution gated.
        -- TRUESTRIKE_MELEE_ATTRIBUTION = false
        -- Outcome A confirmed. No outgoing melee API path.
        return
    end

    local route = routing[family]
    if not route then return end

    local areaName = route.areaName
    local enabled = route.enabled
    if enabled == false then return end
    if not areaName or areaName == "" then return end

    -- Secret value already converted via TS_Taint.SafeStr before
    -- this point. valueStr is display-safe. Do not unwrap further.
    local ok, err = pcall(function()
        if family == "Heal" or family == "HoT" then
            local meta = {isCrit = isCrit or false}
            if type(spellID) == "number" and spellID > 0 then
                local infoOK, info = pcall(C_Spell.GetSpellInfo, spellID)
                if infoOK and type(info) == "table" then
                    meta.spellName = info.name
                    meta.spellIcon = info.iconID
                end
            end
            TSBT.DisplayHealWithSecret(areaName, "", arg3_secret, nil, meta)
            return
        end

        TSBT.DisplayText(areaName, valueStr)
    end)
    if not ok then
        table.insert(TS_DesigConfig.EnsureLogTable("taintErrors"), {
            ["function"] = "RouteToDisplay",
            error = tostring(err),
            context = ctuType
        })
    end
end

local function LogUnknown(ctuType)
    table.insert(TS_DesigConfig.EnsureLogTable("unknownObserved"), {
        spellID = nil,
        spellName = nil,
        ctuType = ctuType,
        timestamp = GetServerTime()
    })
end

function TS_CTURouter.AttributeTick(ctuType, auraSnapshot, lastSpellID,
                                    lastSpellTime)
    local expectedDesig = TS_CTURouter.CTU_SLOT_FAMILY[ctuType]
    if not expectedDesig then return nil end

    -- Earth Shield IDs are Proc in TS_Registry, so the type gate naturally prevents false HoT matching.
    if lastSpellID and lastSpellTime and (GetTime() - lastSpellTime) <
        (TS_DesigConfig.PROMOTION_WINDOW_SECONDS or 0.150) then
        if TS_Registry.GetDesignation(lastSpellID) == expectedDesig then
            local slot = TS_SlotManager.FindHotSlot(lastSpellID, "player")
            if slot then return slot.slotID, "HIGH", slot.spellID end
        end
    end

    local playerAuras = auraSnapshot and auraSnapshot.player or {}
    local inSnapshot = {}
    for _, aura in ipairs(playerAuras) do inSnapshot[aura.spellID] = true end

    for _, slot in ipairs(TS_SlotManager.GetActiveSlots()) do
        if TS_Registry.GetDesignation(slot.spellID) == expectedDesig then
            local confidence = inSnapshot[slot.spellID] and "HIGH" or "MEDIUM"
            table.insert(TS_DesigConfig.EnsureLogTable("tickAttributed"), {
                slotID = slot.slotID,
                spellID = slot.spellID,
                ctuType = ctuType,
                confidence = confidence,
                deltaPrev = 0
            })
            return slot.slotID, confidence, slot.spellID
        end
    end

    LogUnknown(ctuType)
    return nil
end

function TS_CTURouter.OnCombatTextUpdate(ctuType)
    TS_CastAnchor.PruneStale(10)
    TS_SlotManager.PruneExpiredSlots()

    -- NOTE: C_CombatText.GetCurrentEventInfo() returns nil in WoW 12.0 Midnight.
    -- GetCurrentCombatTextEventInfo() is the correct global. Verified in-game 2026.
    local _, arg3 = GetCurrentCombatTextEventInfo()
    local valueStr = TS_Taint.SafeStr(arg3)

    if TSBT.PipelineDiag then
        TSBT.PipelineDiag.ctuFired = TSBT.PipelineDiag.ctuFired + 1
        TSBT.PipelineDiag.lastCtuType = ctuType or "nil"
    end

    local isCrit = ctuType == "HEAL_CRIT" or ctuType == "PERIODIC_HEAL_CRIT" or
                       ctuType == "SPELL_DAMAGE_CRIT" or ctuType ==
                       "PERIODIC_DAMAGE_CRIT"

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
    if not expectedDesig and not _ignorable[ctuType] then LogUnknown(ctuType) end

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

    local lastSucceededID, lastSucceededTime = TS_CastAnchor.GetLastSucceeded()

    --[[ DISPROVEN: SENT anchor fallback for direct event attribution
         Do not implement. Reason: UNIT_SPELLCAST_SENT fires before CTU, but
         instant-cast proc spells (e.g. Ancestral Awakening 382311) also fire
         SUCCEEDED immediately, overwriting the anchor in the window between
         CTU and the actual cast spell's SUCCEEDED. The SENT fallback cannot
         distinguish between a legitimate cast-time spell pending SUCCEEDED and
         a proc that has already stolen the anchor slot. Using SENT produced
         confirmed wrong attributions in v0.3.10-alpha in-game testing.
         The correct behavior is to use SUCCEEDED only and miss cleanly when
         it is absent. TS_CastAnchor.OnSpellcastSucceeded now guards against
         Proc/Ignored spells overwriting the anchor, which eliminates the race.
         Source: OutgoingHealCapture v13 empirical probe sessions + v0.3.10 regression.
    --]]

    -- Direct and periodic events both use SUCCEEDED anchor only.
    -- No SENT fallback. A clean miss is preferable to a wrong attribution.
    local lastSpellID   = lastSucceededID
    local lastSpellTime = lastSucceededTime
    local auraSnapshot = TS_AuraScanner and TS_AuraScanner.SnapshotAllWatchedUnits and TS_AuraScanner.SnapshotAllWatchedUnits() or {}

    local slotID, confidence, matchedSpellID =
        TS_CTURouter.AttributeTick(ctuType, auraSnapshot, lastSpellID,
                                   lastSpellTime)

    -- Determine whether this event can route to display.
    -- AttributeTick() handles HoTs and close-window anchored spells.
    -- The fast paths below handle direct heals, spell damage, and DoTs
    -- that fall outside the 0.150s promotion window but still have a
    -- recent cast anchor (within 2.0s), or are DoT ticks (attributed by type).
    local canRoute = false

    if slotID then
        -- Normal attribution path: HoT slot match or promotion-window anchor.
        canRoute = true

    elseif (ctuType == "HEAL" or ctuType == "HEAL_CRIT") and lastSpellID and
        lastSpellTime and (GetTime() - lastSpellTime) < 2.0 then
        local anchorDesig = TS_Registry.GetDesignation(lastSpellID)
        if anchorDesig == "Heal" or anchorDesig == "HoT" then
            -- Direct heal attributed via recent cast anchor (wider 2.0s window).
            -- CTU fires before UNIT_SPELLCAST_SUCCEEDED for cast-time spells,
            -- so the 0.150s promotion window is too tight for this path.
            -- HoT spells (e.g. Riptide 61295) fire an initial HEAL event before their ticks begin.
            canRoute = true
            slotID = tostring(lastSpellID) -- string only, for logging
            confidence = "ANCHOR"
        end

    elseif (ctuType == "SPELL_DAMAGE" or ctuType == "SPELL_DAMAGE_CRIT") and
        lastSpellID and lastSpellTime and (GetTime() - lastSpellTime) < 2.0 and
        TS_Registry.GetDesignation(lastSpellID) == "Damage" then
        -- Spell damage attributed via recent cast anchor.
        canRoute = true
        slotID = tostring(lastSpellID) -- string only, for logging
        confidence = "ANCHOR"

    elseif ctuType == "PERIODIC_DAMAGE" or ctuType == "PERIODIC_DAMAGE_CRIT" then
        -- DoT ticks: route by type alone. Attribution is best-effort.
        -- No slotID match required; the CTU type itself confirms player authorship.
        canRoute = true
        slotID = "DoT_unattributed" -- string only, for logging
        confidence = "LOW"
    end

    _seq = _seq + 1
    table.insert(TS_DesigConfig.EnsureLogTable("ctuCaptured"), {
        seq = _seq,
        ctuType = ctuType,
        valueStr = valueStr,
        correlatedSpellID = slotID,
        desig = expectedDesig,
        confidence = confidence
    })

    local resolvedSpellID = nil
    if ctuType == "PERIODIC_HEAL" or ctuType == "PERIODIC_HEAL_CRIT" or ctuType ==
        "PERIODIC_DAMAGE" or ctuType == "PERIODIC_DAMAGE_CRIT" then
        -- Periodic events: slot manager match only. Never use cast anchor.
        if type(matchedSpellID) == "number" and matchedSpellID > 0 then
            resolvedSpellID = matchedSpellID
        end
    else
        -- Direct events: prefer cast anchor, fall back to slot match.
        if type(lastSpellID) == "number" and lastSpellID > 0 then
            resolvedSpellID = lastSpellID
        elseif type(matchedSpellID) == "number" and matchedSpellID > 0 then
            resolvedSpellID = matchedSpellID
        end
    end

    if TSBT.PipelineDiag then
        if canRoute then
            TSBT.PipelineDiag.canRouteTrue = TSBT.PipelineDiag.canRouteTrue + 1
            TSBT.PipelineDiag.lastSpellID = resolvedSpellID or 0
        else
            TSBT.PipelineDiag.canRouteFalse =
                TSBT.PipelineDiag.canRouteFalse + 1
        end
    end

    if canRoute then
        RouteToDisplay(ctuType, valueStr, resolvedSpellID, isCrit, arg3)
    end
end
