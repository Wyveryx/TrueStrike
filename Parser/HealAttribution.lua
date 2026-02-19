------------------------------------------------------------------------
-- TrueStrike Battle Text - Heal Attribution System
--
-- Provides spell attribution for incoming heals using COMBAT_TEXT_UPDATE.
-- Works within WoW 12.0's "Secret Values" constraints where heal amounts
-- can be displayed but not compared or used in calculations.
--
-- Attribution Strategies (in priority order):
-- 1. CastTime - Matches heals to spells currently being cast (UNIT_SPELLCAST_START)
-- 2. Instant  - Matches heals to recently sent instant casts (UNIT_SPELLCAST_SENT)
-- 3. HoT      - Matches periodic heals to active HoT buffs (UNIT_AURA)
-- 4. Proc     - Fallback for unattributed heals (passive procs, item effects)
--
-- IMPORTANT: This module requires the CVar 'enableFloatingCombatText' to be
-- set to 1 for COMBAT_TEXT_UPDATE events to fire. The visual display can be
-- disabled separately via the same CVar set to 0 AFTER events are captured,
-- or users can uncheck "Scrolling Combat Text" in Interface options.
------------------------------------------------------------------------

local ADDON_NAME, TSBT = ...

TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.HealAttribution = TSBT.Parser.HealAttribution or {}

local HealAttr = TSBT.Parser.HealAttribution

------------------------------------------------------------------------
-- Module State
------------------------------------------------------------------------
HealAttr._enabled = false
HealAttr._frame = nil

-- Cast-time spell tracking (UNIT_SPELLCAST_START)
HealAttr._pendingCast = nil

-- Spell tracking (UNIT_SPELLCAST_SENT)
-- Covers both instant casts and cast-time spells (Healing Wave ~1.5s cast)
HealAttr._sentSpells = {}
HealAttr._sentExpire = 3.0  -- 3 second window to cover cast-time spells

-- Active HoT tracking (UNIT_AURA)
HealAttr._activeHoTs = {}

------------------------------------------------------------------------
-- CTU Event Types
------------------------------------------------------------------------
local HEAL_EVENTS = {
    HEAL = true,
    HEAL_CRIT = true,
    PERIODIC_HEAL = true,
    PERIODIC_HEAL_CRIT = true,
}

------------------------------------------------------------------------
-- Debug Helper (uses Addon:DebugPrint, respects debug level setting)
------------------------------------------------------------------------
local function Debug(level, ...)
    local Addon = TSBT.Addon
    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(level, "[HealAttr]", ...)
    end
end

