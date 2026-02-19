------------------------------------------------------------------------
-- TrueStrike Battle Text - Default Configuration Values
-- Every user-configurable setting with its factory default.
-- Structure mirrors the AceDB profile schema.
------------------------------------------------------------------------

local ADDON_NAME, TSBT = ...

TSBT.DEFAULTS = {
    profile = {
        ------------------------------------------------------------------------
        -- Tab 1: General
        ------------------------------------------------------------------------
        general = {
            enabled       = true,       -- Master enable/disable
            combatOnly    = false,      -- Only show text during combat

            -- Disable Blizzard's floating combat text display
            -- NOTE: This sets enableFloatingCombatText CVar to 0, which hides
            -- Blizzard's visual display but still allows COMBAT_TEXT_UPDATE
            -- events to fire for TrueStrike's use.
            disableBlizzardFCT = false,

            -- DEPRECATED (WoW 12.0): These no longer function due to API changes
            -- Kept for backwards compatibility but have no effect.
            suppressBlizzardDamage  = false,
            suppressBlizzardHealing = false,

            -- Minimap button (simple native button, no LDB libs)
            minimap = {
                hide  = false,
                angle = 220,
            },

            -- Master font settings
            font = {
                face    = "Friz Quadrata TT",   -- Default WoW font
                size    = 18,
                outline = "Thin",               -- None / Thin / Thick / Monochrome
                alpha   = 1.0,                  -- 0.0 - 1.0
            },
        },

        ------------------------------------------------------------------------
        -- Tab 2: Scroll Areas
        ------------------------------------------------------------------------
        scrollAreas = {
            ["Outgoing"] = {
                xOffset   = 200,
                yOffset   = 0,
                width     = 200,
                height    = 300,
                alignment = "Center",
                direction = "Up",
                animation = "Parabola",
                animSpeed = 1.0,
            },
            ["Incoming"] = {
                xOffset   = -200,
                yOffset   = 0,
                width     = 200,
                height    = 300,
                alignment = "Center",
                direction = "Up",
                animation = "Straight",
                animSpeed = 1.0,
            },
            ["Notifications"] = {
                xOffset   = 0,
                yOffset   = 200,
                width     = 300,
                height    = 100,
                alignment = "Center",
                direction = "Up",
                animation = "Static",
                animSpeed = 1.0,
            },
        },

        ------------------------------------------------------------------------
        -- Tab 3: Incoming
        ------------------------------------------------------------------------
        incoming = {
            damage = {
                enabled       = true,
                scrollArea    = "Incoming",
                showFlags     = true,
                -- NOTE: minThreshold is non-functional in WoW 12.0 due to
                -- "Secret Values" - amounts cannot be compared, only displayed.
                minThreshold  = 0,
            },
            healing = {
                enabled       = true,
                scrollArea    = "Incoming",
                showHoTTicks  = true,
                showSpellInfo = true,   -- Show spell name and icon with heals
                -- NOTE: minThreshold is non-functional in WoW 12.0 due to
                -- "Secret Values" - amounts cannot be compared, only displayed.
                minThreshold  = 0,

                -- User-defined HoT spell IDs for attribution
                -- When a PERIODIC_HEAL event fires, we check active buffs
                -- against this list to determine which HoT produced the tick.
                -- Format: { [spellID] = true, ... }
                -- Example: { [61295] = true } for Riptide
                hotSpellIDs = {},
            },
            useSchoolColors = true,
            customColor     = { r = 1, g = 1, b = 1 },
        },

        ------------------------------------------------------------------------
        -- Tab 4: Outgoing
        ------------------------------------------------------------------------
        outgoing = {
            damage = {
                enabled        = true,
                scrollArea     = "Outgoing",
                showTargets    = false,
                autoAttackMode = "Show All",
                minThreshold   = 0,
            },
            healing = {
                enabled       = true,
                scrollArea    = "Outgoing",
                showOverheal  = false,
                minThreshold  = 0,
            },
            showSpellNames = false,
        },

        ------------------------------------------------------------------------
        -- Tab 5: Pets
        ------------------------------------------------------------------------
        pets = {
            enabled       = true,
            scrollArea    = "Outgoing",
            aggregation   = "Generic (\"Pet Hit X\")",
            minThreshold  = 0,
        },

        ------------------------------------------------------------------------
        -- Tab 6: Spam Control
        ------------------------------------------------------------------------
        spamControl = {
            merging = {
                enabled     = true,
                window      = 1.5,
                showCount   = true,
            },
            throttling = {
                minDamage     = 0,
                minHealing    = 0,
                hideAutoBelow = 0,
            },
            suppressDummyDamage = true,
        },

        ------------------------------------------------------------------------
        -- Tab 7: Cooldowns
        ------------------------------------------------------------------------
        cooldowns = {
            enabled    = true,
            scrollArea = "Notifications",
            format     = "%s Ready!",
            sound      = "None",
            tracked    = {},
        },

        ------------------------------------------------------------------------
        -- Tab 8: Media
        ------------------------------------------------------------------------
        media = {
            sounds = {
                lowHealth     = "None",
                cooldownReady = "None",
            },
            schoolColors = {
                physical = { r = 1.00, g = 1.00, b = 0.00 },
                holy     = { r = 1.00, g = 0.90, b = 0.50 },
                fire     = { r = 1.00, g = 0.30, b = 0.00 },
                nature   = { r = 0.30, g = 1.00, b = 0.30 },
                frost    = { r = 0.40, g = 0.80, b = 1.00 },
                shadow   = { r = 0.60, g = 0.20, b = 1.00 },
                arcane   = { r = 1.00, g = 0.50, b = 1.00 },
            },
        },

        ------------------------------------------------------------------------
        -- Diagnostics
        ------------------------------------------------------------------------
        diagnostics = {
            debugLevel     = 0,
            captureEnabled = false,
            maxEntries     = 1000,
            log            = {},
        },
    },
}
