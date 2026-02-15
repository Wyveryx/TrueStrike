------------------------------------------------------------------------
-- TrueStrike - Incoming Detection (UI/UX Validation)
--
-- Responsibility:
--   - Listen to UNIT_COMBAT for the *player unit* only
--   - Normalize the raw payload into a small IncomingEvent contract
--   - Forward to Core.IncomingProbe for capture + replay
--
-- Notes:
--   - Exists ONLY to validate the Incoming UI/UX.
--   - No GUID usage, no attribution, no aggregation.
--   - Designed to avoid secret-value landmines by never touching identity APIs.
------------------------------------------------------------------------
local ADDON_NAME, TSBT = ...

TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.Incoming = TSBT.Parser.Incoming or {}
local Incoming = TSBT.Parser.Incoming
local Addon    = TSBT.Addon

Incoming._enabled = Incoming._enabled or false
Incoming._frame   = Incoming._frame or nil

local function Debug(level, ...)
    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(level, ...)
    end
end

local function NormalizeUnitCombat(unitTarget, event, flagText, amount, schoolMask)
    -- Defensive: UNIT_COMBAT payload may vary across builds.
    if unitTarget ~= "player" then return nil end

    local evt = tostring(event or "")
    local amt = tonumber(amount)
    if not amt or amt <= 0 then return nil end

    -- UNIT_COMBAT "event" values are historically things like WOUND/HEAL/etc.
    -- We intentionally use a conservative classifier.
    local kind
    local up = evt:upper()
    if up:find("HEAL", 1, true) then
        kind = "heal"
    else
        -- Treat anything not explicitly a heal as damage for UI probing.
        kind = "damage"
    end

    return {
        ts        = (GetTime and GetTime()) or 0,
        kind      = kind,
        amount    = amt,
        flagText  = (type(flagText) == "string" and flagText ~= "") and flagText or nil,
        schoolMask = tonumber(schoolMask),
    }
end

function Incoming:Enable()
    if self._enabled then return end
    self._enabled = true

    Debug(1, "Parser.Incoming:Enable()")

    if not self._frame then
        local f = CreateFrame("Frame")
        f:Hide()
        self._frame = f
    end

    self._frame:SetScript("OnEvent", function(_, _, ...)
        local ok, evtOrErr = pcall(function(...)
            local unitTarget, event, flagText, amount, schoolMask = ...
            return NormalizeUnitCombat(unitTarget, event, flagText, amount, schoolMask)
        end, ...)

        if not ok then
            -- If Blizzard changes something and we start erroring, do not spam.
            Debug(1, "Parser.Incoming UNIT_COMBAT error:", tostring(evtOrErr))
            return
        end

        local evt = evtOrErr
        if not evt then return end

        local probe = TSBT.Core and TSBT.Core.IncomingProbe
        if probe and probe.OnIncomingDetected then
            probe:OnIncomingDetected(evt)
        end
    end)

    self._frame:RegisterEvent("UNIT_COMBAT")
    self._frame:Show()
end

function Incoming:Disable()
    if not self._enabled then return end
    self._enabled = false

    Debug(1, "Parser.Incoming:Disable()")

    if self._frame then
        self._frame:UnregisterEvent("UNIT_COMBAT")
        self._frame:SetScript("OnEvent", nil)
        self._frame:Hide()
    end
end
