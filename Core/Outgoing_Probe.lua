------------------------------------------------------------------------
-- TrueStrike - Outgoing Probe / Replay Harness (UI/UX Validation)
--
-- Purpose:
--   - Capture *real* outgoing events (from Parser.Outgoing) into a ring buffer
--   - Replay captured events through display routing to validate the Outgoing UI
--
-- Scope rules for this probe:
--   - Outgoing = player-only. Pet/guardian damage must NOT appear here.
--   - This is NOT the engine. No attribution beyond player-only flag filtering.
--   - No spam control, merging, throttling, or learning.
------------------------------------------------------------------------
local ADDON_NAME, TSBT = ...

TSBT.Core = TSBT.Core or {}
TSBT.Core.OutgoingProbe = TSBT.Core.OutgoingProbe or {}
local Probe = TSBT.Core.OutgoingProbe
local Addon = TSBT.Addon

-- Internal state
Probe._initialized = Probe._initialized or false
Probe._capturing = Probe._capturing or false
Probe._replaying = Probe._replaying or false
Probe._captureEnds = Probe._captureEnds or 0
Probe._ticker = Probe._ticker or nil

Probe._maxBuffer = Probe._maxBuffer or 300
Probe._buffer = Probe._buffer or {}
Probe._bufHead = Probe._bufHead or 0
Probe._bufCount = Probe._bufCount or 0

local function Now() return (GetTime and GetTime()) or 0 end

local function Debug(level, ...)
    if Addon and Addon.DebugPrint then Addon:DebugPrint(level, ...) end
end

local function PushEvent(evt)
    Probe._bufHead = (Probe._bufHead % Probe._maxBuffer) + 1
    Probe._buffer[Probe._bufHead] = evt
    Probe._bufCount = math.min(Probe._bufCount + 1, Probe._maxBuffer)
end

local function SnapshotBuffer()
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

function Probe:Init()
    if self._initialized then return end
    self._initialized = true
    Debug(1, "Core.OutgoingProbe:Init()")
end

function Probe:IsCapturing() return self._capturing == true end
function Probe:IsReplaying() return self._replaying == true end

function Probe:ResetCapture()
    self._buffer = {}
    self._bufHead = 0
    self._bufCount = 0
end

function Probe:StartCapture(seconds)
    self:Init()

    if self._capturing then return end
    self:StopReplay(false)

    seconds = tonumber(seconds) or 30
    if seconds < 1 then seconds = 1 end
    if seconds > 120 then seconds = 120 end

    self:ResetCapture()

    self._capturing = true
    self._captureEnds = Now() + seconds

    Debug(1, ("Core.OutgoingProbe:StartCapture(%ss)"):format(seconds))
    if Addon and Addon.Print then
        Addon:Print(
            ("Outgoing probe capture started (%ss). Auto-attack and cast a few spells; do at least one heal if possible.")
                :format(seconds))
    end

    C_Timer.After(seconds, function()
        if Probe and Probe._capturing then Probe:StopCapture(true) end
    end)
end

function Probe:StopCapture(auto)
    if not self._capturing then return end
    self._capturing = false
    self._captureEnds = 0

    Debug(1, "Core.OutgoingProbe:StopCapture()")
    if Addon and Addon.Print then
        Addon:Print(("Outgoing probe capture %s. Captured %d events.")
                        :format(auto and "ended" or "stopped", self._bufCount))
    end
end

