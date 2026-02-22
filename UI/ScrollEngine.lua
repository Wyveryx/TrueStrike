-- TrueStrike Scroll Engine
-- Runtime scroll area frames and lightweight animation for test entries.

local _, ns = ...
local TrueStrike = ns.TrueStrike

local floor = math.floor
local random = math.random
local sin = math.sin

local DURATION = 1.4

local function clamp(v, minv, maxv)
  if v < minv then return minv end
  if v > maxv then return maxv end
  return v
end

function TrueStrike:InitializeScrollEngine()
  self.areaFrames = self.areaFrames or {}
  self:CreateAreaFrames()
  self:RefreshAreaFrames()
end

function TrueStrike:CreateAreaFrames()
  for i = 1, 3 do
    if not self.areaFrames[i] then
      local frame = CreateFrame("Frame", "TrueStrikeScrollArea" .. i, UIParent, "BackdropTemplate")
      frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
      })
      frame:SetBackdropColor(0.03, 0.04, 0.07, 0.35)
      frame:SetBackdropBorderColor(0.2, 0.7, 1, 0.5)
      frame:SetClipsChildren(true)
      frame:SetMovable(true)
      frame.activeEntries = {}

      frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      frame.label:SetPoint("TOP", 0, -6)

      frame.handle = CreateFrame("Button", nil, frame, "BackdropTemplate")
      frame.handle:SetSize(20, 20)
      frame.handle:SetPoint("TOPLEFT", 2, -2)
      frame.handle:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
      frame.handle:SetBackdropColor(0.1, 0.7, 1, 0.6)
      frame.handle:RegisterForDrag("LeftButton")
      frame.handle:SetScript("OnDragStart", function()
        if self.db.profile.scrollAreas.unlocked then
          frame:StartMoving()
        end
      end)
      frame.handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SaveAreaFramePosition(i)
      end)

      frame.resizer = CreateFrame("Button", nil, frame, "BackdropTemplate")
      frame.resizer:SetSize(18, 18)
      frame.resizer:SetPoint("BOTTOMRIGHT", -1, 1)
      frame.resizer:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
      frame.resizer:SetBackdropColor(1, 0.6, 0.2, 0.8)
      frame.resizer:RegisterForDrag("LeftButton")
      frame.resizer:SetScript("OnDragStart", function()
        if self.db.profile.scrollAreas.unlocked then
          frame:StartSizing("BOTTOMRIGHT")
        end
      end)
      frame.resizer:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SaveAreaFrameSize(i)
      end)

      frame:SetScript("OnUpdate", function(_, elapsed)
        self:UpdateAreaEntries(frame, i, elapsed)
      end)

      self.areaFrames[i] = frame
    end
  end
end

function TrueStrike:SaveAreaFramePosition(index)
  local frame = self.areaFrames[index]
  if not frame then return end

  local point, _, relativePoint, x, y = frame:GetPoint(1)
  local area = self:GetScrollAreaSettings(index)
  area.point = point
  area.relativePoint = relativePoint
  area.x = floor(x + 0.5)
  area.y = floor(y + 0.5)
end

function TrueStrike:SaveAreaFrameSize(index)
  local frame = self.areaFrames[index]
  if not frame then return end

  local area = self:GetScrollAreaSettings(index)
  area.width = floor(frame:GetWidth() + 0.5)
  area.height = floor(frame:GetHeight() + 0.5)
end

function TrueStrike:RefreshAreaFrames()
  local profile = self:GetProfile()

  for i, frame in ipairs(self.areaFrames or {}) do
    local area = profile.scrollAreas.areas[i]
    frame:ClearAllPoints()
    frame:SetPoint(area.point, UIParent, area.relativePoint, area.x, area.y)
    frame:SetSize(clamp(area.width, 120, 700), clamp(area.height, 60, 400))
    frame.label:SetText(area.name)

    local showHandles = profile.scrollAreas.unlocked
    frame.handle:SetShown(showHandles)
    frame.resizer:SetShown(showHandles)

    frame:SetShown(area.enabled)
  end
end

function TrueStrike:GetAreaFontSettings(area)
  local general = self:GetGeneralSettings()
  local source = area.useFontOverride and area or general
  local fontName = source.font or source.masterFont or "Friz Quadrata TT"
  local fontSize = source.fontSize or source.masterFontSize or 24
  local fontColor = source.fontColor or source.masterFontColor

  local fontPath = "Fonts\\FRIZQT__.TTF"
  local lsm = self:SafeGetLSM()
  if lsm then
    local fetched = lsm:Fetch("font", fontName, true)
    if fetched then
      fontPath = fetched
    end
  end

  return fontPath, fontSize, fontColor
