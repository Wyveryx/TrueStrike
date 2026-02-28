local ADDON_NAME, TSBT = ...

TS_DesigConfig = TS_DesigConfig or {}

-- Empirically fixed by probe runs; do not change without a new probe campaign.
TS_DesigConfig.PROMOTION_WINDOW_SECONDS = 0.150

TS_DesigConfig.TRUESTRIKE_CAST_ANCHOR_ENABLED = true
TS_DesigConfig.TRUESTRIKE_HOT_SLOT_LIFECYCLE = true
TS_DesigConfig.TRUESTRIKE_TYPE_GATE = true
TS_DesigConfig.TRUESTRIKE_SPELLBOOK_SCAN = true
TS_DesigConfig.TRUESTRIKE_PRECOMBAT_AURA_SCAN = true
TS_DesigConfig.TRUESTRIKE_SYNTHETIC_TOTEM_SLOTS = true
TS_DesigConfig.TRUESTRIKE_KNOWN_SPELLS_OVERRIDE = true
TS_DesigConfig.TRUESTRIKE_UNIT_COMBAT_PROBE = false
TS_DesigConfig.TRUESTRIKE_MELEE_ATTRIBUTION = false
TS_DesigConfig.TRUESTRIKE_AURA_INSTANCE_PROBE = false
TS_DesigConfig.TRUESTRIKE_INCOMBAT_HOT_CREATION = false
TS_DesigConfig.TRUESTRIKE_INCOMING_HEAL_PROBE = false
TS_DesigConfig.TRUESTRIKE_CLASS_DB_DRUID = false
TS_DesigConfig.TRUESTRIKE_CLASS_DB_PRIEST = false
TS_DesigConfig.TRUESTRIKE_CLASS_DB_PALADIN = false
TS_DesigConfig.TRUESTRIKE_CLASS_DB_MONK = false
TS_DesigConfig.DEBUG_LOGGING = false

local function SafeLog(prefix, msg)
    if not TS_DesigConfig.DEBUG_LOGGING then
        return
    end

    print(string.format("%s %s", prefix or "[TS_CFG]", msg or ""))
end

TS_DesigConfig.SafeLog = SafeLog
