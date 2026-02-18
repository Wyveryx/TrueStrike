--==================================--
-- Module Setup
--==================================--

-- Initialize addon namespace references.
local ADDON_NAME, TSBT = ...

-- Ensure parser and collector tables exist before attaching methods.
TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.EventCollector = TSBT.Parser.EventCollector or {}
local Collector = TSBT.Parser.EventCollector

-- Persist collector module state across reloads.
Collector._enabled = Collector._enabled or false
Collector._frame = Collector._frame or nil
Collector._sink = Collector._sink or nil
Collector._lastHealth = Collector._lastHealth or {}
Collector._lastPlayerSpellName = Collector._lastPlayerSpellName or nil

-- Track player falling state to identify fall damage from UNIT_COMBAT.
local isFalling = false
local fallingTimer = nil

--==================================--
-- Utility Functions
--==================================--

-- Return a consistent timestamp source for emitted events.
local function now()
	return (GetTime and GetTime()) or 0
end

-- Detect restricted "Secret Value" health data types.
local function isSecretValue(v)
	return type(v) ~= "number"
end

-- Safely resolve unit display names without hard errors.
local function safeUnitName(unit)
	if not unit then return nil end
	local ok, value = pcall(UnitName, unit)
	if not ok then return nil end
	if type(value) == "string" and value ~= "" then return value end
	return nil
end

-- Forward parsed events to the configured sink callback.
local function emit(eventType, payload)
	if Collector._sink then
		Collector._sink(eventType, payload)
	end
end

-- Reset fall tracking and cancel any delayed landing timer.
local function resetFallingState()
	isFalling = false
	if fallingTimer then
		fallingTimer:Cancel()
		fallingTimer = nil
	end
end

-- Set the callback that receives normalized parser events.
function Collector:setSink(fn)
	self._sink = fn
end

--[[
WoW 12.0 Outgoing Damage Detection Strategy:

Since COMBAT_LOG_EVENT_UNFILTERED is protected, we use correlation:
1. UNIT_SPELLCAST_SUCCEEDED - captures when player finishes a cast
2. UNIT_HEALTH - detects health changes on target
3. Correlation engine matches cast → health drop → emits damage event

Limitations:
- In instances/M+/raids, UnitHealth() returns "Secret Values" (userdata)
- Cannot calculate damage deltas in restricted content
- Falls back to confidence=UNKNOWN/LOW in those cases
]]

--==================================--
-- Spell Tracking
--==================================--

-- Capture successful player casts for downstream correlation.
function Collector:handleSpellcastSucceeded(unit, _, spellId)
	if unit ~= "player" then return end
	if not spellId then return end

	local spellName = nil
	if C_Spell and C_Spell.GetSpellName then
		spellName = C_Spell.GetSpellName(spellId)
	end
	if not spellName and GetSpellInfo then
		spellName = GetSpellInfo(spellId)
	end

	self._lastPlayerSpellName = spellName

	emit("SPELLCAST_SUCCEEDED", {
		timestamp = now(),
		unit = unit,
		spellId = spellId,
		spellName = spellName,
		targetName = safeUnitName("target"),
	})
end

--==================================--
-- Self Heal Detection (COMBAT_TEXT_UPDATE)
--==================================--

-- Supported combat text event tokens that represent healing.
local HEAL_EVENT_TYPES = {
	HEAL = true,
	HEAL_CRIT = true,
	PERIODIC_HEAL = true,
	PERIODIC_HEAL_CRIT = true,
}

-- Parse self-heal combat text into structured events.
function Collector:handleCombatTextUpdate(arg1)
	if not (C_CombatText and C_CombatText.GetCurrentEventInfo) then return end
	if not HEAL_EVENT_TYPES[arg1] then return end

	local _, arg3 = C_CombatText.GetCurrentEventInfo()
	if arg3 == nil then return end

	local spellName = self._lastPlayerSpellName
	if type(spellName) ~= "string" or spellName == "" then
		spellName = "Heal"
	end

	emit("SELF_HEAL_TEXT", {
		timestamp = now(),
		spellName = spellName,
		amountText = tostring(arg3),
		isCrit = arg1 == "HEAL_CRIT" or arg1 == "PERIODIC_HEAL_CRIT",
	})

	-- Incoming healing for the player uses combat text events as a non-UNIT_COMBAT path.
	emit("INCOMING_HEAL_TEXT", {
		timestamp = now(),
		targetName = safeUnitName("player"),
		amountText = tostring(arg3),
		isCrit = arg1 == "HEAL_CRIT" or arg1 == "PERIODIC_HEAL_CRIT",
		isPeriodic = arg1 == "PERIODIC_HEAL" or arg1 == "PERIODIC_HEAL_CRIT",
	})
end

