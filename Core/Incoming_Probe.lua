------------------------------------------------------------------------
-- TrueStrike - Incoming Probe / Replay Harness (UI/UX Validation)
--
-- Purpose:
--   - Capture *real* incoming events (from Parser.Incoming) into a ring buffer
--   - Derive a small capabilities report based on observed fields
--   - Replay captured events through Display routing to validate UI/UX
--
-- Non-goals:
--   - This is NOT the engine.
--   - No attribution, aggregation, throttling, or spam policy.
--   - No secret-value identity work.
------------------------------------------------------------------------
local ADDON_NAME, TSBT = ...

TSBT.Core = TSBT.Core or {}
TSBT.Core.IncomingProbe = TSBT.Core.IncomingProbe or {}
local Probe = TSBT.Core.IncomingProbe
local Addon = TSBT.Addon

-- Internal state
Probe._initialized = Probe._initialized or false
Probe._capturing = Probe._capturing or false
Probe._replaying = Probe._replaying or false
Probe._captureEnds = Probe._captureEnds or 0
Probe._ticker = Probe._ticker or nil

Probe._maxBuffer = Probe._maxBuffer or 200
Probe._buffer = Probe._buffer or {}
Probe._bufHead = Probe._bufHead or 0
Probe._bufCount = Probe._bufCount or 0

-- Observed field values during current capture window
Probe._seenSchoolMasks = Probe._seenSchoolMasks or {}
Probe._seenSchoolsList = Probe._seenSchoolsList or {}

-- Capability report is based on what we observe during capture.
-- Values:
--   nil  = unknown (not observed yet)
--   true = observed
--   false = observed unavailable/impossible in current source
Probe.cap = Probe.cap or {
    source = "UNIT_COMBAT",
    hasAmount = true, -- required
    hasFlagText = nil,
    hasSchool = nil,
    hasPeriodic = false -- UNIT_COMBAT does not provide reliable periodic classification
}

local function Now() return (GetTime and GetTime()) or 0 end

local function Debug(level, ...)
    if Addon and Addon.DebugPrint then Addon:DebugPrint(level, ...) end
end

local function PushEvent(evt)
    -- Ring buffer.
    Probe._bufHead = (Probe._bufHead % Probe._maxBuffer) + 1
    Probe._buffer[Probe._bufHead] = evt
    Probe._bufCount = math.min(Probe._bufCount + 1, Probe._maxBuffer)
end

