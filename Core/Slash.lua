--[[
TrueStrike - Slash Commands
Purpose:
  Register and process simple chat commands for shell visibility.
Main responsibilities:
  - Register /truestrike and /ts aliases.
  - Support show/hide plus frame lock management subcommands.
  - Toggle shell visibility by default.
Module interactions:
  - Delegates shell actions to UI/Shell methods.
]]

local _, ns = ...
local TrueStrike = ns.TrueStrike

function TrueStrike:InitializeSlashCommands()
  self:RegisterChatCommand("truestrike", "HandleSlash")
  self:RegisterChatCommand("ts", "HandleSlash")
end

function TrueStrike:HandleSlash(msg)
  local cmd = (msg or ""):lower():match("^%s*(.-)%s*$")
  if cmd == "show" then
    self:ShowShell()
    return
  elseif cmd == "hide" then
    self:HideShell()
    return
  elseif cmd == "unlock" then
    self:GetProfile().framesUnlocked = true
    self:ApplyLockState()
    self:RefreshAreaFrames()
    self:Print("Scroll areas unlocked.")
    return
  elseif cmd == "lock" then
    self:GetProfile().framesUnlocked = false
    self:ApplyLockState()
    self:RefreshAreaFrames()
    self:Print("Scroll areas locked.")
    return
  elseif cmd == "togglelock" then
    self:GetProfile().framesUnlocked = not self:GetProfile().framesUnlocked
    self:ApplyLockState()
    self:RefreshAreaFrames()
    self:Print(self:GetProfile().framesUnlocked and "Scroll areas unlocked." or "Scroll areas locked.")
    return
  end

  self:ToggleShell()
end
