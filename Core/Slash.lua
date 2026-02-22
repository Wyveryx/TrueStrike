--[[
TrueStrike - Slash Commands
Purpose:
  Register and process simple chat commands for shell visibility.
Main responsibilities:
  - Register /truestrike and /ts aliases.
  - Support optional `show` and `hide` subcommands.
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
  end

  self:ToggleShell()
end
