-- TrueStrike Core Init
-- Creates the addon object, shared helpers, and lifecycle bootstrap.

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
  self:InitializeShell()
  self:InitializeSlashCommands()
  self:InitializeScrollEngine()
  self:InitializeTestHarness()
  self:Print("Loaded. Type /truestrike to open the UI.")
end
