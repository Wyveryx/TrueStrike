------------------------------------------------------------------------
-- TrueStrike Battle Text - Scroll Area Visualization
-- Feature A: Unlock/Lock mode - draggable colored frames showing area
--            positions and sizes on screen.
-- Feature B: Test animation - fires dummy text into a scroll area.
------------------------------------------------------------------------

local ADDON_NAME, TSBT = ...
local Addon = TSBT.Addon

------------------------------------------------------------------------
-- Constants for visualization frames
------------------------------------------------------------------------

-- Color cycle for scroll area overlay frames (one per area, wraps)
local AREA_COLORS = {
    { r = 1.0, g = 0.2, b = 0.2, a = 0.3 },   -- Red
    { r = 0.2, g = 0.4, b = 1.0, a = 0.3 },   -- Blue
    { r = 0.2, g = 1.0, b = 0.2, a = 0.3 },   -- Green
    { r = 1.0, g = 1.0, b = 0.2, a = 0.3 },   -- Yellow
    { r = 0.7, g = 0.2, b = 1.0, a = 0.3 },   -- Purple
    { r = 1.0, g = 0.6, b = 0.1, a = 0.3 },   -- Orange
}

-- Border alpha is higher for visibility
local BORDER_ALPHA = 0.8

-- Storage for active visualization frames
local activeFrames = {}

-- Track unlock state
local isUnlocked = false

-- Track continuous test state
local isContinuousTesting = false
local continuousTestTimer = nil

------------------------------------------------------------------------
-- Font Resolution
--
-- Scroll areas may override the global font. This is used by the test
-- animation now and will be consumed by the runtime display engine later.
------------------------------------------------------------------------
local function ResolveFontForArea(areaName)
    local profile = TSBT.db and TSBT.db.profile
    if not profile then
        return "Fonts\\FRIZQT__.TTF", 18, "OUTLINE", 1.0
    end

    local general = (profile.general and profile.general.font) or {}
    local area = (profile.scrollAreas and profile.scrollAreas[areaName]) or nil
    local areaFont = area and area.font or nil

    local useGlobal = true
    if areaFont and areaFont.useGlobal == false then
        useGlobal = false
    end

    local faceKey    = (not useGlobal and areaFont and areaFont.face)    or general.face or "Friz Quadrata TT"
    local sizeVal    = (not useGlobal and areaFont and areaFont.size)    or general.size or 18
    local outlineKey = (not useGlobal and areaFont and areaFont.outline) or general.outline or "Thin"
    local alphaVal   = (not useGlobal and areaFont and areaFont.alpha)   or general.alpha or 1.0

    local LSM = LibStub("LibSharedMedia-3.0", true)
    local fontFace = "Fonts\\FRIZQT__.TTF" -- fallback
    if LSM and faceKey then
        local fetched = LSM:Fetch("font", faceKey)
        if fetched then fontFace = fetched end
    end

    local fontSize = tonumber(sizeVal) or 18
    local outlineFlag = TSBT.OUTLINE_STYLES[outlineKey] or "OUTLINE"
    local fontAlpha = tonumber(alphaVal) or 1.0

    return fontFace, fontSize, outlineFlag, fontAlpha
end

------------------------------------------------------------------------
-- Feature A: Unlock/Lock Mode
------------------------------------------------------------------------

