local ADDON_NAME, TSBT = ...

TS_SpellbookScanner = TS_SpellbookScanner or {}

local _spellbookScanned = false
local _spellbookCache = {}

local function RegisterSpellDesignation(spellID, desig)
    if not spellID then
        return
    end

    if TS_Registry.GetDesignation(spellID) then
        return
    end

    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    local name = info and info.name or tostring(spellID)
    TS_Registry.RegisterSpell(spellID, name, desig)
    _spellbookCache[spellID] = true
end

function TS_SpellbookScanner.ScanSpellbook()
    if not (TS_DesigConfig and TS_DesigConfig.TRUESTRIKE_SPELLBOOK_SCAN) then
        return
    end

    _spellbookCache = {}

    local skillLineCount = C_SpellBook.GetNumSpellBookSkillLines()
    for i = 1, skillLineCount do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
        if skillLineInfo then
            local itemIndexOffset = skillLineInfo.itemIndexOffset or 0
            local numSpellBookItems = skillLineInfo.numSpellBookItems or 0

            for j = itemIndexOffset + 1, itemIndexOffset + numSpellBookItems do
                local itemInfo = C_SpellBook.GetSpellBookItemInfo(j, Enum.SpellBookSpellBank.Player)
                if itemInfo then
                    local itemType = itemInfo.itemType
                    local spellID = itemInfo.actionID

                    if itemType == Enum.SpellBookItemType.Spell then
                        local desig = TS_Registry.DESIGNATION.UNKNOWN
                        if C_Spell and C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(spellID) then
                            desig = TS_Registry.DESIGNATION.IGNORED
                        end
                        RegisterSpellDesignation(spellID, desig)
                    elseif itemType == Enum.SpellBookItemType.FutureSpell then
                        -- FUTURESPELL
                        RegisterSpellDesignation(spellID, TS_Registry.DESIGNATION.UNKNOWN)
                    end
                end
            end
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


function TS_SpellbookScanner.GetCache()
    return _spellbookCache or {}
end

--[[ FLAGGED: Spellbook scan on PLAYER_ENTERING_WORLD
     Why flagged:         SPELLS_CHANGED is the confirmed trigger for spellbook refresh.
     Evidence gap:        No requirement or evidence supports PEW as the primary scan trigger.
     Acceptance criteria: Probe data confirms PEW-only scan is complete and stable.
     Default behavior:    Scan is handled by OnSpellsChanged; no PEW-triggered scan here.
     Feature flag:        TRUESTRIKE_SPELLBOOK_SCAN
--]]
