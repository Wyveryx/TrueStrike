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

            -- Optional: attempt to suppress Blizzard floating combat text
            -- NOTE: May not work on all client builds (Blizzard changes / locks).
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
                minThreshold  = 0,
            },
            healing = {
                enabled       = true,
                scrollArea    = "Incoming",
                showHoTTicks  = true,
                minThreshold  = 0,
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