function Probe:Replay(speed)
    self:Init()
    if self._replaying then return end
    self:StopCapture(false)

    local events = SnapshotBuffer()
    if #events == 0 then
        if Addon and Addon.Print then
            Addon:Print("Outgoing probe has no captured events to replay. Capture first.")
        end
        return
    end

    speed = tonumber(speed) or 1.0
    if speed < 0.25 then speed = 0.25 end
    if speed > 4.0 then speed = 4.0 end

    self._replaying = true
    local i = 1

    Debug(1, ("Core.OutgoingProbe:Replay(speed=%s) events=%d"):format(speed, #events))
    if Addon and Addon.Print then
        Addon:Print(("Outgoing probe replay started (%d events, speed x%.2f).")
                        :format(#events, speed))
    end

    local interval = 0.20 / speed
    self._ticker = C_Timer.NewTicker(interval, function()
        if not Probe or not Probe._replaying then return end
        local evt = events[i]
        if evt then
            Probe:ProcessOutgoingEvent(evt, true)
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

    Debug(1, "Core.OutgoingProbe:StopReplay()")
    if Addon and Addon.Print then
        Addon:Print(("Outgoing probe replay %s."):format(auto and "completed" or "stopped"))
    end
end

function Probe:GetStatusLine()
    local cap = {}
    cap.bufferCount = self._bufCount or 0
    cap.bufferMax = self._maxBuffer or 0
    cap.capturing = self._capturing == true
    cap.replaying = self._replaying == true
    return cap
end

-- evt contract from Parser.Outgoing:
-- {
--   ts=number,
--   kind="damage"|"heal",
--   amount=number,
--   overheal=number|nil,
--   isAuto=true|false,
--   isCrit=true|false,
--   spellID=number|nil,
--   spellName=string|nil,
--   targetName=string|nil,
--   schoolMask=number|nil,
-- }
function Probe:OnOutgoingDetected(evt)
    if not evt or type(evt) ~= "table" then return end

    if self._capturing then
        PushEvent(evt)
        -- Emit live during capture.
        self:ProcessOutgoingEvent(evt, false)
    end
end

function Probe:ProcessOutgoingEvent(evt, isReplay)
    if not TSBT.db or not TSBT.db.profile or not TSBT.db.profile.outgoing then
        return
    end

    local prof = TSBT.db.profile.outgoing
    local kind = evt.kind
    if kind ~= "damage" and kind ~= "heal" then return end

    local amt = tonumber(evt.amount) or 0
    if amt <= 0 then return end

    if kind == "damage" then
        local conf = prof.damage
        if not conf or not conf.enabled then return end

        -- Auto-attack filtering.
        if evt.isAuto == true then
            local mode = tostring(conf.autoAttackMode or "Show All")
            if mode == "Hide" then return end
            if mode == "Show Only Crits" and evt.isCrit ~= true then return end
        end

        local minT = tonumber(conf.minThreshold) or 0
        if amt < minT then return end

        local area = conf.scrollArea or "Outgoing"
        local text = tostring(math.floor(amt + 0.5))

        if prof.showSpellNames and evt.isAuto ~= true and type(evt.spellName) == "string" and evt.spellName ~= "" then
            text = text .. " " .. evt.spellName
        end

        if conf.showTargets and type(evt.targetName) == "string" and evt.targetName ~= "" then
            text = text .. " -> " .. evt.targetName
        end

        local color = {r = 1.00, g = 0.25, b = 0.25}
        local meta = {
            probe = true,
            replay = isReplay == true,
            kind = kind,
            isAuto = evt.isAuto == true,
            isCrit = evt.isCrit == true,
            school = evt.schoolMask,
        }

        if TSBT.DisplayText then
            TSBT.DisplayText(area, text, color, meta)
        elseif TSBT.Core and TSBT.Core.Display and TSBT.Core.Display.Emit then
            TSBT.Core.Display:Emit(area, text, color, meta)
        end

    else
        local conf = prof.healing
        if not conf or not conf.enabled then return end

        local over = tonumber(evt.overheal) or 0
        if over < 0 then over = 0 end

        -- What we display is what we threshold against.
        local displayAmt = amt
        if not conf.showOverheal then
            displayAmt = amt - over
        end
        if displayAmt <= 0 then return end

        local minT = tonumber(conf.minThreshold) or 0
        if displayAmt < minT then return end

        local area = conf.scrollArea or "Outgoing"
        local text = tostring(math.floor(displayAmt + 0.5))

        if prof.showSpellNames and type(evt.spellName) == "string" and evt.spellName ~= "" then
            text = text .. " " .. evt.spellName
        end

        if conf.showOverheal and over > 0 then
            text = text .. " (OH " .. tostring(math.floor(over + 0.5)) .. ")"
        end

        local color = {r = 0.20, g = 1.00, b = 0.20}
        local meta = {
            probe = true,
            replay = isReplay == true,
            kind = kind,
            isCrit = evt.isCrit == true,
            school = evt.schoolMask,
        }

        if TSBT.DisplayText then
            TSBT.DisplayText(area, text, color, meta)
        elseif TSBT.Core and TSBT.Core.Display and TSBT.Core.Display.Emit then
            TSBT.Core.Display:Emit(area, text, color, meta)
        end
    end
end