------------------------------------------------------------------------
-- CreateAreaFrame: Build a single visualization frame for one scroll area
-- @param areaName  (string) Name of the scroll area
-- @param areaData  (table)  Scroll area config {xOffset, yOffset, width, height, ...}
-- @param colorIdx  (number) Index into AREA_COLORS (1-based, wraps)
-- @return frame    (Frame)  The created visualization frame
------------------------------------------------------------------------
local function CreateAreaFrame(areaName, areaData, colorIdx)
    local color = AREA_COLORS[((colorIdx - 1) % #AREA_COLORS) + 1]

    -- Create the frame anchored to screen center (UIParent CENTER)
    local frame = CreateFrame("Frame", "TSBT_AreaViz_" .. areaName, UIParent,
        "BackdropTemplate")
    frame:SetSize(areaData.width, areaData.height)
    frame:SetPoint("CENTER", UIParent, "CENTER", areaData.xOffset, areaData.yOffset)
    -- Keep frames above the config window while unlocked (new areas must be visible immediately)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(1000)

    -- Semi-transparent colored backdrop with rounded corners
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,  -- Minimum size for rounded border texture
        insets   = { left = 16, right = 16, top = 16, bottom = 16 },
    })
    frame:SetBackdropColor(color.r, color.g, color.b, color.a)
    frame:SetBackdropBorderColor(color.r, color.g, color.b, BORDER_ALPHA)

    -- Area name label (centered in frame)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER", frame, "CENTER", 0, 0)
    label:SetText(areaName)
    label:SetTextColor(1, 1, 1, 0.9)

    -- Offset readout below the name (updates during drag)
    local offsetLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    offsetLabel:SetPoint("TOP", label, "BOTTOM", 0, -4)
    offsetLabel:SetTextColor(0.8, 0.8, 0.8, 0.8)
    offsetLabel:SetText(string.format("X: %d  Y: %d", areaData.xOffset, areaData.yOffset))
    frame.offsetLabel = offsetLabel

    -- Make the frame draggable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    -- Store references for drag handler
    frame.areaName = areaName

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        -- Calculate new offset from UIParent CENTER
        local centerX = UIParent:GetWidth() / 2
        local centerY = UIParent:GetHeight() / 2
        local frameX = self:GetLeft() + (self:GetWidth() / 2)
        local frameY = self:GetBottom() + (self:GetHeight() / 2)

        local newXOffset = math.floor(frameX - centerX + 0.5)
        local newYOffset = math.floor(frameY - centerY + 0.5)

        -- Clamp to slider range
        newXOffset = math.max(TSBT.SCROLL_OFFSET_MIN,
                     math.min(TSBT.SCROLL_OFFSET_MAX, newXOffset))
        newYOffset = math.max(TSBT.SCROLL_OFFSET_MIN,
                     math.min(TSBT.SCROLL_OFFSET_MAX, newYOffset))

        -- Update the saved profile data
        local area = TSBT.db.profile.scrollAreas[self.areaName]
        if area then
            area.xOffset = newXOffset
            area.yOffset = newYOffset
        end

        -- Snap the frame to the clamped position (in case we clamped)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", newXOffset, newYOffset)

        -- Update the offset readout label immediately
        if self.offsetLabel then
            self.offsetLabel:SetText(string.format("X: %d  Y: %d",
                newXOffset, newYOffset))
        end

        -- Notify AceConfig to refresh sliders if the config dialog is open
        LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
    end)

    frame:Show()
    return frame
end

------------------------------------------------------------------------
-- ShowScrollAreaFrames: Create and display visualization frames for all
-- configured scroll areas. Called when user clicks "Unlock Scroll Areas".
------------------------------------------------------------------------
function TSBT.ShowScrollAreaFrames()
    -- Clean up any existing frames first
    TSBT.HideScrollAreaFrames()

    if not TSBT.db or not TSBT.db.profile or not TSBT.db.profile.scrollAreas then
        return
    end

    local colorIdx = 0
    for areaName, areaData in pairs(TSBT.db.profile.scrollAreas) do
        colorIdx = colorIdx + 1
        local frame = CreateAreaFrame(areaName, areaData, colorIdx)
        activeFrames[areaName] = frame
    end

    isUnlocked = true
    Addon:Print("Scroll areas unlocked. Drag to reposition.")
end

------------------------------------------------------------------------
-- RefreshScrollAreaFrames: Reconcile active visualization frames with
-- current profile scrollAreas without requiring a lock/unlock cycle.
-- Called after create/delete while unlocked.
------------------------------------------------------------------------
function TSBT.RefreshScrollAreaFrames()
    if not isUnlocked or not TSBT.db or not TSBT.db.profile or not TSBT.db.profile.scrollAreas then
        return
    end

    local areas = TSBT.db.profile.scrollAreas

    -- Remove frames that no longer exist
    for areaName, frame in pairs(activeFrames) do
        if not areas[areaName] then
            frame:Hide()
            frame:SetParent(nil)
            activeFrames[areaName] = nil
        end
    end

    -- Add frames for newly created areas
    local colorIdx = 0
    for _ in pairs(activeFrames) do colorIdx = colorIdx + 1 end

    for areaName, areaData in pairs(areas) do
        if not activeFrames[areaName] then
            colorIdx = colorIdx + 1
            activeFrames[areaName] = CreateAreaFrame(areaName, areaData, colorIdx)
        end
    end

    TSBT.UpdateScrollAreaFrames()
