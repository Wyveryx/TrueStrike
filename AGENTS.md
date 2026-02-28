# Project Overview
TrueStrike provides accurate floating combat text with confidence-based attribution for WoW 12.0.1 (Midnight). It bypasses Secret Values restrictions using COMBAT_TEXT_UPDATE passthrough logic combined with a confidence-based Designation Engine.

Three layers:
- Parser Layer: Detects and normalizes WoW events. Files: TS_DesigConfig.lua, TS_Taint.lua, TS_Registry.lua, TS_SlotManager.lua, TS_SpellbookScanner.lua, TS_AuraScanner.lua, TS_CastAnchor.lua, TS_CTURouter.lua. All live in Parser/.
- Core Layer: Decision logic and coordination. Files: Core.lua, Incoming_Probe.lua, Outgoing_Probe.lua, Combat_Decide.lua, Cooldowns_Decide.lua, Display_Decide.lua, Init.lua, Diagnostics.lua, MinimapButton.lua, Constants.lua, Defaults.lua. All live in Core/.
- UI Layer: Config and display. Files: Config.lua, ConfigTabs.lua, ScrollAreaFrames.lua. All live in UI/.

Load order (strict): Libs → Core/Constants.lua → Core/Defaults.lua → Core/Init.lua → Core/Diagnostics.lua → Core/*.lua → Parser/*.lua → UI/*.lua

# WoW 12.0.1 Secret Values Constraints (CRITICAL — enforce on every change)
- DO NOT perform arithmetic on combat amounts or CTU values.
- DO NOT use tonumber() on Secret Values.
- DO NOT use comparison operators on amounts or caster name strings from combat events.
- DO NOT call UnitAura(). It was removed in patch 11.0.2. The correct API is C_UnitAuras.GetAuraDataByIndex(unit, index, filter) which returns an AuraData struct. Access fields by name: aura.spellId, aura.expirationTime, aura.duration, aura.name.
- DO pass Secret Values directly to display via tostring() inside a pcall only.
- DO treat info.critical as a truthy/falsey flag only.

# CTU Passthrough System
TrueStrike uses COMBAT_TEXT_UPDATE combined with C_CombatText.GetCurrentEventInfo() to read combat values without triggering taint.

What CTU provides: data (caster name string), arg3 (amount as secret value), arg4 (extra).
What CTU fires for: self-heals, incoming heals, energize events, indirect procs (e.g. Earth Shield).
What CTU does NOT fire for: outgoing damage, direct heals cast on other players.
CTU does not provide spell name — attribution requires UNIT_SPELLCAST correlation.

# Proven Event Order
1. UNIT_SPELLCAST_SENT — fires immediately on cast initiation. Use for queuing instant casts.
2. UNIT_SPELLCAST_START — fires as cast bar begins. Use for cast-time spells.
3. COMBAT_TEXT_UPDATE — fires when the heal/event lands.
4. UNIT_SPELLCAST_SUCCEEDED — fires AFTER CTU. Do not use to pre-populate attribution queues.

HoT attribution: use UNIT_AURA to track active HoTs. When PERIODIC_HEAL CTU fires, check aura snapshot to attribute the tick.

# Taint and Combat Lockdown Rules
- Frame creation: at module/file scope during load only. NEVER inside Enable() or any event handler.
- Event registration: only inside Enable() / Disable(). Never inside InCombatLockdown().
- If InCombatLockdown() is true during Enable(), defer via PLAYER_REGEN_ENABLED hook.
- Initialization: use PLAYER_ENTERING_WORLD for safe parser activation.
- Aura scanning: C_UnitAuras.GetAuraDataByIndex must never be called when InCombatLockdown() is true. Guard every call site.
- Spellbook scanning: do not scan during PLAYER_ENTERING_WORLD. Spellbook data is not loaded yet. Scan on SPELLS_CHANGED event instead.

# PROMOTION_WINDOW_SECONDS
Value: 0.150 seconds. Empirically fixed across 13 probe sessions. Do not make this user-configurable without running a new probe campaign.

# Designation Engine Feature Flags
All flags live in Parser/TS_DesigConfig.lua. Current defaults:
- TRUESTRIKE_CAST_ANCHOR_ENABLED = true (CONFIRMED)
- TRUESTRIKE_HOT_SLOT_LIFECYCLE = true (CONFIRMED)
- TRUESTRIKE_TYPE_GATE = true (CONFIRMED)
- TRUESTRIKE_SPELLBOOK_SCAN = true (CONFIRMED)
- TRUESTRIKE_PRECOMBAT_AURA_SCAN = true (CONFIRMED)
- TRUESTRIKE_SYNTHETIC_TOTEM_SLOTS = true (CONFIRMED)
- TRUESTRIKE_KNOWN_SPELLS_OVERRIDE = true (CONFIRMED)
- TRUESTRIKE_UNIT_COMBAT_PROBE = false (FLAGGED — Outcome A confirmed incoming-only)
- TRUESTRIKE_MELEE_ATTRIBUTION = false (FLAGGED — no outgoing melee API path found)
- TRUESTRIKE_AURA_INSTANCE_PROBE = false (FLAGGED — Q2 verdict unverified)
- TRUESTRIKE_INCOMBAT_HOT_CREATION = false (FLAGGED — depends on aura instance probe)
- TRUESTRIKE_INCOMING_HEAL_PROBE = false (FLAGGED — untested)
- TRUESTRIKE_CLASS_DB_DRUID/PRIEST/PALADIN/MONK = false (FLAGGED — no discovery data)
- DEBUG_LOGGING = false