local function SnapshotBuffer()
    -- Return events in chronological order.
    local out = {}
    if Probe._bufCount == 0 then return out end

    local start = Probe._bufHead - Probe._bufCount + 1
    for i = 0, Probe._bufCount - 1 do
        local idx = start + i
        while idx <= 0 do idx = idx + Probe._maxBuffer end
        while idx > Probe._maxBuffer do idx = idx - Probe._maxBuffer end
        out[#out + 1] = Probe._buffer[idx]
    end
    return out
end

local function SchoolColorFromMask(mask)
    -- Minimal school coloring for UX testing. Multi-school masks fall back.
    if type(mask) ~= "number" then return nil end

    local band = (bit and bit.band) or (bit32 and bit32.band)
    if type(band) ~= "function" then
        -- If bitlib is unavailable for some reason, do not attempt masking.
        return nil
    end

    local single = mask
    -- If multiple bits are set, skip coloring (engine can refine later).
    if single and single > 0 and band(single, single - 1) ~= 0 then
        return nil
    end

    -- Treat PHYSICAL as "no school color" for UI/UX, so we still
    -- get damage/heal distinction (red/green) instead of everything turning white.
    if single == TSBT.SCHOOL_PHYSICAL then
        return nil
    end
    if single == TSBT.SCHOOL_HOLY then return {r = 1.00, g = 0.90, b = 0.50} end
    if single == TSBT.SCHOOL_FIRE then return {r = 1.00, g = 0.35, b = 0.20} end
    if single == TSBT.SCHOOL_NATURE then
        return {r = 0.30, g = 1.00, b = 0.30}
    end
    if single == TSBT.SCHOOL_FROST then return {r = 0.50, g = 0.85, b = 1.00} end
    if single == TSBT.SCHOOL_SHADOW then
        return {r = 0.65, g = 0.45, b = 1.00}
    end
    if single == TSBT.SCHOOL_ARCANE then
        return {r = 0.60, g = 0.60, b = 1.00}
    end
    return nil
end

function Probe:Init()
    if self._initialized then return end
    self._initialized = true
    Debug(1, "Core.IncomingProbe:Init()")
end

function Probe:IsCapturing() return self._capturing == true end

function Probe:IsReplaying() return self._replaying == true end

function Probe:ResetCapture()
    self._buffer = {}
    self._bufHead = 0
    self._bufCount = 0

    self.cap.hasFlagText = nil
    self.cap.hasSchool = nil
    -- hasPeriodic remains false by design for UNIT_COMBAT.

    self._seenSchoolMasks = {}
    self._seenSchoolsList = {}
end

function Probe:StartCapture(seconds)
    self:Init()

    if self._capturing then return end
    self:StopReplay()

    seconds = tonumber(seconds) or 10
    if seconds < 1 then seconds = 1 end
    if seconds > 60 then seconds = 60 end

    self:ResetCapture()

    self._capturing = true
    self._captureEnds = Now() + seconds

    Debug(1, ("Core.IncomingProbe:StartCapture(%ss)"):format(seconds))
    if Addon and Addon.Print then
        Addon:Print(
            ("Incoming probe capture started (%ss). Go get hit / get healed."):format(
                seconds))
    end

    -- Auto-stop timer.
    C_Timer.After(seconds, function()
        if Probe and Probe._capturing then Probe:StopCapture(true) end
    end)
end

function Probe:StopCapture(auto)
    if not self._capturing then return end
    self._capturing = false
    self._captureEnds = 0

    Debug(1, "Core.IncomingProbe:StopCapture()")

    if Addon and Addon.Print then
        Addon:Print(("Incoming probe capture %s. Captured %d events."):format(
                        auto and "ended" or "stopped", self._bufCount))

        if self._seenSchoolsList and #self._seenSchoolsList > 0 then
            table.sort(self._seenSchoolsList)
            local maxShow = 12
            local parts = {}
            for i = 1, math.min(#self._seenSchoolsList, maxShow) do
                parts[#parts + 1] = tostring(self._seenSchoolsList[i])
            end
            local suffix = (#self._seenSchoolsList > maxShow) and
                               (" … +" ..
                                   tostring(#self._seenSchoolsList - maxShow)) or
                               ""
            Addon:Print(
                ("Incoming probe observed schoolMask values: %s%s"):format(
                    table.concat(parts, ", "), suffix))
        else
            Addon:Print("Incoming probe observed schoolMask values: (none)")
        end
    end
end

function Probe:Replay(speed)
    self:Init()
    if self._replaying then return end
    self:StopCapture(false)

    local events = SnapshotBuffer()
    if #events == 0 then
        if Addon and Addon.Print then
            Addon:Print(
                "Incoming probe has no captured events to replay. Capture first.")
        end
        return
    end

    speed = tonumber(speed) or 1.0
    if speed < 0.25 then speed = 0.25 end
    if speed > 4.0 then speed = 4.0 end

    self._replaying = true
    local i = 1

    Debug(1, ("Core.IncomingProbe:Replay(speed=%s) events=%d"):format(speed,
                                                                      #events))
    if Addon and Addon.Print then
        Addon:Print(
            ("Incoming probe replay started (%d events, speed x%.2f)."):format(
                #events, speed))
    end

    -- Replay at a fixed interval. We do not preserve original timing; UX test only.
    local interval = 0.20 / speed
    self._ticker = C_Timer.NewTicker(interval, function()
        if not Probe or not Probe._replaying then return end
        local evt = events[i]
        if evt then
            Probe:ProcessIncomingEvent(evt, true)
            i = i + 1
        end

        if i > #events then Probe:StopReplay(true) end
    end)
end

function Probe:StopReplay(auto)
    if not self._replaying then return end
    self._replaying = false

    if self._ticker then
        self._ticker:Cancel()
        self._ticker = nil
    end

    Debug(1, "Core.IncomingProbe:StopReplay()")
    if Addon and Addon.Print then
        Addon:Print(("Incoming probe replay %s."):format(
                        auto and "completed" or "stopped"))
    end
end

function Probe:GetCapabilityReport()
    local cap = self.cap or {}
    local function v(x)
        if x == nil then return "unknown" end
        return x and "yes" or "no"
    end

    return {
        source = cap.source or "?",
        hasFlagText = v(cap.hasFlagText),
        hasSchool = v(cap.hasSchool),
        hasPeriodic = v(cap.hasPeriodic),
        bufferCount = self._bufCount or 0,
        bufferMax = self._maxBuffer or 0,
        schoolMaskCount = (self._seenSchoolsList and #self._seenSchoolsList) or
            0
    }
end

function Probe:PrintCapabilityReport()
    local r = self:GetCapabilityReport()
    if Addon and Addon.Print then
        Addon:Print(
            ("Incoming Probe Capabilities: source=%s, flags=%s, school=%s, periodic=%s, buffer=%d/%d, schools=%d"):format(
                r.source, r.hasFlagText, r.hasSchool, r.hasPeriodic,
                r.bufferCount, r.bufferMax, r.schoolMaskCount or 0))
    end
end

-- Called by Parser.Incoming. This function must be safe: no identity ops.
-- evt = {
--   ts=number, kind="damage"|"heal", amount=number,
--   flagText=string|nil, schoolMask=number|nil
-- }
function Probe:OnIncomingDetected(evt)
    if not evt or type(evt) ~= "table" then return end

    -- Update capabilities only while capturing (keeps the report scoped to current test).
    if self._capturing then
        if self.cap.hasFlagText == nil and type(evt.flagText) == "string" and
            evt.flagText ~= "" then self.cap.hasFlagText = true end
        if self.cap.hasSchool == nil and type(evt.schoolMask) == "number" and
            evt.schoolMask > 0 then self.cap.hasSchool = true end

        if type(evt.schoolMask) == "number" and evt.schoolMask > 0 then
            if not self._seenSchoolMasks[evt.schoolMask] then
                self._seenSchoolMasks[evt.schoolMask] = true
                self._seenSchoolsList[#self._seenSchoolsList + 1] =
                    evt.schoolMask
            end
        end

        PushEvent(evt)
    end

    -- Always display incoming events in real-time.
    -- Capture mode only controls buffer storage, not display.
    self:ProcessIncomingEvent(evt, false)
end

function Probe:ProcessIncomingEvent(evt, isReplay)
    -- Respect user toggles + thresholds.
    if not TSBT.db or not TSBT.db.profile or not TSBT.db.profile.incoming then
        return
    end

    local prof = TSBT.db.profile.incoming

    local kind = evt.kind
    if kind ~= "damage" and kind ~= "heal" then return end

    -- Skip heals here - HealAttribution handles incoming heals via COMBAT_TEXT_UPDATE
    -- with better attribution (spell names, icons). This prevents duplicate display.
    if kind == "heal" then
        return
    end

    local conf = (kind == "damage") and prof.damage or prof.healing
    if not conf or not conf.enabled then return end

    -- Handle both numeric amount (UNIT_COMBAT path) and string amountText (COMBAT_TEXT_UPDATE path)
    local amt = tonumber(evt.amount) or tonumber(evt.amountText) or 0
    if amt <= 0 then return end

    local minT = tonumber(conf.minThreshold) or 0
    if amt < minT then return end

    local area = conf.scrollArea or "Incoming"

    -- Format: use amountText directly if available (preserves original formatting), else format amt
    local text = evt.amountText or tostring(math.floor(amt + 0.5))

    -- Optional flags for damage
    if kind == "damage" and prof.damage.showFlags and type(evt.flagText) ==
        "string" and evt.flagText ~= "" then
        text = text .. " " .. evt.flagText
    end

    -- Optional spell name for heals
    -- NOTE: evt.spellName may be a SECRET STRING VALUE (WoW 12.0)
    -- Secret strings can be displayed but some operations may fail, so we use pcall
    if kind == "heal" and conf.showSpellInfo and evt.spellName then
        local ok, combined = pcall(function()
            return tostring(evt.spellName) .. " +" .. text
        end)
        if ok and combined then
            text = combined
        end
    end

    -- Color
    -- For UI/UX testing, we want damage and healing to be visually distinguishable even
    -- before the real engine can enrich events.
    --
    -- Rules (probe-only):
    --   1) If "Use School Colors" is enabled and we have a single-bit schoolMask, colorize.
    --      (Applies to both damage and healing.)
    --   2) Otherwise, if the user set a non-white customColor, respect it.
    --   3) Otherwise, fall back to kind-based defaults (damage=red, healing=green).
    local color = nil

    if prof.useSchoolColors and type(evt.schoolMask) == "number" then
        color = SchoolColorFromMask(evt.schoolMask)
    end

    local c = prof.customColor
    local hasCustom = (type(c) == "table") and (type(c.r) == "number") and
                          (type(c.g) == "number") and (type(c.b) == "number")

    local customIsWhite = hasCustom and (c.r == 1 and c.g == 1 and c.b == 1)

    if not color and hasCustom and not customIsWhite then
        color = {r = c.r, g = c.g, b = c.b}
    end

    if not color then
        if kind == "heal" then
            color = {r = 0.20, g = 1.00, b = 0.20}
        else
            color = {r = 1.00, g = 0.25, b = 0.25}
        end
    end

    -- Meta is reserved for the real engine.
    local meta = {
        probe = true,
        replay = isReplay == true,
        kind = kind,
        school = evt.schoolMask
    }

    if TSBT.DisplayText then
        TSBT.DisplayText(area, text, color, meta)
    elseif TSBT.Core and TSBT.Core.Display and TSBT.Core.Display.Emit then
        TSBT.Core.Display:Emit(area, text, color, meta)
    end
end