end

------------------------------------------------------------------------
-- UpdateScrollAreaFrames: Update all active visualization frames to match
-- current profile settings (size, position). Called when sliders are adjusted.
------------------------------------------------------------------------
function TSBT.UpdateScrollAreaFrames()
    if not isUnlocked or not TSBT.db or not TSBT.db.profile then
        return
    end

    for areaName, frame in pairs(activeFrames) do
        local areaData = TSBT.db.profile.scrollAreas[areaName]
        if areaData then
            -- Update size
            frame:SetSize(areaData.width, areaData.height)
            
            -- Update position
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", areaData.xOffset, areaData.yOffset)
            
            -- Update offset label
            if frame.offsetLabel then
                frame.offsetLabel:SetText(string.format("X: %d  Y: %d",
                    areaData.xOffset, areaData.yOffset))
            end
        end
    end
end


------------------------------------------------------------------------
-- HideScrollAreaFrames: Destroy all visualization frames.
-- Called when user clicks "Lock Scroll Areas".
------------------------------------------------------------------------
function TSBT.HideScrollAreaFrames()
    -- Stop continuous testing if active
    if isContinuousTesting then
        TSBT.StopContinuousTesting()
    end

    for areaName, frame in pairs(activeFrames) do
        frame:Hide()
        frame:SetParent(nil)  -- Release from UI hierarchy
    end
    wipe(activeFrames)

    isUnlocked = false
end

------------------------------------------------------------------------
-- IsUnlocked: Query whether scroll areas are currently in unlock mode.
-- Used by the toggle button in ConfigTabs.
------------------------------------------------------------------------
function TSBT.IsScrollAreasUnlocked()
    return isUnlocked
end

------------------------------------------------------------------------
-- Feature B: Test Animation
------------------------------------------------------------------------

------------------------------------------------------------------------
-- TestScrollArea: Fire 3 dummy text numbers into the named scroll area.
-- Uses a 0.3s delay between each. Text uses the area's animation style,
-- direction, and alignment settings from the current profile.
-- Only works when scroll areas are unlocked.
--
-- @param areaName (string) Name of scroll area to test
------------------------------------------------------------------------
function TSBT.TestScrollArea(areaName)
    if not areaName then
        Addon:Print("No scroll area selected for test.")
        return
    end

    -- Require scroll areas to be unlocked
    if not isUnlocked then
        Addon:Print("Scroll areas must be unlocked to test. Click 'Unlock Scroll Areas' first.")
        return
    end

    local area = TSBT.db and TSBT.db.profile
                  and TSBT.db.profile.scrollAreas
                  and TSBT.db.profile.scrollAreas[areaName]
    if not area then
        Addon:Print("Scroll area '" .. areaName .. "' not found.")
        return
    end

    local fontFace, fontSize, outlineFlag, fontAlpha = ResolveFontForArea(areaName)

    -- Determine alignment anchor point
    local alignmentMap = {
        ["Left"]   = "LEFT",
        ["Center"] = "CENTER",
        ["Right"]  = "RIGHT",
    }
    local anchorH = alignmentMap[area.alignment] or "CENTER"

    -- Determine scroll direction multiplier (Up = positive Y, Down = negative)
    local dirMult = (area.direction == "Down") and -1 or 1

    -- Animation duration base (modified by animSpeed)
    local baseDuration = 2.0   -- seconds for full scroll
    local duration = baseDuration / (area.animSpeed or 1.0)

    -- Mock event templates (same variety as continuous test)
    local mockEvents = {
        "Fireball 1523",
        "Pyroblast 2841",
        "Heal +842",
    }

    for i, text in ipairs(mockEvents) do
        -- Use C_Timer.After for staggered firing (0.0, 0.3, 0.6 seconds)
        C_Timer.After((i - 1) * 0.3, function()
            TSBT.FireTestText(text, area, fontFace, fontSize, outlineFlag,
                              fontAlpha, anchorH, dirMult, duration)
        end)
    end
end

