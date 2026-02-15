------------------------------------------------------------------------
-- TrueStrike Battle Text - Configuration UI
-- Builds the master AceConfig-3.0 options table with all 8 tabs.
-- Each tab is constructed in ConfigTabs.lua and assembled here.
------------------------------------------------------------------------

local ADDON_NAME, TSBT = ...
local Addon = TSBT.Addon
local LSM = LibStub("LibSharedMedia-3.0")

------------------------------------------------------------------------
-- Helper: Build a dropdown values table from a key/value table
------------------------------------------------------------------------
function TSBT.ValuesFromKeys(tbl)
    local out = {}
    for k, _ in pairs(tbl) do
        out[k] = k
    end
    return out
end

------------------------------------------------------------------------
-- Helper: Get available scroll area names from current profile
------------------------------------------------------------------------
function TSBT.GetScrollAreaNames()
    local names = {}
    if TSBT.db and TSBT.db.profile and TSBT.db.profile.scrollAreas then
        for name, _ in pairs(TSBT.db.profile.scrollAreas) do
            names[name] = name
        end
    end
    return names
end

------------------------------------------------------------------------
-- Helper: Build font dropdown values from LibSharedMedia
-- Returns a table suitable for AceConfig select "values".
-- Uses standard select type â€” no LSM30_Font widget required.
------------------------------------------------------------------------
function TSBT.BuildFontDropdown()
    local fonts = {}
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            fonts[name] = name
        end
    end
    -- Ensure default WoW font is always present
    if not fonts["Friz Quadrata TT"] then
        fonts["Friz Quadrata TT"] = "Friz Quadrata TT"
    end
    return fonts
end

------------------------------------------------------------------------
-- Helper: Build sound dropdown values from LibSharedMedia
-- Returns a table suitable for AceConfig select "values".
-- Uses standard select type â€” no LSM30_Sound widget required.
-- Always includes a "None" option at the top.
------------------------------------------------------------------------
function TSBT.BuildSoundDropdown()
    local sounds = { ["None"] = "None" }
    if LSM then
        for _, name in ipairs(LSM:List("sound")) do
            sounds[name] = name
        end
    end
    return sounds
end

------------------------------------------------------------------------
-- Helper: Play an LSM sound by key name
-- Used by "Test" buttons next to sound dropdowns.
------------------------------------------------------------------------
function TSBT.PlayLSMSound(soundKey)
    if not soundKey or soundKey == "None" then return end
    if not LSM then return end
    local path = LSM:Fetch("sound", soundKey)
    if path then
        PlaySoundFile(path, "Master")
    end
end

------------------------------------------------------------------------
-- Build the complete options table
-- Called once during OnInitialize.
-- Profiles tab is injected by Init.lua after DB creation.
------------------------------------------------------------------------
function TSBT.BuildOptionsTable()
    -- Ensure ConfigTabs has been loaded
    assert(TSBT.BuildTab_General, "ConfigTabs.lua must be loaded before Config.lua")

    local options = {
        type = "group",
        name = "|cFF4A9EFF\226\154\148|r TrueStrike Configuration",
        childGroups = "tab",
        args = {
            ----------------------------------------------------------------
            -- Tab 1: General
            ----------------------------------------------------------------
            general = TSBT.BuildTab_General(),

            ----------------------------------------------------------------
            -- Tab 2: Scroll Areas
            ----------------------------------------------------------------
            scrollAreas = TSBT.BuildTab_ScrollAreas(),

            ----------------------------------------------------------------
            -- Tab 3: Incoming
            ----------------------------------------------------------------
            incoming = TSBT.BuildTab_Incoming(),

            ----------------------------------------------------------------
            -- Tab 4: Outgoing
            ----------------------------------------------------------------
            outgoing = TSBT.BuildTab_Outgoing(),

            ----------------------------------------------------------------
            -- Tab 5: Pets
            ----------------------------------------------------------------
            pets = TSBT.BuildTab_Pets(),

            ----------------------------------------------------------------
            -- Tab 6: Spam Control
            ----------------------------------------------------------------
            spamControl = TSBT.BuildTab_SpamControl(),

            ----------------------------------------------------------------
            -- Tab 7: Cooldowns
            ----------------------------------------------------------------
            cooldowns = TSBT.BuildTab_Cooldowns(),

            ----------------------------------------------------------------
            -- Tab 8: Media
            ----------------------------------------------------------------
            media = TSBT.BuildTab_Media(),

            ----------------------------------------------------------------
            -- Profiles tab placeholder (injected by Init.lua after DB init)
            ----------------------------------------------------------------
        },
    }

    return options
