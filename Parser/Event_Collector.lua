local ADDON_NAME, TSBT = ...

TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.EventCollector = TSBT.Parser.EventCollector or {}
local Collector = TSBT.Parser.EventCollector

Collector._enabled = Collector._enabled or false
Collector._frame = Collector._frame or nil
Collector._sink = Collector._sink or nil

local function now()
	return (GetTime and GetTime()) or 0
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

function Collector:handleUnitCombat(unit, action, amount, school, _, _, _, critical)
	if unit ~= "target" and unit ~= "mouseover" and unit ~= "nameplate1" then
		return
	end

	if action ~= "WOUND" and action ~= "DAMAGE" and action ~= "HEAL" and action ~= "CRITHEAL" and action ~= "CRIT" then
		return
	end

	emit("UNIT_COMBAT", {
		timestamp = now(),
		unit = unit,
		action = action,
		amount = amount,
		school = school,
		isCrit = (critical == true) or action == "CRIT" or action == "CRITHEAL",
		targetName = safeUnitName(unit),
	})
end

function Collector:handleUnitHealth(unit)
	if unit ~= "target" and unit ~= "mouseover" and unit ~= "player" then return end

	-- WoW 12.0 Secret Value note:
	-- UnitHealth/UnitHealthMax may return userdata in restricted contexts.
	-- We pass values through untouched and never perform arithmetic here.
	local health = UnitHealth and UnitHealth(unit) or nil
	local healthMax = UnitHealthMax and UnitHealthMax(unit) or nil
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
			elseif event == "UNIT_COMBAT" then
				Collector:handleUnitCombat(...)
			elseif event == "UNIT_HEALTH" then
				Collector:handleUnitHealth(...)
			end
		end)
	end

	self._frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self._frame:RegisterEvent("UNIT_COMBAT")
	self._frame:RegisterEvent("UNIT_HEALTH")
	self._enabled = true
end

function Collector:Disable()
	if not self._enabled then return end
	if self._frame then
		self._frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		self._frame:UnregisterEvent("UNIT_COMBAT")
		self._frame:UnregisterEvent("UNIT_HEALTH")
	end
	self._enabled = false
end
