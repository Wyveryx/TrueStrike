------------------------------------------------------------------------
-- TrueStrike Battle Text - Configuration Tab Definitions
-- Each function builds one AceConfig options group (tab).
-- Order values control tab ordering in the UI.
--
-- NOTE: All font/sound dropdowns use standard "select" type with
-- TSBT.BuildFontDropdown() / TSBT.BuildSoundDropdown() helpers.
-- No LSM30_Font or LSM30_Sound widget dependencies.
------------------------------------------------------------------------

local ADDON_NAME, TSBT = ...
local Addon = TSBT.Addon

------------------------------------------------------------------------
-- Compatibility: C_Spell.GetSpellInfo for WoW 12.0+
-- Returns spell name or fallback string. Handles nil gracefully.
------------------------------------------------------------------------
local function SafeGetSpellName(spellID)
    if not spellID then return nil end
    -- WoW 12.0+: use C_Spell.GetSpellInfo which returns a table
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name then
            return info.name
        end
    end
    -- Fallback for older API (pre-12.0)
    if GetSpellInfo then
        local name = GetSpellInfo(spellID)
        if name then return name end
    end
    return nil
end

------------------------------------------------------------------------
-- Compatibility: C_Item.GetItemInfo
-- Returns item name or fallback string. Handles nil gracefully.
------------------------------------------------------------------------
local function SafeGetItemName(itemID)
    if not itemID then return nil end
    itemID = tonumber(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemInfo then
        local name = C_Item.GetItemInfo(itemID)
        if name then return name end
    end
    return nil
end


------------------------------------------------------------------------
-- TAB 1: GENERAL
-- Master font, global behavior, quick actions, profile management.
------------------------------------------------------------------------
function TSBT.BuildTab_General()
    return {
        type  = "group",
        name  = "General",
        order = 1,
        args  = {
            headerMaster = {
                type  = "header",
                name  = "Master Controls",
                order = 1,
            },
            enabled = {
                type  = "toggle",
                name  = "Enable TrueStrike",
                desc  = "Master switch to enable or disable all TrueStrike output.",
                width = "full",
                order = 2,
                get   = function() return TSBT.db.profile.general.enabled end,
                set   = function(_, val)
                    TSBT.db.profile.general.enabled = val

                    -- Drive runtime gating immediately (safe no-ops in skeleton layers).
                    if TSBT.Core then
                        if val and TSBT.Core.Enable then TSBT.Core:Enable() end
                        if (not val) and TSBT.Core.Disable then TSBT.Core:Disable() end
                    end

                    if TSBT.Parser then
                        if val then
                            if TSBT.Parser.CombatLog and TSBT.Parser.CombatLog.Enable then
                                TSBT.Parser.CombatLog:Enable()
                            end
                            if TSBT.Parser.Cooldowns and TSBT.Parser.Cooldowns.Enable then
                                TSBT.Parser.Cooldowns:Enable()
                            end
                        else
                            if TSBT.Parser.Cooldowns and TSBT.Parser.Cooldowns.Disable then
                                TSBT.Parser.Cooldowns:Disable()
                            end
                            if TSBT.Parser.CombatLog and TSBT.Parser.CombatLog.Disable then
                                TSBT.Parser.CombatLog:Disable()
                            end
                        end
                    end

                    LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                end,
            },
            combatOnly = {
                type  = "toggle",
                name  = "Combat Only Mode",
                desc  = "Only display TrueStrike output while you are in combat.",
                width = "full",
                order = 3,
                get   = function() return TSBT.db.profile.general.combatOnly end,
                set   = function(_, val)
                    TSBT.db.profile.general.combatOnly = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                end,
            },

            headerFont = {
                type  = "header",
                name  = "Master Font",
                order = 10,
            },
            fontFace = {
                type   = "select",
                name   = "Font Face",
                desc   = "Global font used for all TrueStrike combat text.",
                order  = 11,
                values = function() return TSBT.BuildFontDropdown() end,
                get    = function() return TSBT.db.profile.general.font.face end,
                set    = function(_, val)
                    TSBT.db.profile.general.font.face = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                end,
            },
            fontSize = {
                type  = "range",
                name  = "Font Size",
                desc  = "Base size for TrueStrike combat text numbers.",
                order = 12,
                min   = TSBT.FONT_SIZE_MIN,
                max   = TSBT.FONT_SIZE_MAX,
                step  = 1,
                get   = function() return TSBT.db.profile.general.font.size end,
                set   = function(_, val)
                    TSBT.db.profile.general.font.size = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                end,
            },
            fontOutline = {
                type   = "select",
                name   = "Outline Style",
                desc   = "Font outline thickness.",
                order  = 13,
                values = TSBT.ValuesFromKeys(TSBT.OUTLINE_STYLES),
                get    = function() return TSBT.db.profile.general.font.outline end,
                set    = function(_, val)
                    TSBT.db.profile.general.font.outline = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                end,
            },
            fontAlpha = {
                type      = "range",
                name      = "Text Opacity",
                desc      = "Global transparency for TrueStrike text.",
                order     = 14,
                min       = TSBT.ALPHA_MIN,
                max       = TSBT.ALPHA_MAX,
                step      = 0.05,
                isPercent = true,
                get       = function() return TSBT.db.profile.general.font.alpha end,
                set       = function(_, val)
                    TSBT.db.profile.general.font.alpha = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                end,
            },

            headerActions = {
                type  = "header",
                name  = "Quick Actions",
                order = 30,
            },
            resetDefaults = {
                type    = "execute",
                name    = "Reset to Defaults",
                desc    = "Reset settings to defaults (tracked cooldown spells are preserved).",
                order   = 31,
                confirm = true,
                confirmText = "Reset all settings to defaults?\n\nTracked cooldown spells will be preserved.",
                func    = function()
                    -- Preserve tracked cooldown spells.
                    local preservedTracked = nil
                    if TSBT.db
                        and TSBT.db.profile
                        and TSBT.db.profile.cooldowns
                        and TSBT.db.profile.cooldowns.tracked then

                        preservedTracked = {}
                        for k, v in pairs(TSBT.db.profile.cooldowns.tracked) do
                            preservedTracked[k] = v
                        end
                    end

                    TSBT.db:ResetProfile()

                    if preservedTracked then
                        TSBT.db.profile.cooldowns.tracked = preservedTracked
                    end

                    Addon:Print("Settings reset to defaults.")
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                end,
            },
            reloadUI = {
                type    = "execute",
                name    = "Reload UI",
                desc    = "Reload the World of Warcraft user interface.",
                order   = 32,
                confirm = true,
                confirmText = "Reload the UI now?",
                func    = function() ReloadUI() end,
            },
            versionInfo = {
                type  = "description",
                name  = "\n|cFF888888" .. TSBT.ADDON_TITLE .. " v" .. TSBT.VERSION .. "|r",
                order = 40,
            },
        },
    }
end


------------------------------------------------------------------------
-- TAB 2: SCROLL AREAS
-- Create/delete/rename scroll areas and configure their geometry.
------------------------------------------------------------------------


-- Module-level state for selected scroll area
local selectedScrollArea = nil
local renameScrollAreaBuffer = ""
local createScrollAreaBuffer = ""

local function GetFallbackScrollAreaName()
    -- Prefer Incoming if it exists; otherwise pick the first available area name.
    if TSBT and TSBT.db and TSBT.db.profile and TSBT.db.profile.scrollAreas then
        if TSBT.db.profile.scrollAreas["Incoming"] then
            return "Incoming"
        end
        for name in pairs(TSBT.db.profile.scrollAreas) do
            return name
        end
    end
    return nil
end

local function EnsureSelectedScrollArea()
    local names = TSBT.GetScrollAreaNames and TSBT.GetScrollAreaNames() or nil
    if names and selectedScrollArea and names[selectedScrollArea] then
        return selectedScrollArea
    end

    -- Default to Incoming if present.
    if names and names["Incoming"] then
        selectedScrollArea = "Incoming"
        return selectedScrollArea
    end

    -- Otherwise choose first available.
    if names then
        for name in pairs(names) do
            selectedScrollArea = name
            return selectedScrollArea
        end
    end

    -- Last resort: check raw table (should not happen if values() is correct).
    selectedScrollArea = GetFallbackScrollAreaName()
    return selectedScrollArea
end

local function ReplaceScrollAreaRefsInProfile(oldName, newName)
    if not oldName or not newName or oldName == newName then return end
    if not TSBT or not TSBT.db or not TSBT.db.profile then return end

    local function walk(tbl)
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                walk(v)
            elseif k == "scrollArea" and v == oldName then
                tbl[k] = newName
            end
        end
    end

    walk(TSBT.db.profile)
end

local function CreateDefaultScrollArea(name)
    name = name or "Incoming"
    if TSBT.db.profile.scrollAreas[name] then return name end

    TSBT.db.profile.scrollAreas[name] = {
        xOffset   = -450,
        yOffset   = 250,
        width     = 200,
        height    = 300,
        alignment = "Center",
        direction = "Up",
        animation = "Straight",
        animSpeed = 1.0,
        font      = {
            useGlobal = true,
            face      = TSBT.db.profile.general.font.face,
            size      = TSBT.db.profile.general.font.size,
            outline   = TSBT.db.profile.general.font.outline,
            alpha     = TSBT.db.profile.general.font.alpha,
        },
    }
    return name
end

local function MakeUniqueScrollAreaName(base)
    base = base or "New Area"
    if not TSBT.db.profile.scrollAreas[base] then return base end
    local i = 2
    while true do
        local candidate = base .. " " .. i
        if not TSBT.db.profile.scrollAreas[candidate] then
            return candidate
        end
        i = i + 1
    end
end

function TSBT.BuildTab_ScrollAreas()
    return {
        type  = "group",
        name  = "Scroll Areas",
        order = 2,
        args  = {
            ----------------------------------------------------------------
            -- Area Selection & Management
            ----------------------------------------------------------------
            headerAreas = {
                type  = "header",
                name  = "Scroll Area Management",
                order = 1,
            },
            spacerAreas = {
                type  = "description",
                name  = " ",
                order = 1.5,
                width = "full",
            },

            -- Line 1: Select + Delete
            rowSelect = {
                type   = "group",
                name   = "",
                inline = true,
                order  = 2,
                args   = {
                    selectArea = {
                        type   = "select",
                        name   = "Select Scroll Area",
                        desc   = "Choose a scroll area to configure.",
                        order  = 1,
                        width  = "double",
                        values = function() return TSBT.GetScrollAreaNames() end,
                        get    = function() return EnsureSelectedScrollArea() end,
                        set    = function(_, val)
                            selectedScrollArea = val
                            LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                        end,
                    },
                    deleteArea = {
                        type     = "execute",
                        name     = "Delete Selected",
                        desc     = "Remove the currently selected scroll area.",
                        order    = 2,
                        width    = "normal",
                        disabled = function() return not EnsureSelectedScrollArea() end,
                        func     = function()
                            local sel = EnsureSelectedScrollArea()
                            if not sel then return end

                            local count = 0
                            for _ in pairs(TSBT.db.profile.scrollAreas) do count = count + 1 end

                            if count <= 1 then
                                -- Last area safeguard: we never allow zero areas. We delete, then immediately create a new default.
                                StaticPopup_Show("TRUESTRIKE_DELETE_LAST_SCROLLAREA", sel, nil, sel)
                                return
                            end

                            StaticPopup_Show("TRUESTRIKE_DELETE_SCROLLAREA", sel, nil, sel)
                        end,
                    },
                },
            },

            -- Line 2: Rename + Apply
            rowRename = {
                type   = "group",
                name   = "",
                inline = true,
                order  = 3,
                args   = {
                    renameAreaName = {
                        type   = "input",
                        name   = "Rename Selected",
                        desc   = "Rename the currently selected scroll area.",
                        order  = 1,
                        width  = "double",
                        hidden = function() return not EnsureSelectedScrollArea() end,
                        get    = function()
                            if renameScrollAreaBuffer == "" then
                                return EnsureSelectedScrollArea() or ""
                            end
                            return renameScrollAreaBuffer
                        end,
                        set    = function(_, val)
                            renameScrollAreaBuffer = strtrim(val or "")
                        end,
                    },
                    applyRename = {
                        type     = "execute",
                        name     = "Apply Rename",
                        desc     = "Apply the rename to the selected scroll area.",
                        order    = 2,
                        width    = "normal",
                        hidden   = function() return not EnsureSelectedScrollArea() end,
                        disabled = function()
                            local sel = EnsureSelectedScrollArea()
                            local newName = strtrim(renameScrollAreaBuffer or "")
                            if not sel or newName == "" or newName == sel then return true end
                            return TSBT.db.profile.scrollAreas[newName] ~= nil
                        end,
                        func     = function()
                            local oldName = EnsureSelectedScrollArea()
                            local newName = strtrim(renameScrollAreaBuffer or "")
                            if not oldName or newName == "" or newName == oldName then return end

                            if TSBT.db.profile.scrollAreas[newName] then
                                TSBT.Addon:Print("Scroll area '" .. newName .. "' already exists.")
                                return
                            end

                            TSBT.db.profile.scrollAreas[newName] = TSBT.db.profile.scrollAreas[oldName]
                            TSBT.db.profile.scrollAreas[oldName] = nil

                            ReplaceScrollAreaRefsInProfile(oldName, newName)

                            selectedScrollArea = newName
                            renameScrollAreaBuffer = ""

                            if TSBT.IsScrollAreasUnlocked and TSBT.IsScrollAreasUnlocked() and TSBT.RefreshScrollAreaFrames then
                                TSBT.RefreshScrollAreaFrames()
                            end

                            LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                            TSBT.Addon:Print("Renamed scroll area: " .. oldName .. " -> " .. newName)
                        end,
                    },
                },
            },

            -- Line 3: Create New Area (input + explicit Create button)
            rowCreate = {
                type   = "group",
                name   = "",
                inline = true,
                order  = 4,
                args   = {
                    createAreaName = {
                        type  = "input",
                        name  = "Create New Area",
                        desc  = "Type a name and press Enter (or click OK) to create. If blank, nothing will be created.",
                        order = 1,
                        width = "full",
                        get   = function() return createScrollAreaBuffer or "" end,
                        set   = function(_, val)
                            val = strtrim(val or "")
                            createScrollAreaBuffer = val
                            if val == "" then
                                LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                                return
                            end

                            if TSBT.db.profile.scrollAreas[val] then
                                Addon:Print("Scroll area '" .. val .. "' already exists.")
                                return
                            end

                            TSBT.db.profile.scrollAreas[val] = {
                                xOffset   = -450,
                                yOffset   = 250,
                                width     = 200,
                                height    = 300,
                                alignment = "Center",
                                direction = "Up",
                                animation = "Straight",
                                animSpeed = 1.0,
                                font      = {
                                    useGlobal = true,
                                    face      = TSBT.db.profile.general.font.face,
                                    size      = TSBT.db.profile.general.font.size,
                                    outline   = TSBT.db.profile.general.font.outline,
                                    alpha     = TSBT.db.profile.general.font.alpha,
                                },
                            }

                            selectedScrollArea = val
                            createScrollAreaBuffer = ""
                            Addon:Print("Created scroll area: " .. val)

                            if TSBT.IsScrollAreasUnlocked and TSBT.IsScrollAreasUnlocked() and TSBT.RefreshScrollAreaFrames then
                                TSBT.RefreshScrollAreaFrames()
                            end
                            LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                        end,
                    },
                },
            },

            -- Line 4: Lock / Unlock
            unlockAreas = {
                type  = "execute",
                name  = function()
                    if TSBT.IsScrollAreasUnlocked and TSBT.IsScrollAreasUnlocked() then
                        return "Lock Scroll Areas"
                    end
                    return "Unlock Scroll Areas"
                end,
                desc  = "Show draggable frames on screen for each scroll area. Drag to reposition, then lock to save.",
                order = 5,
                width = "full",
                func  = function()
                    if TSBT.IsScrollAreasUnlocked and TSBT.IsScrollAreasUnlocked() then
                        TSBT.HideScrollAreaFrames()
                        Addon:Print("Scroll areas locked.")
                    else
                        TSBT.ShowScrollAreaFrames()
                    end
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                end,
            },

            ----------------------------------------------------------------
            -- Unlock / Lock Toggle
            ----------------------------------------------------------------
-- Geometry (only visible when an area is selected)
            ----------------------------------------------------------------
            spacerGeometry = {
                type   = "description",
                name   = " ",
                order  = 9.5,
                width  = "full",
                hidden = function() return not selectedScrollArea end,
            },
            headerGeometry = {
                type   = "header",
                name   = "Geometry",
                order  = 10,
                hidden = function() return not selectedScrollArea end,
            },
            xOffset = {
                type   = "range",
                name   = "X Offset",
                desc   = "Horizontal position relative to screen center.",
                order  = 11,
                min    = TSBT.SCROLL_OFFSET_MIN,
                max    = TSBT.SCROLL_OFFSET_MAX,
                step   = 5,
                hidden = function() return not selectedScrollArea end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return area and area.xOffset or 0
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if area then
                        area.xOffset = val
                        -- Update visualization frame in real-time
                        if TSBT.UpdateScrollAreaFrames then
                            TSBT.UpdateScrollAreaFrames()
                        end
                    end
                end,
            },
            yOffset = {
                type   = "range",
                name   = "Y Offset",
                desc   = "Vertical position relative to screen center.",
                order  = 12,
                min    = TSBT.SCROLL_OFFSET_MIN,
                max    = TSBT.SCROLL_OFFSET_MAX,
                step   = 5,
                hidden = function() return not selectedScrollArea end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return area and area.yOffset or 0
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if area then
                        area.yOffset = val
                        -- Update visualization frame in real-time
                        if TSBT.UpdateScrollAreaFrames then
                            TSBT.UpdateScrollAreaFrames()
                        end
                    end
                end,
            },
            areaWidth = {
                type   = "range",
                name   = "Width",
                desc   = "Width of the scroll area in pixels.",
                order  = 13,
                min    = TSBT.SCROLL_WIDTH_MIN,
                max    = TSBT.SCROLL_WIDTH_MAX,
                step   = 10,
                hidden = function() return not selectedScrollArea end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return area and area.width or 200
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if area then
                        area.width = val
                        -- Update visualization frame in real-time
                        if TSBT.UpdateScrollAreaFrames then
                            TSBT.UpdateScrollAreaFrames()
                        end
                    end
                end,
            },
            areaHeight = {
                type   = "range",
                name   = "Height",
                desc   = "Height of the scroll area in pixels.",
                order  = 14,
                min    = TSBT.SCROLL_HEIGHT_MIN,
                max    = TSBT.SCROLL_HEIGHT_MAX,
                step   = 10,
                hidden = function() return not selectedScrollArea end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return area and area.height or 300
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if area then
                        area.height = val
                        -- Update visualization frame in real-time
                        if TSBT.UpdateScrollAreaFrames then
                            TSBT.UpdateScrollAreaFrames()
                        end
                    end
                end,
            },

            ----------------------------------------------------------------
            -- Font Override (per selected area)
            ----------------------------------------------------------------
            headerAreaFont = {
                type   = "header",
                name   = "Font Override",
                order  = 15,
                hidden = function() return not selectedScrollArea end,
            },
            areaFontUseGlobal = {
                type   = "toggle",
                name   = "Use Global Font",
                desc   = "When enabled, this scroll area uses the Master Font from the General tab.",
                order  = 16,
                width  = "full",
                hidden = function() return not selectedScrollArea end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    local f = area and area.font
                    if not f then return true end
                    return f.useGlobal ~= false
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if not area then return end
                    area.font = area.font or {
                        useGlobal = true,
                        face      = TSBT.db.profile.general.font.face,
                        size      = TSBT.db.profile.general.font.size,
                        outline   = TSBT.db.profile.general.font.outline,
                        alpha     = TSBT.db.profile.general.font.alpha,
                    }
                    area.font.useGlobal = val and true or false
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                end,
            },
            areaFontFace = {
                type   = "select",
                name   = "Font Face",
                desc   = "Font used for this scroll area when Use Global Font is disabled.",
                order  = 17,
                values = function() return TSBT.BuildFontDropdown() end,
                hidden = function()
                    if not selectedScrollArea then return true end
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return not area or not area.font or area.font.useGlobal ~= false
                end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return area and area.font and area.font.face or TSBT.db.profile.general.font.face
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if not area then return end
                    area.font = area.font or { useGlobal = false }
                    area.font.face = val
                end,
            },
            areaFontSize = {
                type   = "range",
                name   = "Font Size",
                desc   = "Font size for this scroll area when Use Global Font is disabled.",
                order  = 18,
                min    = TSBT.FONT_SIZE_MIN,
                max    = TSBT.FONT_SIZE_MAX,
                step   = 1,
                hidden = function()
                    if not selectedScrollArea then return true end
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return not area or not area.font or area.font.useGlobal ~= false
                end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return area and area.font and area.font.size or TSBT.db.profile.general.font.size
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if not area then return end
                    area.font = area.font or { useGlobal = false }
                    area.font.size = val
                end,
            },
            areaFontOutline = {
                type   = "select",
                name   = "Outline Style",
                desc   = "Outline style for this scroll area when Use Global Font is disabled.",
                order  = 19,
                values = TSBT.ValuesFromKeys(TSBT.OUTLINE_STYLES),
                hidden = function()
                    if not selectedScrollArea then return true end
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return not area or not area.font or area.font.useGlobal ~= false
                end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return area and area.font and area.font.outline or TSBT.db.profile.general.font.outline
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if not area then return end
                    area.font = area.font or { useGlobal = false }
                    area.font.outline = val
                end,
            },
            areaFontAlpha = {
                type      = "range",
                name      = "Text Opacity",
                desc      = "Text opacity for this scroll area when Use Global Font is disabled.",
                order     = 20,
                min       = TSBT.ALPHA_MIN,
                max       = TSBT.ALPHA_MAX,
                step      = 0.05,
                isPercent = true,
                hidden = function()
                    if not selectedScrollArea then return true end
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return not area or not area.font or area.font.useGlobal ~= false
                end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return area and area.font and area.font.alpha or TSBT.db.profile.general.font.alpha
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if not area then return end
                    area.font = area.font or { useGlobal = false }
                    area.font.alpha = val
                end,
            },

            ----------------------------------------------------------------
            -- Layout & Animation
            ----------------------------------------------------------------
            spacerLayout = {
                type   = "description",
                name   = " ",
                order  = 20.5,
                width  = "full",
                hidden = function() return not selectedScrollArea end,
            },
            headerLayout = {
                type   = "header",
                name   = "Layout & Animation",
                order  = 21,
                hidden = function() return not selectedScrollArea end,
            },
            alignment = {
                type   = "select",
                name   = "Text Alignment",
                desc   = "Horizontal text alignment within the scroll area.",
                order  = 22,
                values = TSBT.ValuesFromKeys(TSBT.TEXT_ALIGNMENTS),
                hidden = function() return not selectedScrollArea end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return area and area.alignment or "Center"
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if area then area.alignment = val end
                end,
            },
            direction = {
                type   = "select",
                name   = "Scroll Direction",
                desc   = "Direction text scrolls.",
                order  = 23,
                values = TSBT.ValuesFromKeys(TSBT.SCROLL_DIRECTIONS),
                hidden = function() return not selectedScrollArea end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return area and area.direction or "Up"
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if area then area.direction = val end
                end,
            },
            animation = {
                type   = "select",
                name   = "Animation Style",
                desc   = "How text moves through the scroll area.",
                order  = 24,
                values = TSBT.ValuesFromKeys(TSBT.ANIMATION_STYLES),
                hidden = function() return not selectedScrollArea end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return area and area.animation or "Straight"
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if area then area.animation = val end
                    -- Force AceConfig to re-evaluate hidden states (animSpeed depends on this)
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                end,
            },
            animSpeed = {
                type   = "range",
                name   = "Animation Speed",
                desc   = "Duration in seconds for text animation (1.0 = normal).",
                order  = 25,
                width  = "full",
                min    = 0.5,
                max    = 3.0,
                step   = 0.1,
                -- Hidden when no area selected, or when animation style is Static
                hidden = function()
                    if not selectedScrollArea then return true end
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if area and area.animation == "Static" then return true end
                    return false
                end,
                get    = function()
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    return area and area.animSpeed or 1.0
                end,
                set    = function(_, val)
                    local area = TSBT.db.profile.scrollAreas[selectedScrollArea]
                    if area then area.animSpeed = val end
                end,
            },
            testAnimation = {
                type     = "execute",
                -- Keep the button label short to avoid AceGUI truncation.
                name     = "Test Selected",
                desc     = "Fire 3 test events into this scroll area using its current settings. " ..
                           "Scroll areas must be unlocked to test.",
                order    = 26,
                width    = full,
                hidden   = function() return not selectedScrollArea end,
                disabled = function()
                    -- Disabled if no area selected OR if areas aren't unlocked
                    if not selectedScrollArea then return true end
                    if TSBT.IsScrollAreasUnlocked and not TSBT.IsScrollAreasUnlocked() then
                        return true
                    end
                    return false
                end,
                func     = function()
                    if TSBT.TestScrollArea then
                        TSBT.TestScrollArea(selectedScrollArea)
                    else
                        Addon:Print("Display system not yet available.")
                    end
                end,
            },
            testAllAreas = {
                type     = "execute",
                name     = function()
                    if TSBT.IsContinuousTesting and TSBT.IsContinuousTesting() then
                        return "Stop All Tests"
                    end
                    return "Test All (Unlocked)"
                end,
                desc     = "Toggle continuous test animation on all unlocked scroll areas. " ..
                           "Animations repeat every 3 seconds. Scroll areas must be unlocked to test.",
                order    = 27,
                width    = full,
                disabled = function()
                    -- Disabled if areas aren't unlocked (unless already running, then allow stop)
                    if TSBT.IsContinuousTesting and TSBT.IsContinuousTesting() then
                        return false
                    end
                    if TSBT.IsScrollAreasUnlocked and not TSBT.IsScrollAreasUnlocked() then
                        return true
                    end
                    return false
                end,
                func     = function()
                    if TSBT.IsContinuousTesting and TSBT.IsContinuousTesting() then
                        if TSBT.StopContinuousTesting then
                            TSBT.StopContinuousTesting()
                        end
                    else
                        if TSBT.StartContinuousTesting then
                            TSBT.StartContinuousTesting()
                        end
                    end
                end,
            },

            selectedAreaLabel = {
                type   = "description",
                name   = function()
                    if not selectedScrollArea then return "" end
                    return "|cFF888888Selected:|r " .. selectedScrollArea
                end,
                order  = 28,
                width  = "full",
                fontSize = "medium",
                hidden = function() return not selectedScrollArea end,
            },
        },
    }
end

------------------------------------------------------------------------
-- TAB 3: INCOMING
-- Incoming damage and healing configuration.
------------------------------------------------------------------------
function TSBT.BuildTab_Incoming()
    local function cap()
        return TSBT.Core and TSBT.Core.IncomingProbe and TSBT.Core.IncomingProbe.cap
    end

    local function reportLine()
        local p = TSBT.Core and TSBT.Core.IncomingProbe
        if not p or not p.GetCapabilityReport then
            return "Incoming probe not loaded."
        end
        local r = p:GetCapabilityReport()
        return ("Probe: source=%s | flags=%s | school=%s | periodic=%s | buffer=%d/%d")
            :format(r.source, r.hasFlagText, r.hasSchool, r.hasPeriodic, r.bufferCount, r.bufferMax)
    end

    return {
        type  = "group",
        name  = "Incoming",
        order = 3,
        args  = {
            ----------------------------------------------------------------
            -- Incoming Damage
            ----------------------------------------------------------------
            headerDamage = {
                type  = "header",
                name  = "Incoming Damage",
                order = 1,
            },
            damageEnabled = {
                type  = "toggle",
                name  = "Show Incoming Damage",
                desc  = "Display damage taken by your character.",
                width = "full",
                order = 2,
                get   = function() return TSBT.db.profile.incoming.damage.enabled end,
                set   = function(_, val) TSBT.db.profile.incoming.damage.enabled = val end,
            },
            damageScrollArea = {
                type   = "select",
                name   = "Scroll Area",
                desc   = "Which scroll area displays incoming damage.",
                order  = 3,
                values = function() return TSBT.GetScrollAreaNames() end,
                get    = function() return TSBT.db.profile.incoming.damage.scrollArea end,
                set    = function(_, val) TSBT.db.profile.incoming.damage.scrollArea = val end,
            },
            damageShowFlags = {
                type  = "toggle",
                name  = "Show Damage Flags",
                desc  = "Display flags like Crushing, Glancing, Absorb, Block, Resist.",
                width = "full",
                order = 4,
                disabled = function()
                    local c = cap()
                    return c and c.hasFlagText == false
                end,
                get   = function() return TSBT.db.profile.incoming.damage.showFlags end,
                set   = function(_, val) TSBT.db.profile.incoming.damage.showFlags = val end,
            },
            damageMinThreshold = {
                type    = "range",
                name    = "Minimum Damage Threshold",
                desc    = "Suppress incoming damage below this value (0 = show all).",
                order   = 5,
                min     = 0,
                max     = 10000,
                softMax = 5000,
                step    = 50,
                get     = function() return TSBT.db.profile.incoming.damage.minThreshold end,
                set     = function(_, val) TSBT.db.profile.incoming.damage.minThreshold = val end,
            },

            ----------------------------------------------------------------
            -- Incoming Healing
            ----------------------------------------------------------------
            headerHealing = {
                type  = "header",
                name  = "Incoming Healing",
                order = 10,
            },
            healingEnabled = {
                type  = "toggle",
                name  = "Show Incoming Healing",
                desc  = "Display healing received by your character.",
                width = "full",
                order = 11,
                get   = function() return TSBT.db.profile.incoming.healing.enabled end,
                set   = function(_, val) TSBT.db.profile.incoming.healing.enabled = val end,
            },
            healingScrollArea = {
                type   = "select",
                name   = "Scroll Area",
                desc   = "Which scroll area displays incoming healing.",
                order  = 12,
                values = function() return TSBT.GetScrollAreaNames() end,
                get    = function() return TSBT.db.profile.incoming.healing.scrollArea end,
                set    = function(_, val) TSBT.db.profile.incoming.healing.scrollArea = val end,
            },
            healingShowHoTs = {
                type  = "toggle",
                name  = "Show HoT Ticks Separately",
                desc  = "Display each Heal-over-Time tick as its own number. (Requires periodic classification from the live source.)",
                width = "full",
                order = 13,
                disabled = function()
                    local c = cap()
                    return c and c.hasPeriodic == false
                end,
                get   = function() return TSBT.db.profile.incoming.healing.showHoTTicks end,
                set   = function(_, val) TSBT.db.profile.incoming.healing.showHoTTicks = val end,
            },
            healingMinThreshold = {
                type    = "range",
                name    = "Minimum Healing Threshold",
                desc    = "Suppress incoming heals below this value (0 = show all).",
                order   = 14,
                min     = 0,
                max     = 10000,
                softMax = 5000,
                step    = 50,
                get     = function() return TSBT.db.profile.incoming.healing.minThreshold end,
                set     = function(_, val) TSBT.db.profile.incoming.healing.minThreshold = val end,
            },

            ----------------------------------------------------------------
            -- Color Settings
            ----------------------------------------------------------------
            headerColors = {
                type  = "header",
                name  = "Color Settings",
                order = 20,
            },
            useSchoolColors = {
                type  = "toggle",
                name  = "Use Damage School Colors",
                desc  = "Color incoming damage numbers by damage school (Fire, Frost, etc.).",
                width = "full",
                order = 21,
                disabled = function()
                    local c = cap()
                    return c and c.hasSchool == false
                end,
                get   = function() return TSBT.db.profile.incoming.useSchoolColors end,
                set   = function(_, val) TSBT.db.profile.incoming.useSchoolColors = val end,
            },
            customColor = {
                type     = "color",
                name     = "Custom Color Override",
                desc     = "Fallback color when school colors are disabled.",
                order    = 22,
                disabled = function() return TSBT.db.profile.incoming.useSchoolColors end,
                get      = function()
                    local c = TSBT.db.profile.incoming.customColor
                    return c.r, c.g, c.b
                end,
                set      = function(_, r, g, b)
                    local c = TSBT.db.profile.incoming.customColor
                    c.r, c.g, c.b = r, g, b
                end,
            },

            ----------------------------------------------------------------
            -- UI/UX Validation Harness (Capture + Replay)
            ----------------------------------------------------------------
            headerProbe = {
                type  = "header",
                name  = "Incoming Diagnostics (UI Test)",
                order = 30,
            },
            probeReport = {
                type  = "description",
                name  = reportLine,
                order = 31,
                width = "full",
                fontSize = "medium",
            },
            probeStart10 = {
                type  = "execute",
                name  = "Capture 10s",
                desc  = "Capture real incoming UNIT_COMBAT events for 10 seconds and emit them live.",
                order = 32,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.IncomingProbe
                    if p and p.StartCapture then p:StartCapture(10) end
                end,
            },
            probeStart30 = {
                type  = "execute",
                name  = "Capture 30s",
                desc  = "Capture real incoming UNIT_COMBAT events for 30 seconds and emit them live.",
                order = 33,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.IncomingProbe
                    if p and p.StartCapture then p:StartCapture(30) end
                end,
            },
            probeStop = {
                type  = "execute",
                name  = "Stop Capture",
                desc  = "Stop capture early.",
                order = 34,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.IncomingProbe
                    if p and p.StopCapture then p:StopCapture(false) end
                end,
            },
            probeReplay1 = {
                type  = "execute",
                name  = "Replay (1x)",
                desc  = "Replay the captured sample through display routing.",
                order = 35,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.IncomingProbe
                    if p and p.Replay then p:Replay(1.0) end
                end,
            },
            probeReplay2 = {
                type  = "execute",
                name  = "Replay (2x)",
                desc  = "Replay faster.",
                order = 36,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.IncomingProbe
                    if p and p.Replay then p:Replay(2.0) end
                end,
            },
            probeStopReplay = {
                type  = "execute",
                name  = "Stop Replay",
                desc  = "Stop replay early.",
                order = 37,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.IncomingProbe
                    if p and p.StopReplay then p:StopReplay(false) end
                end,
            },
            probePrint = {
                type  = "execute",
                name  = "Print Capability Report",
                desc  = "Print a one-line capability report to chat.",
                order = 38,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.IncomingProbe
                    if p and p.PrintCapabilityReport then p:PrintCapabilityReport() end
                end,
            },

        },
    }
end

------------------------------------------------------------------------
-- TAB 4: OUTGOING
-- Outgoing damage and healing configuration.
------------------------------------------------------------------------
function TSBT.BuildTab_Outgoing()
    local function reportLine()
        local p = TSBT.Core and TSBT.Core.OutgoingProbe
        if not p or not p.GetStatusLine then
            return "Outgoing probe not available."
        end
        local s = p:GetStatusLine() or {}
        local cap = string.format("buffer=%d/%d", tonumber(s.bufferCount) or 0,
                                  tonumber(s.bufferMax) or 0)
        if s.capturing then
            return "Outgoing probe: capturing… " .. cap
        end
        if s.replaying then
            return "Outgoing probe: replaying… " .. cap
        end
        return "Outgoing probe: idle. " .. cap
    end

    return {
        type  = "group",
        name  = "Outgoing",
        order = 4,
        args  = {
            ----------------------------------------------------------------
            -- Outgoing Damage
            ----------------------------------------------------------------
            headerDamage = {
                type  = "header",
                name  = "Outgoing Damage",
                order = 1,
            },
            damageEnabled = {
                type  = "toggle",
                name  = "Show Outgoing Damage",
                desc  = "Display damage dealt by your character.",
                width = "full",
                order = 2,
                get   = function() return TSBT.db.profile.outgoing.damage.enabled end,
                set   = function(_, val) TSBT.db.profile.outgoing.damage.enabled = val end,
            },
            showSpellNames = {
                type  = "toggle",
                name  = "Show Spell Names",
                desc  = "Append the spell name after damage numbers.",
                width = "full",
                order = 3,
                get   = function() return TSBT.db.profile.outgoing.showSpellNames end,
                set   = function(_, val) TSBT.db.profile.outgoing.showSpellNames = val end,
            },
            damageScrollArea = {
                type   = "select",
                name   = "Scroll Area",
                desc   = "Which scroll area displays outgoing damage.",
                order  = 4,
                values = function() return TSBT.GetScrollAreaNames() end,
                get    = function() return TSBT.db.profile.outgoing.damage.scrollArea end,
                set    = function(_, val) TSBT.db.profile.outgoing.damage.scrollArea = val end,
            },
            showTargets = {
                type  = "toggle",
                name  = "Show Target Names",
                desc  = "Display target name alongside damage numbers (where available).",
                width = "full",
                order = 5,
                get   = function() return TSBT.db.profile.outgoing.damage.showTargets end,
                set   = function(_, val) TSBT.db.profile.outgoing.damage.showTargets = val end,
            },
            autoAttackMode = {
                type   = "select",
                name   = "Auto-Attack Display",
                desc   = "How to display auto-attack/auto-shot damage.",
                order  = 6,
                values = TSBT.ValuesFromKeys(TSBT.AUTOATTACK_MODES),
                get    = function() return TSBT.db.profile.outgoing.damage.autoAttackMode end,
                set    = function(_, val) TSBT.db.profile.outgoing.damage.autoAttackMode = val end,
            },
            damageMinThreshold = {
                type    = "range",
                name    = "Minimum Damage Threshold",
                desc    = "Suppress outgoing damage below this value (0 = show all).",
                order   = 7,
                min     = 0,
                max     = 10000,
                softMax = 5000,
                step    = 50,
                get     = function() return TSBT.db.profile.outgoing.damage.minThreshold end,
                set     = function(_, val) TSBT.db.profile.outgoing.damage.minThreshold = val end,
            },

            ----------------------------------------------------------------
            -- Outgoing Healing
            ----------------------------------------------------------------
            headerHealing = {
                type  = "header",
                name  = "Outgoing Healing",
                order = 10,
            },
            healingEnabled = {
                type  = "toggle",
                name  = "Show Outgoing Healing",
                desc  = "Display healing done by your character.",
                width = "full",
                order = 11,
                get   = function() return TSBT.db.profile.outgoing.healing.enabled end,
                set   = function(_, val) TSBT.db.profile.outgoing.healing.enabled = val end,
            },
            healingScrollArea = {
                type   = "select",
                name   = "Scroll Area",
                desc   = "Which scroll area displays outgoing healing.",
                order  = 12,
                values = function() return TSBT.GetScrollAreaNames() end,
                get    = function() return TSBT.db.profile.outgoing.healing.scrollArea end,
                set    = function(_, val) TSBT.db.profile.outgoing.healing.scrollArea = val end,
            },
            showOverheal = {
                type  = "toggle",
                name  = "Show Overhealing",
                desc  = "Display overhealing amounts.",
                width = "full",
                order = 13,
                get   = function() return TSBT.db.profile.outgoing.healing.showOverheal end,
                set   = function(_, val) TSBT.db.profile.outgoing.healing.showOverheal = val end,
            },
            healingMinThreshold = {
                type    = "range",
                name    = "Minimum Healing Threshold",
                desc    = "Suppress outgoing heals below this value (0 = show all).",
                order   = 14,
                min     = 0,
                max     = 10000,
                softMax = 5000,
                step    = 50,
                get     = function() return TSBT.db.profile.outgoing.healing.minThreshold end,
                set     = function(_, val) TSBT.db.profile.outgoing.healing.minThreshold = val end,
            },

            ----------------------------------------------------------------
            -- UI/UX Validation Harness (Capture + Replay)
            ----------------------------------------------------------------
            headerProbe = {
                type  = "header",
                name  = "Outgoing Diagnostics (UI Test)",
                order = 20,
            },
            probeReport = {
                type  = "description",
                name  = reportLine,
                order = 21,
                width = "full",
                fontSize = "medium",
            },
            probeStart45 = {
                type  = "execute",
                name  = "Capture 45s",
                desc  = "Capture real outgoing CLEU events for 45 seconds and emit them live.",
                order = 22,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.OutgoingProbe
                    if p and p.StartCapture then p:StartCapture(45) end
                end,
            },
            probeStart90 = {
                type  = "execute",
                name  = "Capture 90s",
                desc  = "Longer capture to reliably observe at least one natural auto-attack crit.",
                order = 23,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.OutgoingProbe
                    if p and p.StartCapture then p:StartCapture(90) end
                end,
            },
            probeStop = {
                type  = "execute",
                name  = "Stop Capture",
                desc  = "Stop capture early.",
                order = 24,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.OutgoingProbe
                    if p and p.StopCapture then p:StopCapture(false) end
                end,
            },
            probeReplay1 = {
                type  = "execute",
                name  = "Replay (1x)",
                desc  = "Replay the captured sample through display routing.",
                order = 25,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.OutgoingProbe
                    if p and p.Replay then p:Replay(1.0) end
                end,
            },
            probeReplay2 = {
                type  = "execute",
                name  = "Replay (2x)",
                desc  = "Replay faster.",
                order = 26,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.OutgoingProbe
                    if p and p.Replay then p:Replay(2.0) end
                end,
            },
            probeStopReplay = {
                type  = "execute",
                name  = "Stop Replay",
                desc  = "Stop replay early.",
                order = 27,
                func  = function()
                    local p = TSBT.Core and TSBT.Core.OutgoingProbe
                    if p and p.StopReplay then p:StopReplay(false) end
                end,
            },
        },
    }
end

------------------------------------------------------------------------
-- TAB 5: PETS
-- Pet damage display configuration.
------------------------------------------------------------------------
function TSBT.BuildTab_Pets()
    return {
        type  = "group",
        name  = "Pets",
        order = 5,
        args  = {
            headerPets = {
                type  = "header",
                name  = "Pet Damage",
                order = 1,
            },
            enabled = {
                type  = "toggle",
                name  = "Show Pet Damage",
                desc  = "Display damage dealt by your pets and guardians.",
                width = "full",
                order = 2,
                get   = function() return TSBT.db.profile.pets.enabled end,
                set   = function(_, val) TSBT.db.profile.pets.enabled = val end,
            },
            scrollArea = {
                type   = "select",
                name   = "Scroll Area",
                desc   = "Which scroll area displays pet damage.",
                order  = 3,
                values = function() return TSBT.GetScrollAreaNames() end,
                get    = function() return TSBT.db.profile.pets.scrollArea end,
                set    = function(_, val) TSBT.db.profile.pets.scrollArea = val end,
            },
            aggregation = {
                type   = "select",
                name   = "Aggregation Style",
                desc   = "How pet damage is labeled.",
                order  = 4,
                values = TSBT.ValuesFromKeys(TSBT.PET_AGGREGATION),
                get    = function() return TSBT.db.profile.pets.aggregation end,
                set    = function(_, val) TSBT.db.profile.pets.aggregation = val end,
            },
            minThreshold = {
                type    = "range",
                name    = "Minimum Pet Damage Threshold",
                desc    = "Suppress pet damage below this value (0 = show all).",
                order   = 5,
                min     = 0,
                max     = 10000,
                softMax = 5000,
                step    = 50,
                get     = function() return TSBT.db.profile.pets.minThreshold end,
                set     = function(_, val) TSBT.db.profile.pets.minThreshold = val end,
            },

            ----------------------------------------------------------------
            -- Instance Warning
            ----------------------------------------------------------------
            spacer1 = { type = "description", name = "\n", order = 10 },
            instanceWarning = {
                type     = "description",
                name     = "|cFFFFAA00Note:|r In instanced content (dungeons, raids), pet names may be " ..
                           "unavailable due to WoW API restrictions. Pet damage will display as " ..
                           "\"Pet\" in those scenarios regardless of aggregation setting.",
                order    = 11,
                fontSize = "medium",
            },
        },
    }
end

------------------------------------------------------------------------
-- TAB 6: SPAM CONTROL
-- Merging, throttling, and special suppression settings.
------------------------------------------------------------------------
function TSBT.BuildTab_SpamControl()
    return {
        type  = "group",
        name  = "Spam Control",
        order = 6,
        args  = {
            ----------------------------------------------------------------
            -- Merging
            ----------------------------------------------------------------
            headerMerge = {
                type  = "header",
                name  = "Spell Merging",
                order = 1,
            },
            mergeDesc = {
                type     = "description",
                name     = "Combine multiple hits from the same spell into a single display " ..
                           "(e.g., \"Fireball x3\" instead of three separate numbers).",
                order    = 2,
                fontSize = "medium",
            },
            mergeEnabled = {
                type  = "toggle",
                name  = "Enable Spell Merging",
                desc  = "Merge rapid repeated hits from the same spell.",
                width = "full",
                order = 3,
                get   = function() return TSBT.db.profile.spamControl.merging.enabled end,
                set   = function(_, val) TSBT.db.profile.spamControl.merging.enabled = val end,
            },
            mergeWindow = {
                type     = "range",
                name     = "Merge Window (seconds)",
                desc     = "Time window to group hits from the same spell.",
                order    = 4,
                min      = TSBT.MERGE_WINDOW_MIN,
                max      = TSBT.MERGE_WINDOW_MAX,
                step     = 0.1,
                disabled = function() return not TSBT.db.profile.spamControl.merging.enabled end,
                get      = function() return TSBT.db.profile.spamControl.merging.window end,
                set      = function(_, val) TSBT.db.profile.spamControl.merging.window = val end,
            },
            mergeShowCount = {
                type     = "toggle",
                name     = "Show Merge Count",
                desc     = "Display hit count (e.g., \"x3\") alongside merged damage.",
                width    = "full",
                order    = 5,
                disabled = function() return not TSBT.db.profile.spamControl.merging.enabled end,
                get      = function() return TSBT.db.profile.spamControl.merging.showCount end,
                set      = function(_, val) TSBT.db.profile.spamControl.merging.showCount = val end,
            },

            ----------------------------------------------------------------
            -- Throttling
            ----------------------------------------------------------------
            headerThrottle = {
                type  = "header",
                name  = "Throttling",
                order = 10,
            },
            minDamage = {
                type    = "range",
                name    = "Global Minimum Damage",
                desc    = "Suppress all damage events below this value (0 = show all).",
                order   = 11,
                min     = 0,
                max     = 10000,
                softMax = 2000,
                step    = 25,
                get     = function() return TSBT.db.profile.spamControl.throttling.minDamage end,
                set     = function(_, val) TSBT.db.profile.spamControl.throttling.minDamage = val end,
            },
            minHealing = {
                type    = "range",
                name    = "Global Minimum Healing",
                desc    = "Suppress all healing events below this value (0 = show all).",
                order   = 12,
                min     = 0,
                max     = 10000,
                softMax = 2000,
                step    = 25,
                get     = function() return TSBT.db.profile.spamControl.throttling.minHealing end,
                set     = function(_, val) TSBT.db.profile.spamControl.throttling.minHealing = val end,
            },
            hideAutoBelow = {
                type    = "range",
                name    = "Hide Auto-Attacks Below",
                desc    = "Suppress auto-attack damage below this value (0 = show all).",
                order   = 13,
                min     = 0,
                max     = 5000,
                softMax = 1000,
                step    = 25,
                get     = function() return TSBT.db.profile.spamControl.throttling.hideAutoBelow end,
                set     = function(_, val) TSBT.db.profile.spamControl.throttling.hideAutoBelow = val end,
            },

            ----------------------------------------------------------------
            -- Special Cases
            ----------------------------------------------------------------
            headerSpecial = {
                type  = "header",
                name  = "Special Cases",
                order = 20,
            },
            suppressDummy = {
                type  = "toggle",
                name  = "Suppress Training Dummy Internal Damage",
                desc  = "Filter out the large internal damage numbers that training dummies " ..
                        "generate (these are not real damage).",
                width = "full",
                order = 21,
                get   = function() return TSBT.db.profile.spamControl.suppressDummyDamage end,
                set   = function(_, val) TSBT.db.profile.spamControl.suppressDummyDamage = val end,
            },
        },
    }
end

------------------------------------------------------------------------
-- TAB 7: COOLDOWNS
-- Cooldown notification settings and tracked spell management.
-- Uses C_Spell.GetSpellInfo() for WoW 12.0+ compatibility.
------------------------------------------------------------------------

-- Module-level state for spell input
local cooldownSpellInput = ""

function TSBT.BuildTab_Cooldowns()
    return {
        type  = "group",
        name  = "Cooldowns",
        order = 7,
        args  = {
            headerCooldowns = {
                type  = "header",
                name  = "Cooldown Notifications",
                order = 1,
            },
            enabled = {
                type  = "toggle",
                name  = "Show Cooldown Notifications",
                desc  = "Display a notification when tracked spells come off cooldown.",
                width = "full",
                order = 2,
                get   = function() return TSBT.db.profile.cooldowns.enabled end,
                set   = function(_, val) TSBT.db.profile.cooldowns.enabled = val end,
            },
            scrollArea = {
                type     = "select",
                name     = "Scroll Area",
                desc     = "Which scroll area displays cooldown notifications.",
                order    = 3,
                values   = function() return TSBT.GetScrollAreaNames() end,
                disabled = function() return not TSBT.db.profile.cooldowns.enabled end,
                get      = function() return TSBT.db.profile.cooldowns.scrollArea end,
                set      = function(_, val) TSBT.db.profile.cooldowns.scrollArea = val end,
            },
            format = {
                type     = "input",
                name     = "Notification Format",
                desc     = "Text format for cooldown notifications. Use %s for spell name.",
                order    = 4,
                width    = "double",
                disabled = function() return not TSBT.db.profile.cooldowns.enabled end,
                get      = function() return TSBT.db.profile.cooldowns.format end,
                set      = function(_, val) TSBT.db.profile.cooldowns.format = val end,
            },
            -- Sound dropdown: standard select using BuildSoundDropdown()
            sound = {
                type     = "select",
                name     = "Notification Sound",
                desc     = "Sound to play when a cooldown finishes.",
                order    = 5,
                values   = function() return TSBT.BuildSoundDropdown() end,
                -- No dialogControl — uses standard dropdown
                disabled = function() return not TSBT.db.profile.cooldowns.enabled end,
                get      = function() return TSBT.db.profile.cooldowns.sound end,
                set      = function(_, val) TSBT.db.profile.cooldowns.sound = val end,
            },
            -- Test button for cooldown sound
            testCooldownSound = {
                type     = "execute",
                name     = "Play Sound",
                desc     = "Preview the selected notification sound.",
                order    = 6,
                width    = "half",
                disabled = function() return not TSBT.db.profile.cooldowns.enabled end,
                func     = function()
                    TSBT.PlayLSMSound(TSBT.db.profile.cooldowns.sound)
                end,
            },

            ----------------------------------------------------------------
            -- Tracked Spells Management
            ----------------------------------------------------------------
            headerTracked = {
                type  = "header",
                name  = "Tracked Spells",
                order = 10,
            },
            dragDropZonePlaceholder = {
                type     = "description",
                name     = function()
                    -- Trigger overlay creation when this renders
                    if TSBT.CreateCooldownDropOverlay then
                        C_Timer.After(0.1, TSBT.CreateCooldownDropOverlay)
                    end
                    return ""  -- Empty - overlay will render over this space
                end,
                order    = 11,
                hidden   = function() return not TSBT.db.profile.cooldowns.enabled end,
            },
            manualEntryLabel = {
                type     = "description",
                name     = "\n\n\n\n\n\n\n\n|cFFFFFFFFOr enter spell ID manually:|r",
                order    = 20,
                fontSize = "medium",
                hidden   = function() return not TSBT.db.profile.cooldowns.enabled end,
            },
            addSpellInput = {
                type     = "input",
                name     = "Spell ID",
                desc     = "Enter a numeric spell ID to track.",
                order    = 21,
                width    = "normal",
                disabled = function() return not TSBT.db.profile.cooldowns.enabled end,
                get      = function() return cooldownSpellInput end,
                set      = function(_, val)
                    local spellID = tonumber(val)
                    if spellID then
                        -- Validate the spell exists before adding
                        local name = SafeGetSpellName(spellID)
                        if name then
                            TSBT.db.profile.cooldowns.tracked[spellID] = true
                            Addon:Print("Now tracking: " .. name .. " (ID: " .. spellID .. ")")
                        else
                            TSBT.db.profile.cooldowns.tracked[spellID] = true
                            Addon:Print("Now tracking spell ID: " .. spellID .. " (name not found)")
                        end
                        cooldownSpellInput = ""
                        -- Refresh UI to show new spell in list
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                    else
                        cooldownSpellInput = val
                        Addon:Print("Please enter a numeric spell ID.")
                    end
                end,
            },
            addSpellButton = {
                type     = "execute",
                name     = "Add",
                desc     = "Add the entered spell ID to tracking.",
                order    = 22,
                width    = "half",
                disabled = function()
                    if not TSBT.db.profile.cooldowns.enabled then return true end
                    return tonumber(cooldownSpellInput) == nil
                end,
                func     = function()
                    local spellID = tonumber(cooldownSpellInput)
                    if spellID then
                        local name = SafeGetSpellName(spellID)
                        if name then
                            TSBT.db.profile.cooldowns.tracked[spellID] = true
                            Addon:Print("Now tracking: " .. name .. " (ID: " .. spellID .. ")")
                        else
                            TSBT.db.profile.cooldowns.tracked[spellID] = true
                            Addon:Print("Now tracking spell ID: " .. spellID .. " (name not found)")
                        end
                        cooldownSpellInput = ""
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                    end
                end,
            },
            trackedListHeader = {
                type     = "description",
                name     = function()
                    local tracked = TSBT.db.profile.cooldowns.tracked
                    local count = 0
                    for _ in pairs(tracked) do count = count + 1 end
                    if count == 0 then
                        return "\n|cFF888888No spells currently tracked.|r"
                    end
                    return "\n|cFFFFFFFFCurrently tracking " .. count .. " spell(s):|r"
                end,
                order    = 30,
                fontSize = "medium",
            },
            trackedListContainer = {
                type     = "group",
                name     = "Tracked Spells List",
                order    = 31,
                childGroups = "tree",  -- Makes it a collapsible tree with auto-scroll
                hidden   = function()
                    local count = 0
                    for _ in pairs(TSBT.db.profile.cooldowns.tracked) do count = count + 1 end
                    return count == 0
                end,
                args     = {},  -- Will be populated dynamically below
            },
            -- Dynamic per-spell entries with X (remove) buttons
            -- Built dynamically below in BuildTab_Cooldowns
        },
    }
end

------------------------------------------------------------------------
-- Register the StaticPopup dialog for spell removal confirmation.
-- Must be defined at file scope so it exists when needed.
------------------------------------------------------------------------
StaticPopupDialogs["TRUESTRIKE_REMOVE_SPELL"] = {
    text = "Remove %s from cooldown tracking?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, idKey)
        if TSBT.db and TSBT.db.profile and TSBT.db.profile.cooldowns then
            TSBT.db.profile.cooldowns.tracked[idKey] = nil
            TSBT.Addon:Print("Stopped tracking: " .. tostring(idKey))
            -- Refresh the config UI to remove the spell row
            LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

------------------------------------------------------------------------
-- Register the StaticPopup dialog for scroll area deletion confirmation.
-- Must be defined at file scope so it exists when needed.
------------------------------------------------------------------------
StaticPopupDialogs["TRUESTRIKE_DELETE_SCROLLAREA"] = {
    text = "Delete scroll area '%s'?\n\nAny events assigned to it will need reassignment.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(_, areaName)
        if not areaName or not TSBT.db or not TSBT.db.profile or not TSBT.db.profile.scrollAreas then
            return
        end

        TSBT.db.profile.scrollAreas[areaName] = nil
        TSBT.Addon:Print("Deleted scroll area: " .. tostring(areaName))

        -- Re-select a valid area (prefer Incoming if it exists)
        local newSel = GetFallbackScrollAreaName()
        if not newSel then
            -- Should not happen (we guard against deleting last), but fail-safe anyway.
            newSel = CreateDefaultScrollArea("Incoming")
        end

        ReplaceScrollAreaRefsInProfile(areaName, newSel)
        selectedScrollArea = newSel
        renameScrollAreaBuffer = ""

        if TSBT.IsScrollAreasUnlocked and TSBT.IsScrollAreasUnlocked() and TSBT.RefreshScrollAreaFrames then
            TSBT.RefreshScrollAreaFrames()
        end

        LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["TRUESTRIKE_DELETE_LAST_SCROLLAREA"] = {
    text = "You cannot have zero scroll areas.\n\nIf you delete '%s', TrueStrike will immediately create a new default scroll area.",
    button1 = "OK",
    button2 = "Cancel",
    OnAccept = function(_, areaName)
        if not areaName or not TSBT.db or not TSBT.db.profile or not TSBT.db.profile.scrollAreas then
            return
        end

        -- Delete the last remaining area.
        TSBT.db.profile.scrollAreas[areaName] = nil

        -- Create a new default area (prefer Incoming as the canonical default).
        local newName = "Incoming"
        if TSBT.db.profile.scrollAreas[newName] then
            newName = MakeUniqueScrollAreaName("New Area")
        end
        newName = CreateDefaultScrollArea(newName)

        ReplaceScrollAreaRefsInProfile(areaName, newName)
        selectedScrollArea = newName
        renameScrollAreaBuffer = ""

        if TSBT.IsScrollAreasUnlocked and TSBT.IsScrollAreasUnlocked() and TSBT.RefreshScrollAreaFrames then
            TSBT.RefreshScrollAreaFrames()
        end

        LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
        TSBT.Addon:Print("Created new default scroll area: " .. tostring(newName))
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Override BuildTab_Cooldowns to inject dynamic per-spell remove buttons.
-- We wrap the original builder to add execute buttons for each tracked
-- spell, using a stable ordering based on spell ID.
--
-- AceConfig doesn't support truly dynamic widget lists, so we rebuild
-- the args table each time the tab group is accessed by using a
-- "get children dynamically" pattern via the args function closures.
------------------------------------------------------------------------
do
    local originalBuilder = TSBT.BuildTab_Cooldowns

    TSBT.BuildTab_Cooldowns = function()
        local tab = originalBuilder()

        -- Get the tracked list container
        local container = tab.args.trackedListContainer

        local MAX_TRACKED_SLOTS = 50
        local baseOrder = 1  -- Start at 1 within the container

        for slot = 1, MAX_TRACKED_SLOTS do
            local slotIndex = slot

            local function getSlotIDKey()
                local sorted = {}
                for idKey, _ in pairs(TSBT.db.profile.cooldowns.tracked) do
                    sorted[#sorted + 1] = idKey
                end
                -- Mixed types (numbers for spells, strings for items) require a safe comparator
                table.sort(sorted, function(a, b) return tostring(a) < tostring(b) end)
                return sorted[slotIndex]
            end

            -- Entry label
            container.args["trackedSpell_" .. slot] = {
                type   = "description",
                name   = function()
                    local idKey = getSlotIDKey()
                    if not idKey then return "" end

                    if type(idKey) == "string" and idKey:match("^item:") then
                        local itemID = tonumber(idKey:match("^item:(%d+)$"))
                        local name = SafeGetItemName(itemID) or ("Item #" .. tostring(itemID or "?"))
                        return "  \226\128\162 " .. name .. "  |cFF888888(ID: " .. tostring(itemID or "?") .. ")|r"
                    else
                        local spellID = idKey
                        local name = SafeGetSpellName(spellID) or ("Spell #" .. spellID)
                        return "  \226\128\162 " .. name .. "  |cFF888888(ID: " .. spellID .. ")|r"
                    end
                end,
                order  = baseOrder + (slot - 1) * 2,
                width  = "double",
                hidden = function() return getSlotIDKey() == nil end,
                fontSize = "medium",
            }

            -- Remove (X) button
            container.args["removeSpell_" .. slot] = {
                type   = "execute",
                name   = "|cFFFF4444X|r",
                desc   = function()
                    local idKey = getSlotIDKey()
                    if not idKey then return "Remove entry" end

                    if type(idKey) == "string" and idKey:match("^item:") then
                        local itemID = tonumber(idKey:match("^item:(%d+)$"))
                        local name = SafeGetItemName(itemID) or ("Item #" .. tostring(itemID or "?"))
                        return "Remove " .. name .. " from tracking"
                    else
                        local spellID = idKey
                        local name = SafeGetSpellName(spellID) or ("Spell #" .. spellID)
                        return "Remove " .. name .. " from tracking"
                    end
                end,
                order  = baseOrder + (slot - 1) * 2 + 1,
                width  = "half",
                hidden = function() return getSlotIDKey() == nil end,
                func   = function()
                    local idKey = getSlotIDKey()
                    if idKey then
                        local name
                        if type(idKey) == "string" and idKey:match("^item:") then
                            local itemID = tonumber(idKey:match("^item:(%d+)$"))
                            name = SafeGetItemName(itemID) or ("Item #" .. tostring(itemID or "?"))
                        else
                            local spellID = idKey
                            name = SafeGetSpellName(spellID) or ("Spell #" .. spellID)
                        end
                        StaticPopup_Show("TRUESTRIKE_REMOVE_SPELL", name, nil, idKey)
                    end
                end,
            }
        end

        return tab
    end
end

------------------------------------------------------------------------
-- TAB 8: MEDIA
-- Sound events and damage school color pickers.
-- All sound dropdowns use standard select with BuildSoundDropdown().
-- Each sound dropdown has a "Play Sound" test button.
------------------------------------------------------------------------
function TSBT.BuildTab_Media()
    return {
        type  = "group",
        name  = "Media",
        order = 8,
        args  = {
            ----------------------------------------------------------------
            -- Sound Events
            ----------------------------------------------------------------
            headerSounds = {
                type  = "header",
                name  = "Sound Events",
                order = 1,
            },
            -- Low Health sound: standard select
            lowHealthSound = {
                type   = "select",
                name   = "Low Health Warning",
                desc   = "Sound to play when your health drops to critical levels.",
                order  = 2,
                values = function() return TSBT.BuildSoundDropdown() end,
                -- No dialogControl — uses standard dropdown
                get    = function() return TSBT.db.profile.media.sounds.lowHealth end,
                set    = function(_, val) TSBT.db.profile.media.sounds.lowHealth = val end,
            },
            testLowHealth = {
                type  = "execute",
                name  = "Play Sound",
                desc  = "Preview the selected low health warning sound.",
                order = 3,
                width = "half",
                func  = function()
                    TSBT.PlayLSMSound(TSBT.db.profile.media.sounds.lowHealth)
                end,
            },
            -- Cooldown Ready sound: standard select
            cooldownReadySound = {
                type   = "select",
                name   = "Cooldown Ready",
                desc   = "Sound to play when a tracked cooldown finishes.",
                order  = 4,
                values = function() return TSBT.BuildSoundDropdown() end,
                -- No dialogControl — uses standard dropdown
                get    = function() return TSBT.db.profile.media.sounds.cooldownReady end,
                set    = function(_, val) TSBT.db.profile.media.sounds.cooldownReady = val end,
            },
            testCooldownReady = {
                type  = "execute",
                name  = "Play Sound",
                desc  = "Preview the selected cooldown ready sound.",
                order = 5,
                width = "half",
                func  = function()
                    TSBT.PlayLSMSound(TSBT.db.profile.media.sounds.cooldownReady)
                end,
            },

            ----------------------------------------------------------------
            -- Damage School Colors
            ----------------------------------------------------------------
            headerSchoolColors = {
                type  = "header",
                name  = "Damage School Colors",
                order = 10,
            },
            schoolColorDesc = {
                type     = "description",
                name     = "Customize the color used for each damage school when " ..
                           "school-based coloring is enabled.",
                order    = 11,
                fontSize = "medium",
            },
            colorPhysical = {
                type  = "color",
                name  = "Physical",
                order = 12,
                get   = function()
                    local c = TSBT.db.profile.media.schoolColors.physical
                    return c.r, c.g, c.b
                end,
                set   = function(_, r, g, b)
                    local c = TSBT.db.profile.media.schoolColors.physical
                    c.r, c.g, c.b = r, g, b
                end,
            },
            colorHoly = {
                type  = "color",
                name  = "Holy",
                order = 13,
                get   = function()
                    local c = TSBT.db.profile.media.schoolColors.holy
                    return c.r, c.g, c.b
                end,
                set   = function(_, r, g, b)
                    local c = TSBT.db.profile.media.schoolColors.holy
                    c.r, c.g, c.b = r, g, b
                end,
            },
            colorFire = {
                type  = "color",
                name  = "Fire",
                order = 14,
                get   = function()
                    local c = TSBT.db.profile.media.schoolColors.fire
                    return c.r, c.g, c.b
                end,
                set   = function(_, r, g, b)
                    local c = TSBT.db.profile.media.schoolColors.fire
                    c.r, c.g, c.b = r, g, b
                end,
            },
            colorNature = {
                type  = "color",
                name  = "Nature",
                order = 15,
                get   = function()
                    local c = TSBT.db.profile.media.schoolColors.nature
                    return c.r, c.g, c.b
                end,
                set   = function(_, r, g, b)
                    local c = TSBT.db.profile.media.schoolColors.nature
                    c.r, c.g, c.b = r, g, b
                end,
            },
            colorFrost = {
                type  = "color",
                name  = "Frost",
                order = 16,
                get   = function()
                    local c = TSBT.db.profile.media.schoolColors.frost
                    return c.r, c.g, c.b
                end,
                set   = function(_, r, g, b)
                    local c = TSBT.db.profile.media.schoolColors.frost
                    c.r, c.g, c.b = r, g, b
                end,
            },
            colorShadow = {
                type  = "color",
                name  = "Shadow",
                order = 17,
                get   = function()
                    local c = TSBT.db.profile.media.schoolColors.shadow
                    return c.r, c.g, c.b
                end,
                set   = function(_, r, g, b)
                    local c = TSBT.db.profile.media.schoolColors.shadow
                    c.r, c.g, c.b = r, g, b
                end,
            },
            colorArcane = {
                type  = "color",
                name  = "Arcane",
                order = 18,
                get   = function()
                    local c = TSBT.db.profile.media.schoolColors.arcane
                    return c.r, c.g, c.b
                end,
                set   = function(_, r, g, b)
                    local c = TSBT.db.profile.media.schoolColors.arcane
                    c.r, c.g, c.b = r, g, b
                end,
            },

            ----------------------------------------------------------------
            -- Reset Colors
            ----------------------------------------------------------------
            spacer1 = { type = "description", name = "\n", order = 19 },
            resetColors = {
                type    = "execute",
                name    = "Reset School Colors to Defaults",
                desc    = "Restore all damage school colors to their factory defaults.",
                order   = 20,
                confirm = true,
                confirmText = "Reset all damage school colors to defaults?",
                func    = function()
                    local defaults = TSBT.DEFAULTS.profile.media.schoolColors
                    local current  = TSBT.db.profile.media.schoolColors
                    for school, color in pairs(defaults) do
                        current[school] = { r = color.r, g = color.g, b = color.b }
                    end
                    Addon:Print("Damage school colors reset to defaults.")
                end,
            },
        },
    }
end

------------------------------------------------------------------------
-- Test Scroll Area Function
-- Fires 3 "TEST 12345" texts into a named scroll area with 0.3s stagger.
-- Uses C_Timer for staggered firing. Falls back to chat output if
-- the Display system isn't built yet.
------------------------------------------------------------------------
function TSBT.TestScrollArea(areaName)
    if not areaName then return end

    local area = TSBT.db and TSBT.db.profile.scrollAreas[areaName]
    if not area then
        TSBT.Addon:Print("Scroll area '" .. areaName .. "' not found.")
        return
    end

    -- Number of test texts and stagger delay
    local TEST_COUNT = 3
    local STAGGER_SECONDS = 0.3

    for i = 1, TEST_COUNT do
        -- Use C_Timer to stagger the test outputs
        C_Timer.After((i - 1) * STAGGER_SECONDS, function()
            -- If the Display system has a rendering function, use it
            if TSBT.DisplayText then
                TSBT.DisplayText(areaName, "TEST 12345", {
                    r = TSBT.COLORS.ACCENT.r,
                    g = TSBT.COLORS.ACCENT.g,
                    b = TSBT.COLORS.ACCENT.b,
                })
            else
                -- Fallback: print to chat until Display system is implemented
                TSBT.Addon:Print("|cFF4A9EFFTEST 12345|r ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ [" .. areaName .. "] (" .. i .. "/" .. TEST_COUNT .. ")")
            end
        end)
    end
end
