------------------------------------------------------------------------
-- TrueStrike - Seeds_Racials.lua
-- Racial spell ID registry — DEFERRED.
-- Racial spell IDs have not yet been empirically confirmed via CTU
-- observation sessions. Do not populate this file from WoWhead or
-- external sources. All entries must come from in-game probe data.
-- This file is loaded in TrueStrike.toc but the seed function is
-- commented out and must not be called until data is confirmed.
------------------------------------------------------------------------
TS_Registry = TS_Registry or {}



--[[ FLAGGED: Racial Seeds — deferred pending empirical probe data
     Why flagged:         Racial spell IDs unconfirmed. No CTU observation
                          session has been run for racials.
     Evidence gap:        Zero in-game data for racial combat events.
     Acceptance criteria: At least one CTU observation session per race
                          confirms IDs before any entry is added.
     Default behavior:    Function body is entirely commented out.
                          TS_Registry.SeedRacials() is defined but is a no-op.
     Feature flag:        NONE — activate by uncommenting entries after
                          empirical confirmation only.
--]]

-- function TS_Registry.SeedRacials()
--     local D = TS_Registry.DESIGNATION
--     -- Add confirmed racial spell IDs here after empirical probe sessions.
--     -- Example format:
--     -- TS_Registry.RegisterSpell(spellID, "Spell Name", D.DESIGNATION)
-- end
