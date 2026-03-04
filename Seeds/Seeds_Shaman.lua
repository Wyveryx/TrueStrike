------------------------------------------------------------------------
-- TrueStrike - Seeds_Shaman.lua
-- Restoration Shaman confirmed spell ID registry.
-- Source: OutgoingHealCapture v13 — 13 probe sessions empirically confirmed.
-- DO NOT add spell IDs to this file without empirical in-game confirmation.
-- DO NOT guess at IDs from WoWhead or other external sources.
-- Synthetic designations (Riptide, Healing Rain, HST) remain in
-- TS_Registry.SeedKnownSpells() — they are architectural, not data.
------------------------------------------------------------------------

function TS_Registry.SeedShaman()
    local D = TS_Registry.DESIGNATION

    -- DIRECT HEALS
    TS_Registry.RegisterSpell(77472,  "Healing Wave",                    D.HEAL)
    TS_Registry.RegisterSpell(73685,  "Unleash Life",                    D.HEAL)
    TS_Registry.RegisterSpell(98008,  "Spirit Link Totem",               D.HEAL)
    TS_Registry.RegisterSpell(1064,   "Chain Heal",                      D.HEAL)
    TS_Registry.RegisterSpell(8004,   "Healing Surge",                   D.HEAL)

    -- HOTs — slot lifecycle managed by TS_SlotManager
    -- NOTE: 73920 is the CAST spell for Healing Rain. 73921 is the TICK spell.
    -- NOTE: 5394 is the CAST spell for HST. 52042 is the TICK spell.
    -- NOTE: Synthetic designations for Riptide/Healing Rain/HST stay in TS_Registry, not here.
    TS_Registry.RegisterSpell(61295,  "Riptide",                         D.HOT)
    TS_Registry.RegisterSpell(382024, "Earthliving",                     D.HOT)
    TS_Registry.RegisterSpell(73921,  "Healing Rain (tick)",             D.HOT)
    TS_Registry.RegisterSpell(207778, "Downpour (tick heal)",            D.HOT)
    TS_Registry.RegisterSpell(52042,  "Healing Stream Totem",            D.HOT)
    TS_Registry.RegisterSpell(444995, "Surging Totem",                   D.HOT)

    -- PROCS
    -- NOTE: Earth Shield uses three separate IDs — all must be Proc.
    -- 974 = target buff, 383648 = caster self buff, 379 = actual heal event ID.
    -- NOTE: 382311 Ancestral Awakening is PROC. It is NOT Heal. This is critical.
    -- If 382311 is ever designated Heal it will steal attribution from Riptide initial hits.
    TS_Registry.RegisterSpell(974,    "Earth Shield (target buff)",      D.PROC)
    TS_Registry.RegisterSpell(383648, "Earth Shield (self buff)",        D.PROC)
    TS_Registry.RegisterSpell(379,    "Earth Shield (heal proc)",        D.PROC)
    TS_Registry.RegisterSpell(462488, "Downpour (buff)",                 D.PROC)
    TS_Registry.RegisterSpell(53390,  "Tidal Waves",                     D.PROC)
    TS_Registry.RegisterSpell(470077, "Coalescing Water",                D.PROC)
    TS_Registry.RegisterSpell(77756,  "Lava Surge",                      D.PROC)
    TS_Registry.RegisterSpell(378776, "Inundate",                        D.PROC)
    TS_Registry.RegisterSpell(449209, "Authority of Fiery Resolve",      D.PROC)
    TS_Registry.RegisterSpell(382311, "Ancestral Awakening",             D.PROC)
    TS_Registry.RegisterSpell(462384, "Spouting Spirits",                D.PROC)

    -- DAMAGE — SINGLE TARGET
    -- NOTE: Lava Burst uses two IDs. 51505 is the cast spell. 285452 is the
    -- damage event ID that CTU actually fires under. Both must be Damage.
    TS_Registry.RegisterSpell(188196, "Lightning Bolt",                  D.DAMAGE)
    TS_Registry.RegisterSpell(51505,  "Lava Burst",                      D.DAMAGE)
    TS_Registry.RegisterSpell(285452, "Lava Burst (damage event)",       D.DAMAGE)
    TS_Registry.RegisterSpell(370,    "Purge",                           D.DAMAGE)
    TS_Registry.RegisterSpell(8042,   "Earth Shock",                     D.DAMAGE)
    TS_Registry.RegisterSpell(117014, "Elemental Blast",                 D.DAMAGE)

    -- DAMAGE — AOE
    TS_Registry.RegisterSpell(188443, "Chain Lightning",                 D.DAMAGE_AOE)
    TS_Registry.RegisterSpell(462620, "Earthquake",                      D.DAMAGE_AOE)
    TS_Registry.RegisterSpell(470411, "Voltaic Blaze",                   D.DAMAGE_AOE)
    TS_Registry.RegisterSpell(470053, "Voltaic Blaze (Base)",            D.DAMAGE_AOE)
    TS_Registry.RegisterSpell(61882,  "Earthquake (alt)",                D.DAMAGE_AOE)

    -- DOTS
    TS_Registry.RegisterSpell(188389, "Flame Shock",                     D.DOT)

    -- MELEE
    TS_Registry.RegisterSpell(6603,   "Auto Attack",                     D.MELEE)

    -- IGNORED — confirmed noise, summon spells, trinkets, consumables, utility
    -- NOTE: 73920 is Healing Rain CAST — Ignored. Tick fires as 73921 (HOT above).
    -- NOTE: 5394 is HST CAST — Ignored. Tick fires as 52042 (HOT above).
    -- NOTE: 382021 is Earthliving Weapon imbue buff — Ignored. Ticks fire as 382024 (HOT above).
    -- NOTE: 458357 is Chain Heal totem-sourced variant — Ignored to prevent false player attribution.
    TS_Registry.RegisterSpell(5394,    "Healing Stream Totem (cast)",    D.IGNORED)
    TS_Registry.RegisterSpell(73920,   "Healing Rain (cast)",            D.IGNORED)
    TS_Registry.RegisterSpell(456366,  "Healing Rain (summon)",          D.IGNORED)
    TS_Registry.RegisterSpell(462603,  "Downpour (cast)",                D.IGNORED)
    TS_Registry.RegisterSpell(458357,  "Chain Heal (totem-sourced)",     D.IGNORED)
    TS_Registry.RegisterSpell(462960,  "Mariner's Hallowed Citrine",     D.IGNORED)
    TS_Registry.RegisterSpell(462951,  "Thunderlord's Crackling Citrine",D.IGNORED)
    TS_Registry.RegisterSpell(1216884, "Kaja'Cola Mega-Lite",            D.IGNORED)
    TS_Registry.RegisterSpell(143924,  "Leech",                          D.IGNORED)
    TS_Registry.RegisterSpell(462854,  "Skyfury",                        D.IGNORED)
    TS_Registry.RegisterSpell(77223,   "Mastery: Enhanced Elements",     D.IGNORED)
    TS_Registry.RegisterSpell(77226,   "Mastery: Deep Healing",          D.IGNORED)
    TS_Registry.RegisterSpell(2645,    "Ghost Wolf",                     D.IGNORED)
    TS_Registry.RegisterSpell(556,     "Astral Recall",                  D.IGNORED)
    TS_Registry.RegisterSpell(546,     "Water Walking",                  D.IGNORED)
    TS_Registry.RegisterSpell(20608,   "Reincarnation",                  D.IGNORED)
    TS_Registry.RegisterSpell(192106,  "Lightning Shield",               D.IGNORED)
    TS_Registry.RegisterSpell(33757,   "Windfury Weapon",                D.IGNORED)
    TS_Registry.RegisterSpell(382021,  "Earthliving Weapon (imbue buff)",D.IGNORED)
    TS_Registry.RegisterSpell(52127,   "Water Shield",                   D.IGNORED)
    TS_Registry.RegisterSpell(57994,   "Wind Shear",                     D.IGNORED)
    TS_Registry.RegisterSpell(108271,  "Astral Shift",                   D.IGNORED)
    TS_Registry.RegisterSpell(2008,    "Ancestral Spirit",               D.IGNORED)
    TS_Registry.RegisterSpell(378081,  "Nature's Swiftness",             D.IGNORED)
    TS_Registry.RegisterSpell(443454,  "Ancestral Swiftness",            D.IGNORED)
    TS_Registry.RegisterSpell(77130,   "Purify Spirit",                  D.IGNORED)
    TS_Registry.RegisterSpell(440012,  "Cleanse Spirit",                 D.IGNORED)
    TS_Registry.RegisterSpell(192077,  "Wind Rush Totem",                D.IGNORED)
    TS_Registry.RegisterSpell(2484,    "Earthbind Totem",                D.IGNORED)
    TS_Registry.RegisterSpell(51485,   "Earthgrab Totem",                D.IGNORED)
    TS_Registry.RegisterSpell(192058,  "Capacitor Totem",                D.IGNORED)
    TS_Registry.RegisterSpell(198103,  "Earth Elemental",                D.IGNORED)
    TS_Registry.RegisterSpell(32182,   "Heroism",                        D.IGNORED)
    TS_Registry.RegisterSpell(192063,  "Gust of Wind",                   D.IGNORED)
    TS_Registry.RegisterSpell(51490,   "Thunderstorm",                   D.IGNORED)
    TS_Registry.RegisterSpell(191634,  "Stormkeeper",                    D.IGNORED)
    TS_Registry.RegisterSpell(114050,  "Ascendance (Restoration)",       D.IGNORED)
    TS_Registry.RegisterSpell(114051,  "Ascendance (Enhancement)",       D.IGNORED)
    TS_Registry.RegisterSpell(114052,  "Ascendance (Elemental)",         D.IGNORED)
    TS_Registry.RegisterSpell(318038,  "Flametongue Weapon",             D.IGNORED)
    TS_Registry.RegisterSpell(196884,  "Feral Lunge",                    D.IGNORED)
    TS_Registry.RegisterSpell(470057,  "Voltaic Blaze (proc buff)",      D.IGNORED)
    TS_Registry.RegisterSpell(6196,    "Far Sight",                      D.IGNORED)
    TS_Registry.RegisterSpell(125439,  "Revive Battle Pets",             D.IGNORED)
    TS_Registry.RegisterSpell(462757,  "Thunderstrike Ward",             D.IGNORED)
    TS_Registry.RegisterSpell(1231411, "Recuperate",                     D.IGNORED)
    TS_Registry.RegisterSpell(17364,   "Stormstrike",                    D.IGNORED)
    TS_Registry.RegisterSpell(60103,   "Lava Lash",                      D.IGNORED)
    TS_Registry.RegisterSpell(73899,   "Primal Strike",                  D.IGNORED)
    TS_Registry.RegisterSpell(187874,  "Crash Lightning",                D.IGNORED)
    TS_Registry.RegisterSpell(197214,  "Sundering",                      D.IGNORED)
    TS_Registry.RegisterSpell(384352,  "Doom Winds",                     D.IGNORED)
    TS_Registry.RegisterSpell(212048,  "Ancestral Vision",               D.IGNORED)
end
