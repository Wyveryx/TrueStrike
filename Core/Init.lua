------------------------------------------------------------------------
-- TrueStrike Battle Text - Initialization
-- Creates the addon object, registers chat commands, initializes DB.
------------------------------------------------------------------------
local ADDON_NAME, TSBT = ...

------------------------------------------------------------------------
-- Create the Ace3 addon object
------------------------------------------------------------------------
TSBT.Addon = LibStub("AceAddon-3.0"):NewAddon("TrueStrike", "AceConsole-3.0")

local Addon = TSBT.Addon

------------------------------------------------------------------------
-- Combat lockdown defer state
------------------------------------------------------------------------
local pendingParserEnable = false
local pendingParserDisable = false

------------------------------------------------------------------------
-- Apply Blizzard FCT CVar Settings
-- Controls whether Blizzard's floating combat text displays.
-- NOTE: We need enableFloatingCombatText=1 for COMBAT_TEXT_UPDATE events
-- to fire, but users may want the visual display disabled.
------------------------------------------------------------------------
local function ApplyBlizzardFCTSettings()
    local disableFCT = TSBT.db and TSBT.db.profile
        and TSBT.db.profile.general
        and TSBT.db.profile.general.disableBlizzardFCT

    if disableFCT then
        -- Disable Blizzard's visual display
        -- CTU events still fire even with this set to 0
        SetCVar("enableFloatingCombatText", "0")
    else
        -- Ensure CTU events fire (user wants Blizzard FCT visible)
        SetCVar("enableFloatingCombatText", "1")
    end
end

------------------------------------------------------------------------
-- Enable/Disable parsers (with combat lockdown protection)
------------------------------------------------------------------------
local function EnableParsers()
    if InCombatLockdown() then
        pendingParserEnable = true
        pendingParserDisable = false
        return false -- Deferred
    end

    -- Apply Blizzard FCT settings first
    ApplyBlizzardFCTSettings()

    if TSBT.Parser then
        -- Enable data processors (sets _enabled flag, no event registration)
        if TSBT.Parser.Incoming and TSBT.Parser.Incoming.Enable then
            TSBT.Parser.Incoming:Enable()
        end
        if TSBT.Parser.Outgoing and TSBT.Parser.Outgoing.Enable then
            TSBT.Parser.Outgoing:Enable()
        end
        if TSBT.Parser.Cooldowns and TSBT.Parser.Cooldowns.Enable then
            TSBT.Parser.Cooldowns:Enable()
        end

        -- Enable HealAttribution (COMBAT_TEXT_UPDATE based heal display)
        if TSBT.Parser.HealAttribution and TSBT.Parser.HealAttribution.Enable then
            TSBT.Parser.HealAttribution:Enable()
        end

        -- Enable master listener (registers COMBAT_LOG_EVENT_UNFILTERED)
        -- This MUST be last so data processors are ready before events fire
        if TSBT.Parser.CombatLog and TSBT.Parser.CombatLog.Enable then
            TSBT.Parser.CombatLog:Enable()
        end
    end

    pendingParserEnable = false
    return true -- Success
end
 
local function DisableParsers()
    if InCombatLockdown() then
        pendingParserDisable = true
        pendingParserEnable = false
        return false -- Deferred
    end

    if TSBT.Parser then
        -- Disable master listener FIRST (stops event flow)
        if TSBT.Parser.CombatLog and TSBT.Parser.CombatLog.Disable then
            TSBT.Parser.CombatLog:Disable()
        end

        -- Disable HealAttribution
        if TSBT.Parser.HealAttribution and TSBT.Parser.HealAttribution.Disable then
            TSBT.Parser.HealAttribution:Disable()
        end

        -- Then disable data processors (clears _enabled flag)
        if TSBT.Parser.Incoming and TSBT.Parser.Incoming.Disable then
            TSBT.Parser.Incoming:Disable()
        end
        if TSBT.Parser.Outgoing and TSBT.Parser.Outgoing.Disable then
            TSBT.Parser.Outgoing:Disable()
        end
        if TSBT.Parser.Cooldowns and TSBT.Parser.Cooldowns.Disable then
            TSBT.Parser.Cooldowns:Disable()
        end
    end

    pendingParserDisable = false
    return true -- Success
