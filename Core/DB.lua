--[[
TrueStrike - Database Layer
Purpose:
  Define and manage all persisted addon settings through AceDB profiles.
Main responsibilities:
  - Provide a complete default schema for general and scroll-area settings.
  - Expose helper accessors used by UI modules.
  - Apply group edits across areas and fan out refresh hooks.
Module interactions:
  - Initialized from Core/Init:OnInitialize.
  - Read and written by UI tab modules and ScrollEngine.
]]

local _, ns = ...
local TrueStrike = ns.TrueStrike

local function color(r, g, b, a)
  return { r = r, g = g, b = b, a = a }
end

-- Profile schema for milestone state persistence.
-- Group values represent shared defaults for all enabled areas.
local defaults = {
  profile = {
    lastActiveMainTab = "General",
    general = {
      masterFont = "Friz Quadrata TT",
      masterFontSize = 24,
      masterFontColor = color(1, 0.82, 0, 1),
      disableBlizzardFCT = false,
      enableSound = true,
    },
    scrollAreas = {
      unlocked = true,
      group = {
        scrollMode = "UP",
        justify = "CENTER",
        critEffect = "NONE",
        critSoundEnabled = false,
        critSoundKey = "None",
      },
      areas = {
        {
          enabled = true,
          name = "Area 1",
          point = "CENTER",
          relativePoint = "CENTER",
          x = -300,
          y = 120,
          width = 260,
          height = 120,
          useFontOverride = false,
          font = "Friz Quadrata TT",
          fontSize = 24,
          fontColor = color(1, 0.82, 0, 1),
          scrollMode = "UP",
          justify = "LEFT",
          critEffect = "WIGGLE",
          critSoundEnabled = false,
          critSoundKey = "None",
        },
        {
          enabled = true,
          name = "Area 2",
          point = "CENTER",
          relativePoint = "CENTER",
          x = 0,
          y = 160,
          width = 260,
          height = 120,
          useFontOverride = false,
          font = "Friz Quadrata TT",
          fontSize = 24,
          fontColor = color(1, 0.82, 0, 1),
          scrollMode = "UP",
          justify = "CENTER",
          critEffect = "POW",
          critSoundEnabled = false,
          critSoundKey = "None",
        },
        {
          enabled = true,
          name = "Area 3",
          point = "CENTER",
          relativePoint = "CENTER",
          x = 300,
          y = 120,
          width = 260,
          height = 120,
          useFontOverride = false,
          font = "Friz Quadrata TT",
          fontSize = 24,
          fontColor = color(1, 0.82, 0, 1),
          scrollMode = "UP",
          justify = "RIGHT",
          critEffect = "FLASH",
          critSoundEnabled = false,
          critSoundKey = "None",
        },
      },
    },
  },
}

function TrueStrike:InitializeDatabase()
  self.db = LibStub("AceDB-3.0"):New("TrueStrikeDB", defaults, true)
end

function TrueStrike:GetProfile()
  return self.db.profile
end

function TrueStrike:GetGeneralSettings()
  return self.db.profile.general
end

function TrueStrike:GetScrollAreaSettings(index)
  return self.db.profile.scrollAreas.areas[index]
end

function TrueStrike:GetAllScrollAreaSettings()
  return self.db.profile.scrollAreas
end

function TrueStrike:ForEachArea(func)
  for i, area in ipairs(self.db.profile.scrollAreas.areas) do
    func(i, area)
  end
end

-- Group-mode edits propagate to all areas to maintain predictable behavior.
function TrueStrike:ApplyGroupSetting(key, value)
  self.db.profile.scrollAreas.group[key] = value
  self:ForEachArea(function(_, area)
    area[key] = value
  end)
end

-- Trigger tab/runtime refreshes after profile-level actions.
function TrueStrike:RefreshAfterDbChange()
  if self.RefreshGeneralTab then
    self:RefreshGeneralTab()
  end
  if self.RefreshScrollAreasTab then
    self:RefreshScrollAreasTab()
  end
  if self.RefreshAreaFrames then
    self:RefreshAreaFrames()
  end
end
