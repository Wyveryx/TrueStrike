local ADDON_NAME, TSBT = ...

TS_Taint = TS_Taint or {}

local function EnsureLogTable(key)
    TrueStrikeDB = TrueStrikeDB or {}
    TrueStrikeDB.designationLog = TrueStrikeDB.designationLog or {}
    TrueStrikeDB.designationLog[key] = TrueStrikeDB.designationLog[key] or {}
    return TrueStrikeDB.designationLog[key]
end

local function LogTaint(functionName, err, context)
    local entry = {
        ["function"] = functionName,
        error = tostring(err or "unknown"),
        context = context,
    }
    table.insert(EnsureLogTable("taintErrors"), entry)

    if TS_DesigConfig and TS_DesigConfig.SafeLog then
        TS_DesigConfig.SafeLog("[TS_TAINT]", string.format("TAINT_ERROR {function=%s,error=%s,context=%s}", entry["function"], entry.error, tostring(context)))
    end
end

function TS_Taint.SafeStr(val)
    local ok, out = pcall(tostring, val)
    if ok then
        return out
    end

    LogTaint("SafeStr", out, "tostring")
    return "?"
end

function TS_Taint.SafeAuraExtract(unit, index)
    if InCombatLockdown and InCombatLockdown() then
        return nil
    end

    local ok, name, _, _, _, duration, expirationTime, _, _, _, spellID = pcall(UnitAura, unit, index, "HELPFUL|PLAYER")
    if not ok then
        LogTaint("SafeAuraExtract", name, string.format("unit=%s,index=%s", TS_Taint.SafeStr(unit), TS_Taint.SafeStr(index)))
        return nil
    end

    if not name then
        return nil
    end

    return {
        name = name,
        expirationTime = expirationTime,
        duration = duration,
        spellID = spellID,
    }
end

--[[ DISPROVEN: Arithmetic on CTU secret values
     Do not implement. Reason: CTU value is a secret payload; arithmetic access is unsafe in WoW 12.0.1.
     Source: TrueStrike_DesignationEngine_Handoff_v1.md
--]]

--[[ DISPROVEN: tonumber() on any CTU-derived value
     Do not implement. Reason: Converting secret payloads to numbers is forbidden under WoW 12.0.1 constraints.
     Source: TrueStrike_DesignationEngine_Handoff_v1.md
--]]

--[[ DISPROVEN: Secret value as table key
     Do not implement. Reason: Secret payload cannot be used as an index without taint risk.
     Source: TrueStrike_DesignationEngine_Handoff_v1.md
--]]

--[[ DISPROVEN: String laundering via tostring -> concat -> string.match
     Do not implement. Reason: Laundering a secret payload through string ops is still unsafe and closed.
     Source: TrueStrike_DesignationEngine_Handoff_v1.md
--]]