end

function TrueStrike:PlayCritSound(area)
  local general = self:GetGeneralSettings()
  if not general.enableSound or not area.critSoundEnabled then
    return
  end

  local lsm = self:SafeGetLSM()
  if not lsm then return end

  local path = lsm:Fetch("sound", area.critSoundKey, true)
  if path and path ~= "" then
    PlaySoundFile(path, "SFX")
  end
end

function TrueStrike:SpawnTestEntry(areaIndex, text, isCrit)
  local area = self:GetScrollAreaSettings(areaIndex)
  local frame = self.areaFrames and self.areaFrames[areaIndex]
  if not area or not frame or not area.enabled then
    return
  end

  local entry = CreateFrame("Frame", nil, frame)
  entry:SetAllPoints(frame)
  entry.fs = entry:CreateFontString(nil, "OVERLAY")

  local anchor = "LEFT"
  local xAnchor = 8
  if area.justify == "CENTER" then
    anchor = "CENTER"
    xAnchor = 0
  elseif area.justify == "RIGHT" then
    anchor = "RIGHT"
    xAnchor = -8
  end

  entry.fs:SetPoint(anchor, xAnchor, 0)
  entry.fs:SetJustifyH(area.justify)
  entry.fs:SetText(text)

  local fontPath, size, col = self:GetAreaFontSettings(area)
  entry.fs:SetFont(fontPath, size, "OUTLINE")
  entry.fs:SetTextColor(col.r or 1, col.g or 1, col.b or 1, col.a or 1)

  local entryData = {
    frame = entry,
    fs = entry.fs,
    isCrit = isCrit,
    startTime = GetTime(),
    duration = DURATION,
    mode = area.scrollMode,
    critEffect = area.critEffect,
    baseX = xAnchor,
    startY = -frame:GetHeight() * 0.25,
  }

  table.insert(frame.activeEntries, entryData)

  if isCrit then
    self:PlayCritSound(area)
  end
end

function TrueStrike:UpdateAreaEntries(areaFrame, areaIndex, _elapsed)
  if not areaFrame:IsShown() then return end

  local t = GetTime()
  for i = #areaFrame.activeEntries, 1, -1 do
    local entry = areaFrame.activeEntries[i]
    local progress = (t - entry.startTime) / entry.duration

    if progress >= 1 then
      entry.frame:Hide()
      entry.frame:SetParent(nil)
      table.remove(areaFrame.activeEntries, i)
    else
      local yOffset
      if entry.mode == "DOWN" then
        yOffset = (1 - progress) * areaFrame:GetHeight() * 0.55
      elseif entry.mode == "PARABOLA" then
        local peak = 4 * progress * (1 - progress)
        yOffset = (peak - progress * 0.5) * areaFrame:GetHeight() * 0.8
      else
        yOffset = progress * areaFrame:GetHeight() * 0.65
      end

      local xOffset = entry.baseX
      if entry.mode == "PARABOLA" then
        xOffset = xOffset + (progress - 0.5) * 42
      end

      if entry.isCrit then
        if entry.critEffect == "WIGGLE" then
          xOffset = xOffset + sin(progress * 34) * 7
        elseif entry.critEffect == "POW" then
          local scale = 1 + (0.45 * (1 - progress))
          entry.fs:SetScale(scale)
        elseif entry.critEffect == "FLASH" then
          local alpha = 0.65 + 0.35 * sin(progress * 28)
          entry.fs:SetAlpha(alpha)
        end
      end

      entry.fs:ClearAllPoints()
      local area = self:GetScrollAreaSettings(areaIndex)
      local anchor = area.justify
      entry.fs:SetPoint(anchor, xOffset, entry.startY + yOffset)
      entry.fs:SetJustifyH(area.justify)
      entry.frame:SetAlpha(1 - progress * 0.7)
    end
  end
end

function TrueStrike:StopAllEntries()
  for _, frame in ipairs(self.areaFrames or {}) do
    for i = #frame.activeEntries, 1, -1 do
      local entry = frame.activeEntries[i]
      entry.frame:Hide()
      entry.frame:SetParent(nil)
      table.remove(frame.activeEntries, i)
    end
  end
end