end

------------------------------------------------------------------------
-- Combat lockdown watcher frame
------------------------------------------------------------------------
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        -- Combat ended, retry any pending operations
        if pendingParserEnable then
            EnableParsers()
        elseif pendingParserDisable then
            DisableParsers()
        end
    end
end)

------------------------------------------------------------------------
-- OnInitialize: Fires once when addon loads (before PLAYER_LOGIN)
------------------------------------------------------------------------
function Addon:OnInitialize()
    -- Initialize AceDB with our defaults and enable profiles
    self.db = LibStub("AceDB-3.0"):New("TrueStrikeDB", TSBT.DEFAULTS, true)

    -- Store reference in shared namespace for cross-file access
    TSBT.db = self.db

    if TSBT.Core and TSBT.Core.Minimap and TSBT.Core.Minimap.Init then
        TSBT.Core.Minimap:Init()
    end

    -- Register LibSharedMedia-3.0 defaults (ensure base WoW font is listed)
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        -- LSM auto-registers system fonts; no custom media to add yet.
        -- Addon-bundled fonts/sounds can be registered here in future:
        -- LSM:Register("font", "My Custom Font", [[Interface\AddOns\TrueStrike\Media\MyFont.ttf]])
    end

    -- Register slash commands
    self:RegisterChatCommand("tsbt", "HandleSlashCommand")
    self:RegisterChatCommand("truestrike", "HandleSlashCommand")

    -- Build and register Ace3 options table (assembled in Config.lua)
    if TSBT.BuildOptionsTable then
        local options = TSBT.BuildOptionsTable()

        -- Inject the AceDBOptions-3.0 profiles tab into the options tree
        local AceDBOptions = LibStub("AceDBOptions-3.0", true)
        if AceDBOptions then
            local profilesTable = AceDBOptions:GetOptionsTable(self.db)
            profilesTable.order = 100 -- Place after all other tabs
            options.args.profiles = profilesTable
        end

        LibStub("AceConfig-3.0"):RegisterOptionsTable("TrueStrike", options)
        self.configDialog = LibStub("AceConfigDialog-3.0")

        -- Set the default size for the config dialog
        self.configDialog:SetDefaultSize("TrueStrike", TSBT.CONFIG_WIDTH,
                                         TSBT.CONFIG_HEIGHT)

        -- Apply Strike Silver color scheme to config frame
        if TSBT.ApplyStrikeSilverStyling then
            TSBT.ApplyStrikeSilverStyling()
        end
    end

    self:Print(TSBT.ADDON_TITLE .. " v" .. TSBT.VERSION ..
                   " loaded. Type /tsbt to configure.")
end

------------------------------------------------------------------------
-- OnEnable: Fires when addon is enabled (after PLAYER_LOGIN)
------------------------------------------------------------------------
function Addon:OnEnable()
    local masterEnabled = self.db and self.db.profile and
                              self.db.profile.general and
                              self.db.profile.general.enabled == true

    -- Always init core once (safe, no-op skeleton)
    if TSBT.Core and TSBT.Core.Init then TSBT.Core:Init() end

    -- CRITICAL: Use PLAYER_ENTERING_WORLD to defer parser enable
    -- This event ALWAYS fires outside combat and after all protected loading is complete
    local enableFrame = CreateFrame("Frame")
    enableFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    enableFrame:SetScript("OnEvent", function(self, event)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        if masterEnabled then
            if TSBT.Core and TSBT.Core.Enable then TSBT.Core:Enable() end

            -- Enable parsers with combat lockdown protection
            local success = EnableParsers()
            if not success then
                Addon:Print("In combat - TrueStrike will fully enable after combat ends.")
            end
        else
            -- Respect saved disabled state
            DisableParsers()
            if TSBT.Core and TSBT.Core.Disable then TSBT.Core:Disable() end
        end
    end)
end

------------------------------------------------------------------------
-- OnDisable: Fires when addon is disabled
------------------------------------------------------------------------
function Addon:OnDisable()
    DisableParsers()
    if TSBT.Core and TSBT.Core.Disable then TSBT.Core:Disable() end
