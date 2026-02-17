local ADDON_NAME, TSBT = ...

TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.EventCollector = TSBT.Parser.EventCollector or {}
local Collector = TSBT.Parser.EventCollector

Collector._enabled = Collector._enabled or false
Collector._frame = Collector._frame or nil
Collector._sink = Collector._sink or nil
Collector._lastHealth = Collector._lastHealth or {}

local function now()
	return (GetTime and GetTime()) or 0
end

local function isSecretValue(v)
	return type(v) ~= "number"
end

local function safeUnitName(unit)
	if not unit then return nil end
	local ok, value = pcall(UnitName, unit)
	if not ok then return nil end
	if type(value) == "string" and value ~= "" then return value end
	return nil
end

local function emit(eventType, payload)
	if Collector._sink then
		Collector._sink(eventType, payload)
	end
end

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

function Collector:handleSpellcastSucceeded(unit, _, spellId)
	if unit ~= "player" then return end
	if not spellId then return end

	local spellName = (GetSpellInfo and GetSpellInfo(spellId)) or nil
	emit("SPELLCAST_SUCCEEDED", {
		timestamp = now(),
		unit = unit,
		spellId = spellId,
		spellName = spellName,
		targetName = safeUnitName("target"),
	})
end

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

	-- Normal case: we have numeric health values
	-- Calculate damage as health decrease
	local oldHealth = self._lastHealth[unit] or health
	local damage = oldHealth - health

	-- Store current health for next comparison
	self._lastHealth[unit] = health

	-- Only emit if health decreased (damage occurred)
	if damage > 0 then
		emit("HEALTH_DAMAGE", {
			timestamp = now(),
			unit = unit,
			amount = damage,
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

function Collector:Enable()
	if self._enabled then return end

	if not self._frame then
		self._frame = CreateFrame("Frame")
		self._frame:SetScript("OnEvent", function(_, event, ...)
			if event == "UNIT_SPELLCAST_SUCCEEDED" then
				Collector:handleSpellcastSucceeded(...)
			elseif event == "UNIT_HEALTH" then
				Collector:handleUnitHealth(...)
			end
		end)
	end

	self._frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self._frame:RegisterEvent("UNIT_HEALTH")
	self._enabled = true
end

function Collector:Disable()
	if not self._enabled then return end
	if self._frame then
		self._frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		self._frame:UnregisterEvent("UNIT_HEALTH")
	end
	self._enabled = false
	self._lastHealth = {}
end
