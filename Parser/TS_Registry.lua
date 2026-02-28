local ADDON_NAME, TSBT = ...

TS_Registry = TS_Registry or {}

TS_Registry.DESIGNATION = {
    HOT = "HoT",
    HEAL = "Heal",
    MELEE = "Melee",
    DAMAGE = "Damage",
    DAMAGE_AOE = "Damage_AoE",
    DOT = "DoT",
    PROC = "Proc",
    IGNORED = "Ignored",
    UNKNOWN = "Unknown",
}

TS_Registry.HEAL_FAMILY = { HoT = true, Heal = true }
TS_Registry.DAMAGE_FAMILY = { Damage = true, Damage_AoE = true, DoT = true, Melee = true }

local _registry = {}

local function EnsureLogTable(key)
    TrueStrikeDB = TrueStrikeDB or {}
    TrueStrikeDB.designationLog = TrueStrikeDB.designationLog or {}
    TrueStrikeDB.designationLog[key] = TrueStrikeDB.designationLog[key] or {}
    return TrueStrikeDB.designationLog[key]
end

local function GetFamily(desig)
    if TS_Registry.HEAL_FAMILY[desig] then
        return "HEAL"
    end
    if TS_Registry.DAMAGE_FAMILY[desig] then
        return "DAMAGE"
    end
    return desig
end

function TS_Registry.RegisterSpell(spellID, name, desig)
    if not spellID or spellID == 0 then
        return
    end

    _registry[spellID] = {
        name = name,
        desig = desig,
    }
end

function TS_Registry.GetDesignation(spellID)
    local entry = _registry[spellID]
    return entry and entry.desig or nil
end

function TS_Registry.TryPromote(spellID, newDesig, confidence, source)
    local existing = _registry[spellID]

    if existing and TS_DesigConfig and TS_DesigConfig.TRUESTRIKE_TYPE_GATE then
        local currentFamily = GetFamily(existing.desig)
        local newFamily = GetFamily(newDesig)
        if currentFamily ~= newFamily then
            table.insert(EnsureLogTable("typeGateFired"), {
                spellID = spellID,
                requestedDesig = newDesig,
                currentDesig = existing.desig,
                blocked = true,
            })
            if TS_DesigConfig.SafeLog then
                TS_DesigConfig.SafeLog("[TS_REG]", string.format("TYPE_GATE_FIRED {spellID=%d,requestedDesig=%s,currentDesig=%s,blocked=true}", spellID, tostring(newDesig), tostring(existing.desig)))
            end
            return false
        end
    end

    local fromDesig = existing and existing.desig or nil
    TS_Registry.RegisterSpell(spellID, existing and existing.name or tostring(spellID), newDesig)
    table.insert(EnsureLogTable("spellPromoted"), {
        spellID = spellID,
        fromDesig = fromDesig,
        toDesig = newDesig,
        confidence = confidence,
        source = source,
    })
    if TS_DesigConfig and TS_DesigConfig.SafeLog then
        TS_DesigConfig.SafeLog("[TS_REG]", string.format("SPELL_PROMOTED {spellID=%d,fromDesig=%s,toDesig=%s,confidence=%s,source=%s}", spellID, tostring(fromDesig), tostring(newDesig), tostring(confidence), tostring(source)))
    end
    return true
end

function TS_Registry.SeedKnownSpells()
    if not (TS_DesigConfig and TS_DesigConfig.TRUESTRIKE_KNOWN_SPELLS_OVERRIDE) then
        return
    end

    local D = TS_Registry.DESIGNATION

    TS_Registry.RegisterSpell(61295, "Riptide", D.HOT)
    TS_Registry.RegisterSpell(77472, "Healing Wave", D.HEAL)
    TS_Registry.RegisterSpell(77451, "Greater Healing Wave", D.HEAL)
    TS_Registry.RegisterSpell(73921, "Healing Rain", D.HOT)
    TS_Registry.RegisterSpell(73920, "Healing Rain", D.IGNORED)
    TS_Registry.RegisterSpell(458357, "Healing Rain", D.IGNORED)
    TS_Registry.RegisterSpell(383648, "Earth Shield", D.PROC)
    TS_Registry.RegisterSpell(974, "Earth Shield", D.PROC)
    TS_Registry.RegisterSpell(379, "Earth Shield", D.PROC)
    TS_Registry.RegisterSpell(5394, "Healing Stream Totem", D.IGNORED)
    TS_Registry.RegisterSpell(52042, "Healing Stream", D.HOT)
    TS_Registry.RegisterSpell(470411, "Voltaic Blaze", D.DAMAGE_AOE)
    TS_Registry.RegisterSpell(1064, "Chain Heal", D.HEAL)
    TS_Registry.RegisterSpell(51945, "Earthliving", D.PROC)

    -- TODO: verify spellID for Riptide cast variant from handoff section 4.9.
end