end

------------------------------------------------------------------------
-- Slash Command Router
------------------------------------------------------------------------
function Addon:HandleSlashCommand(input)
    local cmd, rest = self:GetArgs(input, 2)

    if not cmd or cmd == "" then
        self:OpenConfig()
        return
    end

    cmd = cmd:lower()

    if cmd == "minimap" then
        if TSBT.Core and TSBT.Core.Minimap and TSBT.Core.Minimap.UpdateVisibility then
            local g = TSBT.db.profile.general
            g.minimap.hide = not g.minimap.hide
            TSBT.Core.Minimap:UpdateVisibility()
            self:Print(("Minimap button %s."):format(g.minimap.hide and "hidden" or "shown"))
        end
        return
    end

    if cmd == "debug" then
        self:HandleDebugCommand(rest)
        return
    elseif cmd == "reset" then
        self:HandleResetCommand()
        return
    elseif cmd == "version" then
        self:Print(TSBT.ADDON_TITLE .. " v" .. TSBT.VERSION)
        return
    end

    self:Print("Unknown command: " .. cmd)
    self:Print("Usage: /tsbt [minimap | debug 0-3 | reset | version]")
end

------------------------------------------------------------------------
-- Open Configuration Window
------------------------------------------------------------------------
function Addon:OpenConfig()
    if self.configDialog then
        self.configDialog:Open("TrueStrike")

        local frame = self.configDialog.OpenFrames["TrueStrike"]
        if frame and frame.frame then
            local f = frame.frame

            -- Prevent AceConfigDialog from auto-closing when spellbook opens
            if not f.tsbtHooked then
                f.tsbtHooked = true

                -- Store original Hide function
                local origHide = f.Hide

                -- Hook Hide to block auto-closes
                f.Hide = function(self, ...)
                    -- Only allow closes when explicitly permitted
                    if not self.tsbtAllowClose then return end
                    return origHide(self, ...)
                end
            end

            -- Find the close button by searching the frame's children
            local function findCloseButton(parent, depth)
                depth = depth or 0
                if depth > 0 then return end -- ONLY check depth 0!

                for i = 1, parent:GetNumChildren() do
                    local child = select(i, parent:GetChildren())
                    if child and child.GetObjectType and child:GetObjectType() ==
                        "Button" then
                        local text = child:GetText()
                        if text and (text:lower():match("close") or text == "X") then
                            child:HookScript("PreClick", function()
                                f.tsbtAllowClose = true
                                C_Timer.After(0.05, function()
                                    f.tsbtAllowClose = false
                                end)
                            end)
                        end
                    end
                end
            end

            findCloseButton(f)

            -- ESC key handler
            f:EnableKeyboard(true)
            f:SetPropagateKeyboardInput(true)
            f:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then
                    self.tsbtAllowClose = true
                    self:Hide()
                    C_Timer.After(0.05, function()
                        if self then
                            self.tsbtAllowClose = false
                        end
                    end)
                end
            end)
        end
    end
end

------------------------------------------------------------------------
-- Debug Level Command
------------------------------------------------------------------------
function Addon:HandleDebugCommand(levelStr)
    local level = tonumber(levelStr)
    if not level or level < TSBT.DEBUG_LEVEL_NONE or level >
        TSBT.DEBUG_LEVEL_ALL_EVENTS then
        self:Print("Usage: /tsbt debug [0-3]")
        self:Print("  0 = Off, 1 = Suppressed, 2 = Confidence, 3 = All Events")
        return
    end

    self.db.profile.diagnostics.debugLevel = level
    local names = {
        [0] = "Off",
        [1] = "Suppressed",
        [2] = "Confidence",
        [3] = "All Events"
    }
    self:Print("Debug level set to " .. level .. " (" .. names[level] .. ")")
end

------------------------------------------------------------------------
-- Reset to Defaults (with confirmation gate)
------------------------------------------------------------------------
function Addon:HandleResetCommand()
    self.db:ResetProfile()
    self:Print("Profile reset to defaults.")
end

