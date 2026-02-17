------------------------------------------------------------------------
-- TrueStrike Battle Text - Combat Log Coordinator
-- WoW 12.0 COMPATIBILITY: COMBAT_LOG_EVENT_UNFILTERED is PROTECTED
------------------------------------------------------------------------
-- CRITICAL: As of WoW 12.0 (Midnight), COMBAT_LOG_EVENT_UNFILTERED is
-- a protected event that CANNOT be registered by addons, even in Enable().
-- 
-- SOLUTION: Each parser (Incoming_Detect, Outgoing_Detect) now registers
-- its own alternative events instead of using a centralized listener.
--
-- This file exists only for coordination and backward compatibility.
------------------------------------------------------------------------
local ADDON_NAME, TSBT = ...

TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.CombatLog = TSBT.Parser.CombatLog or {}
local CombatLog = TSBT.Parser.CombatLog

-- Initialize as disabled
CombatLog._enabled = false

------------------------------------------------------------------------
-- Enable/Disable - Coordination Only
------------------------------------------------------------------------
-- These methods exist for compatibility with Init.lua's EnableParsers()
-- The actual event registration happens in individual parser modules.
------------------------------------------------------------------------
function CombatLog:Enable()
	print(">>> COMBAT LOG COORDINATOR ENABLED (WoW 12.0 MODE) <<<")
	print("    Individual parsers will register their own events")
	self._enabled = true
	
	-- Parsers will handle their own event registration:
	-- - Incoming_Detect: Uses UNIT_COMBAT (not protected)
	-- - Outgoing_Detect: Will need alternative implementation
end

function CombatLog:Disable()
	print(">>> COMBAT LOG COORDINATOR DISABLED <<<")
	self._enabled = false
end