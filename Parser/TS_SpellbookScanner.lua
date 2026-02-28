local ADDON_NAME, TSBT = ...

TS_SpellbookScanner = TS_SpellbookScanner or {}

local _spellbookScanned = false

local function ScanSlot(bookType, slot)
    local spellType, spellID = GetSpellBookItemInfo(slot, bookType)
    if spellType ~= "SPELL" or not spellID then
        return
    end

    if TS_Registry.GetDesignation(spellID) then
        return
    end

    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    local name = info and info.name or tostring(spellID)
    local desig = TS_Registry.DESIGNATION.UNKNOWN

    if C_Spell and C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(spellID) then
        desig = TS_Registry.DESIGNATION.IGNORED
    end

    TS_Registry.RegisterSpell(spellID, name, desig)
end

function TS_SpellbookScanner.ScanSpellbook()
    if not (TS_DesigConfig and TS_DesigConfig.TRUESTRIKE_SPELLBOOK_SCAN) then
        return
    end

    local tabs = GetNumSpellTabs()
    for tab = 1, tabs do
        local _, _, offset, numSlots = GetSpellTabInfo(tab)
        for i = 1, numSlots do
            ScanSlot("spell", offset + i)
        end
    end

    _spellbookScanned = true
end

function TS_SpellbookScanner.OnSpellsChanged()
    if not (TS_DesigConfig and TS_DesigConfig.TRUESTRIKE_SPELLBOOK_SCAN) then
        return
    end

    _spellbookScanned = false
    TS_SpellbookScanner.ScanSpellbook()
end

--[[ FLAGGED: Spellbook scan on PLAYER_ENTERING_WORLD
     Why flagged:         SPELLS_CHANGED is the confirmed trigger for spellbook refresh.
     Evidence gap:        No requirement or evidence supports PEW as the primary scan trigger.
     Acceptance criteria: Probe data confirms PEW-only scan is complete and stable.
     Default behavior:    Scan is handled by OnSpellsChanged; no PEW-triggered scan here.
     Feature flag:        TRUESTRIKE_SPELLBOOK_SCAN
--]]