end

------------------------------------------------------------------------
-- Strike Silver Styling
-- Hooks into AceConfigDialog:Open to apply custom backdrop and colors
-- to the configuration window after it's created by Ace3.
--
-- Design targets:
--   Background: Dark gunmetal (#1F2938), 95% opacity
--   Borders:    Chrome silver (#8B98A8), 2-3px, consistent everywhere
--   Active tab: Electric Blue (#4A9EFF)
--   Inactive:   Light Silver (#C0C0C0)
------------------------------------------------------------------------

-- Track whether we've already hooked (prevent double-hooking)
local strikeSilverHooked = false

-- Border sizes for rounded vs sharp borders
local BORDER_SIZE_SHARP = 2
local BORDER_SIZE_ROUNDED = 20  -- Thicker border with better rounding visibility
local BORDER_INSET = 3         -- No gap between blue frame and border

function TSBT.ApplyStrikeSilverStyling()
    if strikeSilverHooked then return end
    strikeSilverHooked = true

    local ACD = LibStub("AceConfigDialog-3.0", true)
    if not ACD then return end

    -- Hook Open so we can style the frame each time it appears
    hooksecurefunc(ACD, "Open", function(self, appName)
        if appName ~= "TrueStrike" then return end

        -- AceConfigDialog stores open frames in self.OpenFrames[appName]
        local frame = self.OpenFrames[appName]
        if not frame or not frame.frame then return end

        local f = frame.frame  -- The actual WoW frame widget
        local dk = TSBT.COLORS.DARK
        local border = TSBT.COLORS.BORDER

        -- Apply Strike Silver backdrop to main frame
        if not f.tsbtStyled then
            -- Ensure frame supports backdrops
            if not f.SetBackdrop then
                Mixin(f, BackdropTemplateMixin)
            end

            f:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = BORDER_SIZE_ROUNDED,
                insets   = { left = BORDER_INSET, right = BORDER_INSET, 
                             top = BORDER_INSET, bottom = BORDER_INSET },
            })

            -- Frame background: Dark gunmetal
            f:SetBackdropColor(dk.r, dk.g, dk.b, 0.95)

            -- Border: Chrome silver â€” visible on dark background
            f:SetBackdropBorderColor(border.r, border.g, border.b, 1.0)

            -- Style the title bar text if present
            local titleRegion = f.GetTitleRegion and f:GetTitleRegion()
            if not titleRegion then
                -- AceConfigDialog title is typically a FontString child
                for _, region in pairs({ f:GetRegions() }) do
                    if region:IsObjectType("FontString") then
                        local text = region:GetText()
                        if text and text:find("TrueStrike") then
                            region:SetTextColor(TSBT.COLORS.TEXT_LIGHT.r,
                                                TSBT.COLORS.TEXT_LIGHT.g,
                                                TSBT.COLORS.TEXT_LIGHT.b, 1.0)
                        end
                    end
                end
            end

            f.tsbtStyled = true
        end

        -- Style the tab buttons each time Open fires
        TSBT.StyleTabButtons(frame)

        -- Style inner content containers (section borders, tab bar, etc.)
        TSBT.StyleInnerContainers(frame)

        -- Ensure the Cooldowns drag/drop overlay is ONLY visible on the Cooldowns tab.
        if TSBT.HookCooldownOverlayTabSwitch then
            TSBT.HookCooldownOverlayTabSwitch(frame)
        end

        -- Keep confirmation popups above the AceConfig window.
        if TSBT.EnsurePopupsOnTop then
            TSBT.EnsurePopupsOnTop(f)
        end
    end)
end

------------------------------------------------------------------------
-- Style tab buttons with Strike Silver colors
-- Finds the AceGUI TabGroup child and applies accent color to active tab.
------------------------------------------------------------------------
function TSBT.StyleTabButtons(aceFrame)
    if not aceFrame then return end

    -- The AceGUI Frame widget has children; the first is typically the TabGroup
    local tabGroup = nil
    if aceFrame.children then
        for _, child in ipairs(aceFrame.children) do
            if child.type == "TabGroup" then
                tabGroup = child
                break
            end
        end
    end

    if not tabGroup or not tabGroup.tabs then return end

    local accent = TSBT.COLORS.ACCENT
    local tabInactive = TSBT.COLORS.TAB_INACTIVE
    local border = TSBT.COLORS.BORDER

    -- Style tab button backgrounds and text
    for _, tab in ipairs(tabGroup.tabs) do
        if tab and tab.GetFontString then
            local fs = tab:GetFontString()
            if fs then
                -- Default: Pure white for readability on dark background
                fs:SetTextColor(tabInactive.r, tabInactive.g, tabInactive.b, 1.0)
            end
        end
    end

    -- Hook tab selection to recolor active tab with accent
    if not tabGroup.tsbtTabHooked then
        tabGroup.tsbtTabHooked = true

        hooksecurefunc(tabGroup, "SelectTab", function(self, tabValue)
            if not self.tabs then return end
            for _, tab in ipairs(self.tabs) do
                local fs = tab:GetFontString()
                if fs then
                    if tab.value == tabValue then
                        -- Active tab: Electric Blue accent
                        fs:SetTextColor(accent.r, accent.g, accent.b, 1.0)
                    else
                        -- Inactive tab: Pure white (#FFFFFF) - full opacity
                        fs:SetTextColor(tabInactive.r, tabInactive.g, tabInactive.b, 1.0)
                    end
                end
            end
        end)
    end

    -- Style the tab bar container backdrop if the border frame exists
    if tabGroup.border then
        local tabBorder = tabGroup.border
        if not tabBorder.SetBackdrop then
            Mixin(tabBorder, BackdropTemplateMixin)
        end
        tabBorder:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = BORDER_SIZE_ROUNDED,
            insets   = { left = BORDER_INSET, right = BORDER_INSET, 
                         top = BORDER_INSET, bottom = BORDER_INSET },
        })
        local dk = TSBT.COLORS.DARK
        tabBorder:SetBackdropColor(dk.r, dk.g, dk.b, 0.8)
        tabBorder:SetBackdropBorderColor(border.r, border.g, border.b, 1.0)
    end
end

------------------------------------------------------------------------
-- Style inner containers: section borders, scrollable content areas
-- Recursively walks AceGUI children to find InlineGroup/BlizOptionsGroup
-- and applies consistent chrome borders.
------------------------------------------------------------------------
function TSBT.StyleInnerContainers(aceFrame)
    if not aceFrame or not aceFrame.children then return end

    local dk = TSBT.COLORS.DARK
    local border = TSBT.COLORS.BORDER

    local function styleChild(widget)
        -- InlineGroup and similar containers have a .border frame
        if widget.border then
            local b = widget.border
            if not b.tsbtStyled then
                if not b.SetBackdrop then
                    Mixin(b, BackdropTemplateMixin)
                end
                b:SetBackdrop({
                    bgFile   = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = BORDER_SIZE_ROUNDED,
                    insets   = { left = BORDER_INSET, right = BORDER_INSET, 
                                 top = BORDER_INSET, bottom = BORDER_INSET },
                })
                -- Slightly lighter than main background for depth
                b:SetBackdropColor(dk.r * 1.15, dk.g * 1.15, dk.b * 1.15, 0.9)
                b:SetBackdropBorderColor(border.r, border.g, border.b, 1.0)
                b.tsbtStyled = true
            end
        end

        -- Recurse into children
        if widget.children then
            for _, child in ipairs(widget.children) do
                styleChild(child)
            end
        end
    end

    for _, child in ipairs(aceFrame.children) do
        styleChild(child)
    end
end

------------------------------------------------------------------------
-- Popup / Z-Order Safety
-- Ensure StaticPopup confirmations don't hide behind the AceConfig frame.
------------------------------------------------------------------------

local popupsOnTopHooked = false

local function RaiseStaticPopupFrame(popupFrame, anchorFrame)
    if not popupFrame then return end
    popupFrame:SetFrameStrata("FULLSCREEN_DIALOG")

    local baseLevel = 0
    if anchorFrame and anchorFrame.GetFrameLevel then
        baseLevel = anchorFrame:GetFrameLevel() or 0
    end
    popupFrame:SetFrameLevel(baseLevel + 200)

    if popupFrame.SetToplevel then
        popupFrame:SetToplevel(true)
    end
end

function TSBT.EnsurePopupsOnTop(anchorFrame)
    if popupsOnTopHooked then return end
    popupsOnTopHooked = true

    if not StaticPopup_Show then return end

    hooksecurefunc("StaticPopup_Show", function()
        for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
            local f = _G["StaticPopup" .. i]
            if f and f:IsShown() then
                RaiseStaticPopupFrame(f, anchorFrame)
            end
        end
    end)
end

------------------------------------------------------------------------
-- Cooldown Overlay Visibility Control
-- The overlay is parented to the TabGroup content frame, so we must
-- explicitly hide it when the user is not on the Cooldowns tab.
------------------------------------------------------------------------

TSBT.UI = TSBT.UI or {}

function TSBT.SetCooldownOverlayVisible(isVisible)
    local o = TSBT.UI and TSBT.UI.CooldownDropOverlay
    if not o then return end
    if isVisible then
        o:Show()
    else
        o:Hide()
    end
end

local cooldownOverlayTabHooked = false

function TSBT.HookCooldownOverlayTabSwitch(aceFrame)
    if cooldownOverlayTabHooked then return end
    if not aceFrame or not aceFrame.children then return end

    local tabGroup
    for _, child in ipairs(aceFrame.children) do
        if child.type == "TabGroup" then
            tabGroup = child
            break
        end
    end
    if not tabGroup then return end
    cooldownOverlayTabHooked = true

    local function update(selected)
        TSBT.SetCooldownOverlayVisible(selected == "cooldowns")
    end

    if tabGroup.SelectTab then
        hooksecurefunc(tabGroup, "SelectTab", function(_, group)
            update(group)
        end)
    end

    local selected = tabGroup.status and tabGroup.status.selected
    update(selected)
end

------------------------------------------------------------------------
-- Cooldown Drop Overlay
-- Creates a high-strata overlay frame that's parented to the tab content
-- and positioned to overlay the "Drag Spell Here" description text.
------------------------------------------------------------------------

local cooldownDropOverlay = nil

function TSBT.CreateCooldownDropOverlay()
    local ACD = LibStub("AceConfigDialog-3.0", true)
    if not ACD then return end
    
    -- Find the TrueStrike config frame
    local configFrame = ACD.OpenFrames["TrueStrike"]
    if not configFrame or not configFrame.frame then return end
    
    -- Get the TabGroup and its content frame (where the actual options are displayed)
    local tabGroup = nil
    local contentFrame = nil
    if configFrame.children then
        for _, child in ipairs(configFrame.children) do
            if child.type == "TabGroup" then
                tabGroup = child
                contentFrame = child.content
                break
            end
        end
    end
    
    if not contentFrame then return end
    
    -- Create overlay if it doesn't exist
    if not cooldownDropOverlay then
        local accent = TSBT.COLORS.ACCENT
        local dk = TSBT.COLORS.DARK
        
        cooldownDropOverlay = CreateFrame("Frame", "TSBT_CooldownDropOverlay", contentFrame, "BackdropTemplate")
        cooldownDropOverlay:SetSize(520, 70)
        cooldownDropOverlay:EnableMouse(true)
        
        -- CRITICAL: Set frame strata and level HIGHER than parent
        cooldownDropOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
        cooldownDropOverlay:SetFrameLevel(contentFrame:GetFrameLevel() + 100)
        
        -- Backdrop styling
        cooldownDropOverlay:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 2,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        cooldownDropOverlay:SetBackdropColor(dk.r * 1.2, dk.g * 1.2, dk.b * 1.2, 0.95)
        cooldownDropOverlay:SetBackdropBorderColor(accent.r, accent.g, accent.b, 0.9)
        
        -- Icon placeholder
        local iconBg = cooldownDropOverlay:CreateTexture(nil, "ARTWORK")
        iconBg:SetSize(36, 36)
        iconBg:SetPoint("LEFT", cooldownDropOverlay, "LEFT", 14, 0)
        iconBg:SetColorTexture(0.15, 0.15, 0.15, 1.0)
        
        -- Icon overlay (shows after drop)
        local iconOverlay = cooldownDropOverlay:CreateTexture(nil, "OVERLAY")
        iconOverlay:SetSize(34, 34)
        iconOverlay:SetPoint("CENTER", iconBg, "CENTER", 0, 0)
        iconOverlay:Hide()
        cooldownDropOverlay.iconOverlay = iconOverlay
        
        -- Main text
        local mainText = cooldownDropOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        mainText:SetPoint("LEFT", iconBg, "RIGHT", 15, 8)
        mainText:SetJustifyH("LEFT")
        mainText:SetText("|cFF4A9EFF[ Drag Spell Here ]|r")
        cooldownDropOverlay.mainText = mainText
        
        -- Subtext
        local subText = cooldownDropOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        subText:SetPoint("TOPLEFT", mainText, "BOTTOMLEFT", 0, -3)
        subText:SetJustifyH("LEFT")
        subText:SetText("|cFF888888Drag from spellbook or action bar|r")
        
        -- Hover highlight
        local highlight = cooldownDropOverlay:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(accent.r, accent.g, accent.b, 0.15)
		
        
        -- Drag handlers
        cooldownDropOverlay:SetScript("OnReceiveDrag", function(self)
            local cursorType, id, subType = GetCursorInfo()
            
            if cursorType == "spell" then
                -- Resolve spell ID based on drag source
                local spellID = nil
                if subType == "spell" or subType == "pet" then
                    -- Spellbook drag: resolve slot index to spell ID
                    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
                        local bookType = (subType == "pet") and Enum.SpellBookSpellBank.Pet 
                                                              or Enum.SpellBookSpellBank.Player
                        local spellInfo = C_SpellBook.GetSpellBookItemInfo(id, bookType)
                        if spellInfo and spellInfo.spellID then
                            spellID = spellInfo.spellID
                        end
                    end
                else
                    -- Action bar drag: id is already spell ID
                    spellID = id
                end
                
                if spellID and spellID > 0 then
                    -- Add to tracking
                    if not TSBT.db.profile.cooldowns.tracked[spellID] then
                        TSBT.db.profile.cooldowns.tracked[spellID] = true
                        
                        -- Get spell info
                        local name, icon
                        if C_Spell and C_Spell.GetSpellInfo then
                            local info = C_Spell.GetSpellInfo(spellID)
                            if info then
                                name = info.name
                                icon = info.iconID
                            end
                        end
                        
                        -- Visual feedback
                        if icon and self.iconOverlay then
                            self.iconOverlay:SetTexture(icon)
                            self.iconOverlay:Show()
                        end
                        if self.mainText then
                            self.mainText:SetText("|cFF00FF00Added!|r")
                        end
                        
                        -- Reset after 2 seconds
                        C_Timer.After(2.0, function()
                            if self.mainText then
                                self.mainText:SetText("|cFF4A9EFF[ Drag Spell Here ]|r")
                            end
                            if self.iconOverlay then
                                self.iconOverlay:Hide()
                            end
                        end)
                        
                        local displayName = name and (name .. " (ID: " .. spellID .. ")") or ("Spell ID: " .. spellID)
                        TSBT.Addon:Print("Now tracking: " .. displayName)
                        
                        -- Refresh UI
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                    else
                        TSBT.Addon:Print("Spell ID " .. spellID .. " is already being tracked.")
                    end
                else
                    TSBT.Addon:Print("Could not resolve spell ID. Try dragging from action bar.")
                end
                ClearCursor()
            elseif cursorType == "petaction" then
                ClearCursor()
                TSBT.Addon:Print("Pet abilities cannot be tracked.")
            elseif cursorType == "item" then
                -- Item drag: store as string key to avoid ID collisions with spells
                local itemID = id
                if itemID and itemID > 0 then
                    local key = "item:" .. itemID
                    if not TSBT.db.profile.cooldowns.tracked[key] then
                        TSBT.db.profile.cooldowns.tracked[key] = true

                        -- Get item info (may be nil if not cached yet)
                        local name, icon
                        if C_Item and C_Item.GetItemInfo then
                            name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
                        end

                        -- Visual feedback
                        if icon and self.iconOverlay then
                            self.iconOverlay:SetTexture(icon)
                            self.iconOverlay:Show()
                        end
                        if self.mainText then
                            self.mainText:SetText("|cFF00FF00Added!|r")
                        end

                        -- Reset after 2 seconds
                        C_Timer.After(2.0, function()
                            if self.mainText then
                                self.mainText:SetText("|cFF4A9EFF[ Drag Spell Here ]|r")
                            end
                            if self.iconOverlay then
                                self.iconOverlay:Hide()
                            end
                        end)

                        local displayName = name and (name .. " (Item ID: " .. itemID .. ")") or ("Item ID: " .. itemID)
                        TSBT.Addon:Print("Now tracking: " .. displayName)

                        -- Refresh UI
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
                    else
                        TSBT.Addon:Print("Item ID " .. itemID .. " is already being tracked.")
                    end
                end
                ClearCursor()
            else
                ClearCursor()
            end
        end)
        
        cooldownDropOverlay:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                local cursorType, id = GetCursorInfo()
                if (cursorType == "spell" or cursorType == "item") and id and id > 0 then
                    -- Trigger the same logic as OnReceiveDrag
                    self:GetScript("OnReceiveDrag")(self)
                end
            end
        end)
    end

    -- Expose a stable reference for tab switching control
    TSBT.UI.CooldownDropOverlay = cooldownDropOverlay
    
    -- Position the overlay: Should appear below "Tracked Spells" header
    -- Approximate Y offset from top of content area
    cooldownDropOverlay:ClearAllPoints()
    cooldownDropOverlay:SetPoint("TOP", contentFrame, "TOP", 0, -180)
	
    
    -- Default to hidden; tab hook (or this function) will show only on "cooldowns".
    TSBT.SetCooldownOverlayVisible(false)

    local selected = tabGroup and tabGroup.status and tabGroup.status.selected
    TSBT.SetCooldownOverlayVisible(selected == "cooldowns")
end

function TSBT.HideCooldownDropOverlay()
    if cooldownDropOverlay then
        cooldownDropOverlay:Hide()
    end
end
