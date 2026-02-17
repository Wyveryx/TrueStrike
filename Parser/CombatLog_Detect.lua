------------------------------------------------------------------------
-- TrueStrike Battle Text - Parser Coordinator (WoW 12.0)
------------------------------------------------------------------------
local ADDON_NAME, TSBT = ...

TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.CombatLog = TSBT.Parser.CombatLog or {}
local CombatLog = TSBT.Parser.CombatLog

CombatLog._enabled = CombatLog._enabled or false

local function wireCollectorToEngine()
	local collector = TSBT.Parser and TSBT.Parser.EventCollector
	local engine = TSBT.Parser and TSBT.Parser.PulseEngine
	if collector and engine and collector.setSink then
		collector:setSink(function(eventType, payload)
			engine:collect(eventType, payload)
		end)
	end
end

function CombatLog:Enable()
	if self._enabled then return end
	self._enabled = true

	wireCollectorToEngine()

	local engine = TSBT.Parser and TSBT.Parser.PulseEngine
	if engine and engine.Enable then
		engine:Enable()
	end

	local collector = TSBT.Parser and TSBT.Parser.EventCollector
	if collector and collector.Enable then
		collector:Enable()
	end
end

function CombatLog:Disable()
	if not self._enabled then return end
	self._enabled = false

	local collector = TSBT.Parser and TSBT.Parser.EventCollector
	if collector and collector.Disable then
		collector:Disable()
	end

	local engine = TSBT.Parser and TSBT.Parser.PulseEngine
	if engine and engine.Disable then
		engine:Disable()
	end
end
