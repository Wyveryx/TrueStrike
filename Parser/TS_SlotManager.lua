local ADDON_NAME, TSBT = ...

TS_SlotManager = TS_SlotManager or {}

local _hotSlots = {}
local _slotCounter = 0

local function EnsureLogTable(key)
    TrueStrikeDB = TrueStrikeDB or {}
    TrueStrikeDB.designationLog = TrueStrikeDB.designationLog or {}
    TrueStrikeDB.designationLog[key] = TrueStrikeDB.designationLog[key] or {}
    return TrueStrikeDB.designationLog[key]
end

local function LogCreated(slot)
    table.insert(EnsureLogTable("hotSlots"), {
        slotID = slot.slotID,
        spellID = slot.spellID,
        unit = slot.unit,
        expirationTime = slot.expirationTime,
        source = slot.source,
    })
    if TS_DesigConfig and TS_DesigConfig.SafeLog then
        TS_DesigConfig.SafeLog("[TS_SLOT]", string.format("HOT_SLOT_CREATED {slotID=%s,spellID=%s,unit=%s,expirationTime=%s,source=%s}", tostring(slot.slotID), tostring(slot.spellID), tostring(slot.unit), tostring(slot.expirationTime), tostring(slot.source)))
    end
end

local function LogExpired(slot)
    table.insert(EnsureLogTable("hotSlots"), {
        slotID = slot.slotID,
        spellID = slot.spellID,
        tickCount = slot.tickCount,
        expired = true,
    })
    if TS_DesigConfig and TS_DesigConfig.SafeLog then
        TS_DesigConfig.SafeLog("[TS_SLOT]", string.format("HOT_SLOT_EXPIRED {slotID=%s,spellID=%s,tickCount=%s}", tostring(slot.slotID), tostring(slot.spellID), tostring(slot.tickCount)))
    end
end

function TS_SlotManager.NewHotSlot(spellID, spellName, unit, expirationTime, duration, source)
    if not (TS_DesigConfig and TS_DesigConfig.TRUESTRIKE_HOT_SLOT_LIFECYCLE) then
        return nil
    end

    _slotCounter = _slotCounter + 1
    local slot = {
        slotID = string.format("HoT%d", _slotCounter),
        spellID = spellID,
        spellName = spellName,
        unit = unit,
        assignedTime = GetTime(),
        expirationTime = expirationTime,
        duration = duration,
        tickCount = 0,
        source = source,
    }

    table.insert(_hotSlots, slot)
    LogCreated(slot)
    return slot
end

function TS_SlotManager.FindHotSlot(spellID, unit)
    local now = GetTime()
    for _, slot in ipairs(_hotSlots) do
        if slot.expirationTime and slot.expirationTime >= now and slot.spellID == spellID and slot.unit == unit then
            return slot
        end
    end
    return nil
end

function TS_SlotManager.RemoveSlotsBySpellID(spellID)
    for i = #_hotSlots, 1, -1 do
        if _hotSlots[i].spellID == spellID then
            LogExpired(_hotSlots[i])
            table.remove(_hotSlots, i)
        end
    end
end

function TS_SlotManager.PruneExpiredSlots()
    local now = GetTime()
    for i = #_hotSlots, 1, -1 do
        local slot = _hotSlots[i]
        if slot.expirationTime and slot.expirationTime < now then
            LogExpired(slot)
            table.remove(_hotSlots, i)
        end
    end
end

function TS_SlotManager.GetActiveSlots()
    return _hotSlots
end

function TS_SlotManager.CreateSyntheticTotemSlot(summonSpellID, tickSpellID, tickSpellName, durationSeconds)
    if not (TS_DesigConfig and TS_DesigConfig.TRUESTRIKE_SYNTHETIC_TOTEM_SLOTS) then
        return nil
    end

    return TS_SlotManager.NewHotSlot(
        tickSpellID,
        tickSpellName,
        "synthetic_totem",
        GetTime() + durationSeconds,
        durationSeconds,
        "SYNTHETIC_TOTEM"
    )
end
