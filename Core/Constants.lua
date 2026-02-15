------------------------------------------------------------------------
-- TrueStrike Battle Text - Constants
-- Named constants used throughout the addon. No magic numbers.
------------------------------------------------------------------------

local ADDON_NAME, TSBT = ...

------------------------------------------------------------------------
-- Version & Identity
------------------------------------------------------------------------
TSBT.VERSION = "0.1.0-alpha"
TSBT.ADDON_TITLE = "TrueStrike Battle Text"
TSBT.SLASH_PRIMARY = "/tsbt"
TSBT.SLASH_SECONDARY = "/truestrike"

------------------------------------------------------------------------
-- Debug Levels
------------------------------------------------------------------------
TSBT.DEBUG_LEVEL_NONE       = 0    -- Production mode
TSBT.DEBUG_LEVEL_SUPPRESSED = 1    -- Show filtered/suppressed events
TSBT.DEBUG_LEVEL_CONFIDENCE = 2    -- Show confidence scores
TSBT.DEBUG_LEVEL_ALL_EVENTS = 3    -- Everything (verbose)

------------------------------------------------------------------------
-- Confidence Thresholds
------------------------------------------------------------------------
TSBT.CONFIDENCE_THRESHOLD_SOLO  = 0.6
TSBT.CONFIDENCE_THRESHOLD_GROUP = 0.85

-- Confidence contribution factors
TSBT.CONFIDENCE_DIRECT_CAST     = 0.7
TSBT.CONFIDENCE_PET_OWNERSHIP   = 0.5
TSBT.CONFIDENCE_ACTIVE_AURA     = 0.2
TSBT.CONFIDENCE_AUTO_ATTACK     = 0.3

------------------------------------------------------------------------
-- Deduplication
------------------------------------------------------------------------
TSBT.FINGERPRINT_HISTORY_SIZE = 30    -- Number of fingerprints to retain

------------------------------------------------------------------------
-- Diagnostics
------------------------------------------------------------------------
TSBT.DIAG_MAX_ENTRIES = 1000          -- Max diagnostic log entries

------------------------------------------------------------------------
-- UI Dimensions
------------------------------------------------------------------------
TSBT.CONFIG_WIDTH  = 650
TSBT.CONFIG_HEIGHT = 720

------------------------------------------------------------------------
-- Slider Ranges
------------------------------------------------------------------------
TSBT.FONT_SIZE_MIN = 8
TSBT.FONT_SIZE_MAX = 32
TSBT.ALPHA_MIN     = 0
TSBT.ALPHA_MAX     = 1

TSBT.SCROLL_OFFSET_MIN  = -500
TSBT.SCROLL_OFFSET_MAX  = 500
TSBT.SCROLL_WIDTH_MIN   = 100
TSBT.SCROLL_WIDTH_MAX   = 800
TSBT.SCROLL_HEIGHT_MIN  = 100
TSBT.SCROLL_HEIGHT_MAX  = 600

TSBT.MERGE_WINDOW_MIN = 0.5
TSBT.MERGE_WINDOW_MAX = 5.0

------------------------------------------------------------------------
-- Damage School Indices (matches WoW API school masks)
------------------------------------------------------------------------
TSBT.SCHOOL_PHYSICAL = 0x1
TSBT.SCHOOL_HOLY     = 0x2
TSBT.SCHOOL_FIRE     = 0x4
TSBT.SCHOOL_NATURE   = 0x8
TSBT.SCHOOL_FROST    = 0x10
TSBT.SCHOOL_SHADOW   = 0x20
TSBT.SCHOOL_ARCANE   = 0x40

------------------------------------------------------------------------
-- Color Scheme: "Strike Silver"
------------------------------------------------------------------------
TSBT.COLORS = {
    PRIMARY       = { r = 0.75, g = 0.75, b = 0.75 },   -- #C0C0C0  (general chrome/silver)
    TAB_INACTIVE  = { r = 1.00, g = 1.00, b = 1.00 },   -- #FFFFFF  (inactive tab text - pure white)
    PRIMARY_LIGHT = { r = 0.91, g = 0.91, b = 0.91 },   -- #E8E8E8
    ACCENT        = { r = 0.29, g = 0.62, b = 1.00 },   -- #4A9EFF  (active tab, highlights)
    DARK          = { r = 0.12, g = 0.16, b = 0.22 },   -- #1F2938  (main frame background - dark gunmetal)
    DARK_MID      = { r = 0.17, g = 0.24, b = 0.31 },   -- #2C3E50  (original gunmetal, kept for reference)
    BORDER        = { r = 0.55, g = 0.60, b = 0.66 },   -- #8B98A8  (chrome border - visible on dark bg)
    TEXT_LIGHT    = { r = 0.95, g = 0.95, b = 0.95 },   -- near white
}

------------------------------------------------------------------------
-- Outline Styles (keys for dropdown, values for WoW fontstring flags)
------------------------------------------------------------------------
TSBT.OUTLINE_STYLES = {
    ["None"]       = "",
    ["Thin"]       = "OUTLINE",
    ["Thick"]      = "THICKOUTLINE",
    ["Monochrome"] = "MONOCHROME",
}

------------------------------------------------------------------------
-- Animation Styles
------------------------------------------------------------------------
TSBT.ANIMATION_STYLES = {
    ["Parabola"] = "parabola",
    ["Straight"] = "straight",
    ["Static"]   = "static",
}

------------------------------------------------------------------------
-- Text Alignment
------------------------------------------------------------------------
TSBT.TEXT_ALIGNMENTS = {
    ["Left"]   = "LEFT",
    ["Center"] = "CENTER",
    ["Right"]  = "RIGHT",
}

------------------------------------------------------------------------
-- Scroll Direction
------------------------------------------------------------------------
TSBT.SCROLL_DIRECTIONS = {
    ["Up"]   = "UP",
    ["Down"] = "DOWN",
}

------------------------------------------------------------------------
-- Auto-Attack Display Modes
------------------------------------------------------------------------
TSBT.AUTOATTACK_MODES = {
    ["Show All"]        = "all",
    ["Show Only Crits"] = "crits",
    ["Hide"]            = "hide",
}

------------------------------------------------------------------------
-- Pet Aggregation Styles
------------------------------------------------------------------------
TSBT.PET_AGGREGATION = {
    ["Generic (\"Pet Hit X\")"]   = "generic",
    ["Attempt Pet Name"]          = "named",
}
