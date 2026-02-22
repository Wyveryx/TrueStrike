--[[
TrueStrike - Core Initialization
Purpose:
  Create the addon object and orchestrate milestone startup.
Main responsibilities:
  - Initialize AceDB state during OnInitialize.
  - Bring up the UI shell, slash commands, scroll runtime, and test harness.
  - Provide safe LibSharedMedia access helpers for optional dependency handling.
Module interactions:
  - Consumed by all Core/UI files through `ns.TrueStrike`.
]]

local addonName, ns = ...

local TrueStrike = LibStub("AceAddon-3.0"):NewAddon("TrueStrike", "AceConsole-3.0")
ns.TrueStrike = TrueStrike

TrueStrike.TabKeys = {
  "General",
  "ScrollAreas",
  "Incoming",
  "Outgoing",
  "Features",
  "Diagnostics",
}

-- LibSharedMedia is optional at runtime. Fail silently and let UI gate controls.
function TrueStrike:SafeGetLSM()
  local ok, lsm = pcall(LibStub, "LibSharedMedia-3.0", true)
  if ok then
    return lsm
  end
  return nil
end

function TrueStrike:PrintMissingLSMOnce()
  if self.warnedMissingLSM then
    return
  end

  self.warnedMissingLSM = true
  self:Print("LibSharedMedia-3.0 not found. Font and sound pickers are disabled until it is installed.")
end

function TrueStrike:OnInitialize()
  self:InitializeDatabase()
end

function TrueStrike:OnEnable()
  self:InitializeSlashCommands()
  self:InitializeScrollEngine()
  self:InitializeTestHarness()
  self:InitializeShell()
  self:Print("Loaded. Type /truestrike to open the UI.")
end