--==================================--
-- Fall Damage Detection (UNIT_COMBAT + IsFalling)
--==================================--

-- Detect incoming player damage and classify fall damage while airborne.
function Collector:handleUnitCombat(unit, action, _, amount, school)
	if unit ~= "player" then return end
	if action == "WOUND" and school == 1 and isFalling then
		emit("FALL_DAMAGE", {
			timestamp = now(),
			amount = amount,
			school = school,
		})
	elseif action == "WOUND" then
		emit("INCOMING_DAMAGE", {
			timestamp = now(),
			amount = amount,
			school = school,
		})
	end
end

--==================================--
-- Unit Health Tracking (UNIT_HEALTH correlation engine)
--==================================--

-- Track health deltas for units used by the damage correlation engine.
function Collector:handleUnitHealth(unit)
	if unit ~= "target" and unit ~= "mouseover" and unit ~= "player" then return end

	local health = UnitHealth and UnitHealth(unit) or nil
	local healthMax = UnitHealthMax and UnitHealthMax(unit) or nil

	-- WoW 12.0 Secret Value detection
	if isSecretValue(health) or isSecretValue(healthMax) then
		-- In restricted content (instances/M+/raids), health values are userdata
		-- We cannot calculate damage deltas, but can still signal a health change
		emit("HEALTH_CHANGE_SECRET", {
			timestamp = now(),
			unit = unit,
			targetName = safeUnitName(unit),
			isSecret = true,
		})
		return
	end

	-- Check if we've seen this unit before
	local oldHealth = self._lastHealth[unit]
	if not oldHealth then
		-- First time seeing this unit - just store health, don't emit damage yet
		self._lastHealth[unit] = health
		return
	end

	-- Calculate health change (positive = damage, negative = healing)
	local delta = oldHealth - health
	self._lastHealth[unit] = health

	-- Emit damage if health decreased
	if delta > 0 then
		emit("HEALTH_DAMAGE", {
			timestamp = now(),
			unit = unit,
			amount = delta,
			targetName = safeUnitName(unit),
			health = health,
			healthMax = healthMax,
		})
	-- Emit healing if health increased
	elseif delta < 0 then
		emit("HEALTH_HEAL", {
			timestamp = now(),
			unit = unit,
			amount = -delta,
			targetName = safeUnitName(unit),
			health = health,
			healthMax = healthMax,
		})
	end

	-- Also emit general health change for correlation engine
	emit("UNIT_HEALTH", {
		timestamp = now(),
		unit = unit,
		health = health,
		healthMax = healthMax,
		targetName = safeUnitName(unit),
	})
end

--==================================--
-- Enable / Disable Lifecycle
--==================================--

-- Register events and initialize runtime frames used by the collector.
function Collector:Enable()
	if self._enabled then return end
	resetFallingState()

	-- Create the event frame once and route events to parser handlers.
	if not self._frame then
		self._frame = CreateFrame("Frame")
		self._frame:SetScript("OnEvent", function(_, event, ...)
			if event == "UNIT_SPELLCAST_SUCCEEDED" then
				Collector:handleSpellcastSucceeded(...)
			elseif event == "UNIT_HEALTH" then
				Collector:handleUnitHealth(...)
			elseif event == "COMBAT_TEXT_UPDATE" then
				Collector:handleCombatTextUpdate(...)
			elseif event == "UNIT_COMBAT" then
				Collector:handleUnitCombat(...)
			end
		end)
	end

	-- Create a lightweight OnUpdate watcher once for fall state transitions.
	if not Collector._fallingFrame then
		Collector._fallingFrame = CreateFrame("Frame")
		Collector._fallingFrame:SetScript("OnUpdate", function()
			if IsFalling("player") then
				isFalling = true
				if fallingTimer then
					fallingTimer:Cancel()
					fallingTimer = nil
				end
			elseif isFalling then
				if not fallingTimer then
					fallingTimer = C_Timer.NewTimer(0.25, function()
						isFalling = false
						fallingTimer = nil
					end)
				end
			end
		end)
	end

	-- Subscribe to WoW events used by this collector.
	self._frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self._frame:RegisterEvent("UNIT_HEALTH")
	self._frame:RegisterEvent("COMBAT_TEXT_UPDATE")
	self._frame:RegisterEvent("UNIT_COMBAT")
	self._enabled = true
end

-- Unregister events and clear transient runtime state.
function Collector:Disable()
	if not self._enabled then return end
	if self._frame then
		self._frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		self._frame:UnregisterEvent("UNIT_HEALTH")
		self._frame:UnregisterEvent("COMBAT_TEXT_UPDATE")
		self._frame:UnregisterEvent("UNIT_COMBAT")
	end
	resetFallingState()
	self._enabled = false
	self._lastHealth = {}
	self._lastPlayerSpellName = nil
end
