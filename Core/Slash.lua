-- TrueStrike Slash Commands
-- Implements /truestrike and /ts toggling behavior.

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