------------------------------------------------------------------------
-- Spell Info Helper (WoW 12.0 compatible)
------------------------------------------------------------------------
local function GetSpellInfo(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        return C_Spell.GetSpellInfo(spellID)
    end
    return nil
end

------------------------------------------------------------------------
-- HoT Aura Scanning
-- Scans player buffs for active HoTs defined in user configuration.
------------------------------------------------------------------------
local function ScanPlayerHoTs()
    HealAttr._activeHoTs = {}

    -- Get user-configured HoT spell IDs
    local hotSpellIDs = TSBT.db and TSBT.db.profile
        and TSBT.db.profile.incoming
        and TSBT.db.profile.incoming.healing
        and TSBT.db.profile.incoming.healing.hotSpellIDs

    if not hotSpellIDs or not next(hotSpellIDs) then
        return -- No HoTs configured
    end

    -- Scan player buffs
    for i = 1, 40 do
        local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not aura then break end

        if aura.spellId and hotSpellIDs[aura.spellId] then
            HealAttr._activeHoTs[aura.spellId] = {
                name = aura.name,
                icon = aura.icon,
                spellId = aura.spellId,
            }
        end
    end
end

------------------------------------------------------------------------
-- Attribution Strategies
------------------------------------------------------------------------

--- Try to match a heal to a spell currently being cast.
-- CONSUMES the pending cast so it won't match subsequent heals (like procs).
-- @return table|nil match, string strategy
local function TryMatchCastTime()
    if HealAttr._pendingCast then
        local match = HealAttr._pendingCast
        HealAttr._pendingCast = nil  -- Consume it
        return match, "CastTime"
    end
    return nil
end

--- Try to match a heal to a recently sent spell cast.
-- Iterates OLDEST first because CTU events fire in cast completion order.
-- @param now number Current time from GetTime()
-- @return table|nil match, string strategy
local function TryMatchInstant(now)
    -- First, prune expired spells from the front
    while #HealAttr._sentSpells > 0 do
        local spell = HealAttr._sentSpells[1]
        local delta = now - spell.time
        if delta > HealAttr._sentExpire then
            -- Too old, remove it
            table.remove(HealAttr._sentSpells, 1)
            Debug(3, "MATCH: Expired", spell.name, "- age:", string.format("%.0fms", delta * 1000))
        else
            -- Found a valid spell (oldest), match and consume it
            table.remove(HealAttr._sentSpells, 1)
            return spell, string.format("Matched(%.0fms)", delta * 1000)
        end
    end
    return nil
end

--- Try to match a periodic heal to an active HoT buff.
-- @return table|nil match, string strategy
local function TryMatchHoT()
    local count = 0
    local lastHoT = nil

    for spellId, hotData in pairs(HealAttr._activeHoTs) do
        count = count + 1
        lastHoT = hotData
    end

    if count == 1 then
        return lastHoT, "HoT"
    elseif count > 1 then
        -- Multiple HoTs active - cannot determine which one
        return nil, "HoT(ambiguous)"
    end

    return nil
end

--- Main attribution function - tries strategies in priority order.
-- @param now number Current time from GetTime()
-- @param eventType string CTU event type (HEAL, PERIODIC_HEAL, etc.)
-- @return table|nil match, string strategy
local function AttributeHeal(now, eventType)
    -- 1. Try spell match from sent queue (covers both instant and cast-time spells)
    -- Using _sentSpells with 3s window handles cast-time spells correctly
    local match, strategy = TryMatchInstant(now)
    if match then return match, strategy end

    -- 2. For periodic heals, try HoT match
    if eventType == "PERIODIC_HEAL" or eventType == "PERIODIC_HEAL_CRIT" then
        match, strategy = TryMatchHoT()
        if match then return match, strategy end
        return nil, strategy or "Proc"
    end

    -- 3. Fallback to Proc (passive effects, item procs, etc.)
    return nil, "Proc"
end

------------------------------------------------------------------------
-- Prune Helpers
------------------------------------------------------------------------
local function PruneSentSpells(now)
    for i = #HealAttr._sentSpells, 1, -1 do
        if (now - HealAttr._sentSpells[i].time) > HealAttr._sentExpire then
            table.remove(HealAttr._sentSpells, i)
        end
    end
end

------------------------------------------------------------------------
-- Event Handlers
------------------------------------------------------------------------
local function OnEvent(self, event, arg1, ...)
    if not HealAttr._enabled then return end

    local now = GetTime()

    -- UNIT_AURA: Track active HoT buffs
    if event == "UNIT_AURA" and arg1 == "player" then
        ScanPlayerHoTs()
        return
    end

    -- UNIT_SPELLCAST_SENT: Track instant casts (fires before CTU)
    if event == "UNIT_SPELLCAST_SENT" and arg1 == "player" then
        local target, castGUID, spellID = ...
        if spellID then
            local info = GetSpellInfo(spellID)
            if info then
                -- WoW 12.0: Try iconID first, then originalIconID, then icon
                local iconTexture = info.iconID or info.originalIconID or info.icon
                table.insert(HealAttr._sentSpells, {
                    name = info.name,
                    icon = iconTexture,
                    spellID = spellID,
                    time = now,
                })
                PruneSentSpells(now)
                Debug(1, "SENT:", info.name, "| icon:", iconTexture and "yes" or "nil", "| queue#:", #HealAttr._sentSpells)
            else
                Debug(1, "SENT: GetSpellInfo returned nil for spellID:", spellID)
            end
        else
            Debug(1, "SENT: spellID is nil")
        end
        return
    end

    -- UNIT_SPELLCAST_START: Track cast-time spells
    if event == "UNIT_SPELLCAST_START" and arg1 == "player" then
        local castGUID, spellID = ...
        local info = GetSpellInfo(spellID)
        if info then
            -- WoW 12.0: Try iconID first, then originalIconID, then icon
            local iconTexture = info.iconID or info.originalIconID or info.icon
            HealAttr._pendingCast = {
                name = info.name,
                icon = iconTexture,
                spellID = spellID,
            }
            Debug(3, "CASTING:", info.name)
        end
        return
    end

    -- UNIT_SPELLCAST_STOP / INTERRUPTED: Clear pending cast
    if (event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED")
        and arg1 == "player" then
        HealAttr._pendingCast = nil
        return
    end

    -- UNIT_SPELLCAST_SUCCEEDED: Don't clear _pendingCast here!
    -- When chain-casting, the timer would incorrectly clear the NEXT spell's pending cast.
    -- Instead, _pendingCast is consumed by TryMatchCastTime or cleared on STOP/INTERRUPTED.
    if event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
        -- Just let it pass - _pendingCast will be consumed when CTU fires
        return
    end

    -- COMBAT_TEXT_UPDATE: Main heal attribution
    if event == "COMBAT_TEXT_UPDATE" and HEAL_EVENTS[arg1] then
        local data, arg3 = C_CombatText.GetCurrentEventInfo()

        -- Check if healing display is enabled
        local healConf = TSBT.db and TSBT.db.profile
            and TSBT.db.profile.incoming
            and TSBT.db.profile.incoming.healing
        if not healConf or not healConf.enabled then return end

        -- Check if HoT ticks should be shown
        local isPeriodic = (arg1 == "PERIODIC_HEAL" or arg1 == "PERIODIC_HEAL_CRIT")
        if isPeriodic and not healConf.showHoTTicks then return end

        -- Attribute the heal
        local match, strategy = AttributeHeal(now, arg1)

        -- Build display info
        local displayInfo = {
            kind = "heal",
            isCrit = (arg1 == "HEAL_CRIT" or arg1 == "PERIODIC_HEAL_CRIT"),
            isPeriodic = isPeriodic,
            spellName = match and match.name or nil,
            spellIcon = match and match.icon or nil,
            spellID = match and match.spellID or nil,
            strategy = strategy,
            timestamp = now,
        }

        -- Debug: Show attribution result (level 1 for visibility)
        if not match then
            -- Attribution failed - show diagnostic info
            Debug(1, "HEAL:", arg1, "| No match |",
                "pending:", HealAttr._pendingCast and HealAttr._pendingCast.name or "nil",
                "| sent#:", #HealAttr._sentSpells)
        else
            Debug(1, "HEAL:", arg1, "->", match.name, "(", strategy, ")")
        end

        -- Route to display system
        -- The amount (arg3) is a SECRET VALUE - can only be passed to SetText()
        HealAttr:EmitHeal(displayInfo, arg3)
    end
end

------------------------------------------------------------------------
-- Emit Heal to Display System
-- @param info table Attribution info (spellName, spellIcon, isCrit, etc.)
-- @param secretAmount any The heal amount (SECRET VALUE - display only)
------------------------------------------------------------------------
function HealAttr:EmitHeal(info, secretAmount)
    -- Check if spell info should be shown
    local showSpellInfo = TSBT.db and TSBT.db.profile
        and TSBT.db.profile.incoming
        and TSBT.db.profile.incoming.healing
        and TSBT.db.profile.incoming.healing.showSpellInfo

    local scrollArea = TSBT.db and TSBT.db.profile
        and TSBT.db.profile.incoming
        and TSBT.db.profile.incoming.healing
        and TSBT.db.profile.incoming.healing.scrollArea
        or "Incoming"

    -- Build display text
    -- NOTE: secretAmount must be passed directly to SetText via tostring()
    -- It CANNOT be stored in a table or concatenated in advance.
    local prefix = ""
    if showSpellInfo and info.spellName then
        prefix = info.spellName .. ": +"
    elseif not showSpellInfo then
        prefix = "+"
    else
        prefix = "(Proc): +"
    end

    -- Determine color
    local color = { r = 0.2, g = 1.0, b = 0.2 }  -- Default green for heals
    if TSBT.db and TSBT.db.profile and TSBT.db.profile.incoming then
        local inc = TSBT.db.profile.incoming
        if inc.customColor and inc.customColor.r then
            local c = inc.customColor
            if not (c.r == 1 and c.g == 1 and c.b == 1) then
                color = { r = c.r, g = c.g, b = c.b }
            end
        end
    end

    -- Emit to display system
    local meta = {
        kind = "heal",
        spellName = info.spellName,
        spellIcon = info.spellIcon,
        isCrit = info.isCrit,
        isPeriodic = info.isPeriodic,
        strategy = info.strategy,
    }

    -- Call the display function with the secret amount
    -- The display layer must use: text:SetText(prefix .. tostring(secretAmount))
    if TSBT.DisplayHealWithSecret then
        TSBT.DisplayHealWithSecret(scrollArea, prefix, secretAmount, color, meta)
    elseif TSBT.DisplayText then
        -- Fallback: build text here (may not work if DisplayText can't handle secrets)
        local text = prefix .. tostring(secretAmount)
        TSBT.DisplayText(scrollArea, text, color, meta)
    end
end

------------------------------------------------------------------------
-- Enable / Disable
------------------------------------------------------------------------
function HealAttr:Enable()
    if self._enabled then return end

    -- Create frame if needed
    if not self._frame then
        self._frame = CreateFrame("Frame")
    end

    -- Register events
    self._frame:RegisterEvent("COMBAT_TEXT_UPDATE")
    self._frame:RegisterEvent("UNIT_SPELLCAST_SENT")
    self._frame:RegisterEvent("UNIT_SPELLCAST_START")
    self._frame:RegisterEvent("UNIT_SPELLCAST_STOP")
    self._frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self._frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self._frame:RegisterEvent("UNIT_AURA")

    self._frame:SetScript("OnEvent", OnEvent)

    -- Initial HoT scan
    ScanPlayerHoTs()

    self._enabled = true
    Debug(1, "Enabled")
end

function HealAttr:Disable()
    if not self._enabled then return end

    if self._frame then
        self._frame:UnregisterAllEvents()
        self._frame:SetScript("OnEvent", nil)
    end

    -- Clear state
    self._pendingCast = nil
    self._sentSpells = {}
    self._activeHoTs = {}

    self._enabled = false
    Debug(1, "Disabled")
end

------------------------------------------------------------------------
-- Initialization
------------------------------------------------------------------------
function HealAttr:Init()
    Debug(1, "Initialized")
end
