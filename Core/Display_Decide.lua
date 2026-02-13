------------------------------------------------------------------------
-- TrueStrike - Display Decision Layer
-- Responsibility: accept "emit requests" and route to the active render
-- system.
--
-- For now (UI/UX harness phase): use ScrollAreaFrames.lua test renderer
-- (TSBT.FireTestText) as the common animation sink.
------------------------------------------------------------------------

local ADDON_NAME, TSBT = ...

TSBT.Core = TSBT.Core or {}
TSBT.Core.Display = TSBT.Core.Display or {}
local Display = TSBT.Core.Display
local Addon   = TSBT.Addon

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
    local outlineFlag = TSBT.OUTLINE_STYLES and TSBT.OUTLINE_STYLES[outlineKey] or "OUTLINE"
    local fontAlpha = tonumber(alphaVal) or 1.0

    return fontFace, fontSize, outlineFlag, fontAlpha
end

function Display:Enable()
    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(1, "Display:Enable()")
    end
end

function Display:Disable()
    if Addon and Addon.DebugPrint then
        Addon:DebugPrint(1, "Display:Disable()")
    end
end

-- Primary contract: engine calls this to request output.
function Display:Emit(areaName, text, color, meta)
    -- Global gating (Enable TrueStrike + Combat Only Mode)
    if TSBT.Core and TSBT.Core.ShouldEmitNow and not TSBT.Core:ShouldEmitNow() then
        return
    end

    if not (areaName and text) then
        return
    end

    local profile = TSBT.db and TSBT.db.profile
    local area = profile and profile.scrollAreas and profile.scrollAreas[areaName] or nil
    if not area then
        -- Safe fallback: chat-only when a scroll area is missing
        if Addon and Addon.Print then
            Addon:Print(("%s [%s]"):format(text, areaName))
        end
        return
    end

    -- Require the test renderer (ScrollAreaFrames.lua)
    if type(TSBT.FireTestText) ~= "function" then
        if Addon and Addon.Print then
            Addon:Print(("%s [%s]"):format(text, areaName))
        end
        return
    end

    local fontFace, fontSize, outlineFlag, fontAlpha = ResolveFontForArea(areaName)
    local anchorH = (area.alignment == "Left" and "LEFT") or (area.alignment == "Right" and "RIGHT") or "CENTER"
    local dirMult = (area.direction == "Down") and -1 or 1
    local speed = tonumber(area.animSpeed) or 1.0
    if speed <= 0 then speed = 1.0 end
    local duration = 1.2 / speed

    TSBT.FireTestText(text, area, fontFace, fontSize, outlineFlag, fontAlpha,
        anchorH, dirMult, duration, color)
end

-- Backward-compat contract
if TSBT.DisplayText == nil then
    function TSBT.DisplayText(areaName, text, color, meta)
        return Display:Emit(areaName, text, color, meta)
    end
end