------------------------------------------------------------------------
-- TestAllScrollAreas: Fire test events into ALL unlocked scroll areas.
-- Only fires into areas that are currently unlocked (visualization frames shown).
-- Uses a variety of mock events: damage, healing, and notifications.
-- Each area gets 3 events with 0.3s stagger, respecting each area's
-- individual animation settings.
-- Internal function - called once per test cycle.
------------------------------------------------------------------------
local function FireAllAreasOnce()
    -- Mock event templates (mix of damage, healing, notifications)
    local mockEvents = {
        { text = "Fireball 1523",      type = "damage" },
        { text = "Heal +842",           type = "healing" },
        { text = "Wind Shear Ready!",   type = "notification" },
        { text = "Pyroblast 2841",      type = "damage" },
        { text = "Rejuvenation +234",   type = "healing" },
    }

    -- Fire test events into each unlocked area
    for areaName, _ in pairs(activeFrames) do
        local area = TSBT.db and TSBT.db.profile
                      and TSBT.db.profile.scrollAreas
                      and TSBT.db.profile.scrollAreas[areaName]
        
        if area then
            local fontFace, fontSize, outlineFlag, fontAlpha = ResolveFontForArea(areaName)

            -- Determine alignment anchor point
            local alignmentMap = {
                ["Left"]   = "LEFT",
                ["Center"] = "CENTER",
                ["Right"]  = "RIGHT",
            }
            local anchorH = alignmentMap[area.alignment] or "CENTER"

            -- Determine scroll direction multiplier
            local dirMult = (area.direction == "Down") and -1 or 1

            -- Animation duration
            local baseDuration = 2.0
            local duration = baseDuration / (area.animSpeed or 1.0)

            -- Fire 3 mock events with stagger
            for i = 1, 3 do
                local mockEvent = mockEvents[((i - 1) % #mockEvents) + 1]
                
                C_Timer.After((i - 1) * 0.3, function()
                    TSBT.FireTestText(mockEvent.text, area, fontFace, fontSize,
                                      outlineFlag, fontAlpha, anchorH, dirMult, duration)
                end)
            end
        end
    end
end

------------------------------------------------------------------------
-- StartContinuousTesting: Start continuous test animation loop
------------------------------------------------------------------------
function TSBT.StartContinuousTesting()
    -- Check if any areas are unlocked
    local hasUnlockedAreas = false
    for areaName, _ in pairs(activeFrames) do
        hasUnlockedAreas = true
        break
    end

    if not hasUnlockedAreas then
        Addon:Print("No scroll areas are unlocked. Use 'Unlock Scroll Areas' first.")
        return
    end

    if isContinuousTesting then
        -- Already running
        return
    end

    isContinuousTesting = true
    Addon:Print("Continuous testing started. Animations will repeat every 3 seconds.")

    -- Fire immediately
    FireAllAreasOnce()

    -- Set up repeating timer (3 second interval to allow animations to complete)
    local function RepeatTest()
        if not isContinuousTesting then
            return
        end
        
        FireAllAreasOnce()
        
        -- Schedule next iteration
        continuousTestTimer = C_Timer.After(3.0, RepeatTest)
    end

    -- Schedule first repeat
    continuousTestTimer = C_Timer.After(3.0, RepeatTest)
    
    -- Notify AceConfig to update button name
    LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
end

------------------------------------------------------------------------
-- StopContinuousTesting: Stop continuous test animation loop
------------------------------------------------------------------------
function TSBT.StopContinuousTesting()
    if not isContinuousTesting then
        return
    end

    isContinuousTesting = false
    
    -- Cancel pending timer if any
    if continuousTestTimer then
        continuousTestTimer = nil
    end

    Addon:Print("Continuous testing stopped.")
    
    -- Notify AceConfig to update button name
    LibStub("AceConfigRegistry-3.0"):NotifyChange("TrueStrike")
end

------------------------------------------------------------------------
-- IsContinuousTesting: Query whether continuous testing is active
------------------------------------------------------------------------
function TSBT.IsContinuousTesting()
    return isContinuousTesting
end

------------------------------------------------------------------------
-- FireTestText: Create and animate a single test text FontString.
-- This is a standalone test display, independent of the future
-- Display.lua pooling system.
--
-- @param text         (string) Text to display
-- @param area         (table)  Scroll area config
-- @param fontFace     (string) Font file path
-- @param fontSize     (number) Font size
-- @param outlineFlag  (string) WoW outline flag ("", "OUTLINE", etc.)
-- @param fontAlpha    (number) Starting alpha (0-1)
-- @param anchorH      (string) Horizontal anchor ("LEFT","CENTER","RIGHT")
-- @param dirMult      (number) Direction multiplier (+1 up, -1 down)
-- @param duration     (number) Animation duration in seconds
------------------------------------------------------------------------
-- @param color        (table|nil) Optional {r,g,b,a} text color. If nil,
--                      uses TSBT.COLORS.ACCENT.
function TSBT.FireTestText(text, area, fontFace, fontSize, outlineFlag,
                           fontAlpha, anchorH, dirMult, duration, color)
    -- Create a unique parent frame for this scroll area based on its position
    -- This allows multiple areas to be tested simultaneously without interference
    local parentKey = string.format("test_%.0f_%.0f", area.xOffset, area.yOffset)
    
    if not TSBT._testParentFrames then
        TSBT._testParentFrames = {}
    end
    
    local parent = TSBT._testParentFrames[parentKey]
    if not parent then
        parent = CreateFrame("Frame", "TSBT_TestParent_" .. parentKey, UIParent)
        parent:SetFrameStrata("HIGH")
        TSBT._testParentFrames[parentKey] = parent
    end
    
    -- Position and size the parent for this area
    parent:ClearAllPoints()
    parent:SetSize(area.width, area.height)
    parent:SetPoint("CENTER", UIParent, "CENTER", area.xOffset, area.yOffset)
    parent:Show()

    -- Create the FontString
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(fontFace, fontSize, outlineFlag)
    fs:SetText(text)
    fs:SetAlpha(fontAlpha)

    -- Use caller-provided color when available; otherwise accent.
    local c = color or TSBT.COLORS.ACCENT
    fs:SetTextColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1.0)

    -- Starting position: bottom of area if scrolling up, top if scrolling down
    local startAnchorV = (dirMult > 0) and "BOTTOM" or "TOP"
    local startPoint = startAnchorV .. (anchorH ~= "CENTER" and anchorH or "")
    -- Normalize point name: "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT", etc.
    if anchorH == "CENTER" then
        startPoint = startAnchorV
    end

    fs:SetPoint(startPoint, parent, startPoint, 0, 0)

    -- Animation: scroll the text across the area height over `duration` seconds
    local totalDistance = area.height
    local elapsed = 0
    local animStyle = area.animation or "Straight"

    -- Use OnUpdate for animation
    local animFrame = CreateFrame("Frame")
    animFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt

        local progress = elapsed / duration
        if progress >= 1.0 then
            -- Animation complete: clean up
            fs:Hide()
            fs:SetParent(nil)
            self:SetScript("OnUpdate", nil)
            return
        end

        -- Vertical position based on animation style
        local yOffset = 0
        local xOffset = 0

        if animStyle == "Straight" or animStyle == "straight" then
            -- Linear scroll
            yOffset = totalDistance * progress * dirMult

        elseif animStyle == "Parabola" or animStyle == "parabola" then
            -- Parabolic arc: vertical is linear, horizontal follows a parabola
            yOffset = totalDistance * progress * dirMult
            -- Horizontal arc: peaks at midpoint, returns to 0
            -- Uses sin curve for smooth parabolic feel
            local arcWidth = area.width * 0.3  -- 30% of area width for arc
            xOffset = math.sin(progress * math.pi) * arcWidth

        elseif animStyle == "Static" or animStyle == "static" then
            -- No movement, just fade in then fade out
            yOffset = 0
        end

        -- Apply position offset from starting point
        fs:ClearAllPoints()
        fs:SetPoint(startPoint, parent, startPoint, xOffset, yOffset)

        -- Alpha fade: full opacity for first 60%, then fade out
        local alpha = fontAlpha
        if animStyle == "Static" or animStyle == "static" then
            -- Static: fade in 0-10%, hold 10-70%, fade out 70-100%
            if progress < 0.1 then
                alpha = fontAlpha * (progress / 0.1)
            elseif progress > 0.7 then
                alpha = fontAlpha * (1.0 - ((progress - 0.7) / 0.3))
            end
        else
            -- Scrolling styles: hold 0-60%, fade out 60-100%
            if progress > 0.6 then
                alpha = fontAlpha * (1.0 - ((progress - 0.6) / 0.4))
            end
        end
        fs:SetAlpha(math.max(0, alpha))
    end)
end
