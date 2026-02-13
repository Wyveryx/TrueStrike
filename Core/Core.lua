------------------------------------------------------------------------
-- TrueStrike - Core Orchestrator (Skeleton)
------------------------------------------------------------------------
local ADDON_NAME, TSBT = ...

TSBT.Core = TSBT.Core or {}
local Core  = TSBT.Core
local Addon = TSBT.Addon

Core._initialized = Core._initialized or false
Core._enabled     = Core._enabled or false

function Core:IsMasterEnabled()
    return TSBT.db
       and TSBT.db.profile
       and TSBT.db.profile.general
       and TSBT.db.profile.general.enabled == true
end

function Core:IsCombatOnlyEnabled()
    return TSBT.db
       and TSBT.db.profile
       and TSBT.db.profile.general
       and TSBT.db.profile.general.combatOnly == true
end

function Core:ShouldEmitNow()
    if not self:IsMasterEnabled() then return false end
    if self:IsCombatOnlyEnabled() and not UnitAffectingCombat("player") then
        return false
    end
    return true
end

-- Attempt to suppress Blizzard floating combat text via CVars.
-- NOTE: Blizzard may lock/ignore these on some client builds.
function Core:ApplyBlizzardFCTCVars()
    if not TSBT.db or not TSBT.db.profile or not TSBT.db.profile.general then return end

    local g = TSBT.db.profile.general

    -- Only apply suppression when TrueStrike is enabled (your requested UX).
    if not g.enabled then return end

    local function trySet(name, value)
        if type(SetCVar) ~= "function" or type(GetCVar) ~= "function" then
            if Addon and Addon.Print then
                Addon:Print(("CVar API unavailable; cannot set %s."):format(name))
            end
            return
        end

        local ok = pcall(SetCVar, name, value)
        local after = GetCVar(name)

        -- If Blizzard ignores it, warn once per click (good enough for now).
        if not ok or tostring(after) ~= tostring(value) then
            if Addon and Addon.Print then
                Addon:Print(("Attempted to set %s=%s, but client reports %s. Blizzard may be ignoring/locking this CVar."):format(
                    name, tostring(value), tostring(after)
                ))
            end
        end
    end

    -- These are the historical CVars. If Blizzard changes them again, we’ll adapt.
    if g.suppressBlizzardDamage then
        trySet("floatingCombatTextCombatDamage", "0")
    else
        trySet("floatingCombatTextCombatDamage", "1")
    end

    if g.suppressBlizzardHealing then
        trySet("floatingCombatTextCombatHealing", "0")
    else
        trySet("floatingCombatTextCombatHealing", "1")
    end
end

function Core:Init()
    if self._initialized then return end
    self._initialized = true

    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(1, "Core:Init()")
    end

    -- Incoming probe/replay harness init (UI/UX validation only).
    if self.IncomingProbe and self.IncomingProbe.Init then
        self.IncomingProbe:Init()
    end
end

function Core:Enable()
    if self._enabled then return end
    self:Init()
    self._enabled = true

    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(1, "Core:Enable()")
    end

    -- Apply Blizzard suppression knobs (best-effort).
    self:ApplyBlizzardFCTCVars()

    if self.Display and self.Display.Enable then self.Display:Enable() end
    if self.Cooldowns and self.Cooldowns.Enable then self.Cooldowns:Enable() end
    if self.Combat and self.Combat.Enable then self.Combat:Enable() end
end

function Core:Disable()
    if not self._enabled then return end
    self._enabled = false

    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(1, "Core:Disable()")
    end

    if self.Combat and self.Combat.Disable then self.Combat:Disable() end
    if self.Cooldowns and self.Cooldowns.Disable then self.Cooldowns:Disable() end
    if self.Display and self.Display.Disable then self.Display:Disable() end
end
