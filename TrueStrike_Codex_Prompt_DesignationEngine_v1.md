# CODEX PROMPT — TrueStrike Designation Engine Integration (dev branch)

**Classification authority:** `TrueStrike_DesignationEngine_Handoff_v1.md`  
**Do not read, require, or create runtime dependencies on any file prefixed `ZZ_`.**  
**Do not refactor anything unrelated to the tasks below. Surgical integration only.**

---

## A) CONSTRAINTS & GUARDRAILS

**WoW 12.0.1 Secret Values — hard stops. Violating any of these detonates the client:**

1. The `value` argument from every `COMBAT_TEXT_UPDATE` event is always a secret value. Store it ONLY via `tostring()` inside a `pcall`. Never do arithmetic on it. Never compare it. Never use it as a table key. Never pass it to `tonumber()`. Ever.
2. `C_UnitAuras.GetBuffDataByIndex` (or `GetBuffDataByIndex`) must NEVER be called when `InCombatLockdown()` is true. Guard every call site unconditionally.
3. `UnitAura`-derived `isFromPlayerOrPlayerPet` is a secret boolean in combat. Do not test it. Do not read it.
4. Do not use `sourceUnit == "player"` comparisons on any aura table field in combat. That is a secret string comparison. Fatal.
5. Do not call `RegisterEvent` or `UnregisterEvent` inside `InCombatLockdown()`.
6. Do not call `CreateFrame` inside any `:Enable()` method. Frames must exist at file/module load scope.
7. `PROMOTION_WINDOW_SECONDS = 0.150` is empirically fixed. Do not make it user-configurable without a new probe run.
8. The DISPROVEN list in the handoff document represents closed investigations. Do not implement any of them. Leave tombstone comment blocks and move on.

**Scope guard:**

- Classification authority is `TrueStrike_DesignationEngine_Handoff_v1.md`. If something is not CONFIRMED in that document, it is either FLAGGED (stub + comment, default OFF) or DISPROVEN (tombstone comment only).
- Do not invent behavior. Do not "improve" adjacent code. If you see something broken outside your task list, note it in a `-- TODO:` comment and leave it alone.
- The existing TrueStrike addon uses the namespace pattern `local ADDON_NAME, TSBT = ...` and Ace3 for DB/events. Match it exactly. Do not introduce global pollution.

---

## B) REQUIRED COMMENT TEMPLATES

Use this block verbatim at every FLAGGED integration point and every incomplete stub:

```lua
--[[ FLAGGED: <short title>
     Why flagged:         <what is uncertain or risky>
     Evidence gap:        <what is missing from handoff confirmation>
     Acceptance criteria: <what must be true before treating as CONFIRMED>
     Default behavior:    <what this code does right now — e.g., disabled, returns nil, early-out>
     Feature flag:        <TS_DesigConfig flag name, or NONE>
--]]
```

Use this block verbatim for every DISPROVEN item (implementation forbidden):

```lua
--[[ DISPROVEN: <short title>
     Do not implement. Reason: <why this is closed under WoW 12.0.1 constraints>
     Source: TrueStrike_DesignationEngine_Handoff_v1.md
--]]
```

These blocks must appear **adjacent to the code location** where the behavior would have lived, not in a header block at the top of the file. Every FLAGGED flag in Section E must have at least one of these blocks in the code.

---

## C) IMPLEMENTATION PLAN

Before making any change, list every file you intend to modify and what you will do to each one. Do this as a comment block at the top of your first response. If you are uncertain which file owns a particular hook, search the repo for the relevant event name or function name and report what you found before proceeding.

Execute these tasks **in order**. Do not skip ahead.

---

### Task 1 — Create `Parser/TS_DesigConfig.lua`

Create a new file at `Parser/TS_DesigConfig.lua`. This is the single source of truth for Designation Engine feature flags and constants.

Contents:

- A module table `TS_DesigConfig` (not namespaced under TSBT — it must be accessible as a simple global from all Designation Engine modules in this folder).
- `PROMOTION_WINDOW_SECONDS = 0.150` — hardcoded, comment that it is empirically fixed and must not change without a new probe run.
- All flags from Section E of this prompt, with their specified defaults.
- `DEBUG_LOGGING = false` default.
- A `SafeLog(prefix, msg)` local helper that prints only when `DEBUG_LOGGING` is true.

Do NOT add this file to the `.toc` yet — Task 18 covers load order.

---

### Task 2 — Create `Parser/TS_Taint.lua`

Create a new file at `Parser/TS_Taint.lua`. This module owns all taint-safe utility functions.

Contents:

- `TS_Taint.SafeStr(val)` — wraps `tostring(val)` in a `pcall`. On success returns the result string. On failure logs `TAINT_ERROR` and returns `"?"`.
- `TS_Taint.SafeAuraExtract(unit, index)` — wraps a `UnitAura(unit, index, "HELPFUL|PLAYER")` call inside `pcall`. Returns `{name, expirationTime, duration, spellID}` as clean values if successful, or `nil` on taint/error. Must guard with `InCombatLockdown()` — if in combat, return nil immediately without calling the API.
- Add the following DISPROVEN tombstone blocks in this file:
  - Arithmetic on CTU secret values
  - `tonumber()` on any CTU-derived value
  - Secret value as table key
  - String laundering via `tostring -> concat -> string.match`

---

### Task 3 — Create `Parser/TS_Registry.lua`

Create a new file at `Parser/TS_Registry.lua`. This is the spell designation registry and type gate.

Contents:

- `TS_Registry.DESIGNATION` table — constants: `HOT`, `HEAL`, `MELEE`, `DAMAGE`, `DAMAGE_AOE`, `DOT`, `PROC`, `IGNORED`, `UNKNOWN`.
- `TS_Registry.HEAL_FAMILY = { HoT = true, Heal = true }` and `TS_Registry.DAMAGE_FAMILY = { Damage = true, Damage_AoE = true, DoT = true, Melee = true }`. These must never be merged or relaxed.
- `_registry` — private table, keyed by spellID (integer), value `{name, desig}`.
- `TS_Registry.RegisterSpell(spellID, name, desig)` — inserts or updates the registry entry. No-op if spellID is nil or 0.
- `TS_Registry.GetDesignation(spellID)` — returns `desig` string or `nil`.
- `TS_Registry.TryPromote(spellID, newDesig, confidence, source)` — implements the type gate. Rules:
  - If no existing entry: register and log `SPELL_PROMOTED`.
  - If existing entry's family differs from `newDesig`'s family: block the promotion, log `TYPE_GATE_FIRED`, return false.
  - If within same family: allow, log `SPELL_PROMOTED`, return true.
  - Use `TS_DesigConfig.TRUESTRIKE_TYPE_GATE` flag; if false, skip the gate and always promote (but still log).
- `TS_Registry.SeedKnownSpells()` — seeds the full Restoration Shaman spell table using Section 4.9 of `TrueStrike_DesignationEngine_Handoff_v1.md` as the only data source. Do not invent spell IDs. Key entries that must be present (verify each against the handoff):
  - Riptide HoT tick (61295 → HoT), Riptide cast variant per handoff
  - Healing Wave (77472 → Heal), Greater Healing Wave (77451 → Heal)
  - Healing Rain tick (73921 → HoT), Healing Rain cast (73920 → Ignored), totem chain heal variant (458357 → Ignored)
  - Earth Shield charge procs (383648, 974, 379 → Proc — NOT HoT, NOT Heal)
  - HST summon (5394 → Ignored), HST tick (52042 → HoT)
  - Voltaic Blaze (470411 → Damage_AoE)
  - Chain Heal (1064 → Heal)
  - Earthliving proc (51945 → Proc)
  - All additional IDs found in Section 4.9. If an ID is ambiguous in the handoff, add a `-- TODO: verify spellID` comment and seed it as `UNKNOWN`.
- Log prefix: `[TS_REG]`

---

### Task 4 — Create `Parser/TS_SlotManager.lua`

Create a new file at `Parser/TS_SlotManager.lua`. This owns HoT slot lifecycle.

Contents:

- Private `_hotSlots = {}` and `_slotCounter = 0`.
- `TS_SlotManager.NewHotSlot(spellID, spellName, unit, expirationTime, duration, source)` — creates slot table with fields: `slotID` (string, e.g. `"HoT1"`), `spellID`, `spellName`, `unit`, `assignedTime = GetTime()`, `expirationTime`, `duration`, `tickCount = 0`, `source`. Inserts into `_hotSlots`. Logs `HOT_SLOT_CREATED`. Returns slot table. Guard: only create if `TRUESTRIKE_HOT_SLOT_LIFECYCLE` is true.
- `TS_SlotManager.FindHotSlot(spellID, unit)` — iterates `_hotSlots`, skips expired slots (`expirationTime < GetTime()`), returns first matching `{spellID, unit}` slot or nil.
- `TS_SlotManager.RemoveSlotsBySpellID(spellID)` — removes all slots matching spellID, logs `HOT_SLOT_EXPIRED` for each.
- `TS_SlotManager.PruneExpiredSlots()` — removes all slots where `expirationTime < GetTime()`, logs `HOT_SLOT_EXPIRED` for each.
- `TS_SlotManager.GetActiveSlots()` — returns `_hotSlots` (direct reference, read-only intent).
- Log prefix: `[TS_SLOT]`

**Synthetic totem slot** (CONFIRMED 11, gated on `TRUESTRIKE_SYNTHETIC_TOTEM_SLOTS`):

- `TS_SlotManager.CreateSyntheticTotemSlot(summonSpellID, tickSpellID, tickSpellName, durationSeconds)` — builds a slot with `unit = "synthetic_totem"`, `expirationTime = GetTime() + durationSeconds`, `source = "SYNTHETIC_TOTEM"`. HST call site uses: `summonSpellID = 5394`, `tickSpellID = 52042`, `tickSpellName = "Healing Stream"`, `durationSeconds = 15` (verify against handoff Section 4.9 and use that value).

---

### Task 5 — Create `Parser/TS_SpellbookScanner.lua`

Create a new file at `Parser/TS_SpellbookScanner.lua`.

Contents:

- `_spellbookScanned = false` private flag.
- `TS_SpellbookScanner.ScanSpellbook()` — iterates the player's spellbook tabs via `GetNumSpellTabs()` and `GetSpellBookItemInfo()`. For each spell found, calls `C_Spell.GetSpellInfo(spellID)` to get the name and calls `TS_Registry.RegisterSpell(spellID, name, DESIGNATION.UNKNOWN)` only if `TS_Registry.GetDesignation(spellID)` returns nil (never overwrite a seeded designation with UNKNOWN). Uses `C_Spell.IsSpellPassive(spellID)` — if true, register as IGNORED. Sets `_spellbookScanned = true` on completion.
- `TS_SpellbookScanner.OnSpellsChanged()` — resets `_spellbookScanned = false`, then calls `ScanSpellbook()`. This is the handler to register on `SPELLS_CHANGED`.
- Guard: entire module gated on `TRUESTRIKE_SPELLBOOK_SCAN`.
- Log prefix: `[TS_BOOK]`

**IMPORTANT:** Spellbook scanning must be triggered by `SPELLS_CHANGED`, NOT by `PLAYER_ENTERING_WORLD`. Add a FLAGGED comment if you see any temptation to scan on `PLAYER_ENTERING_WORLD`.

---

### Task 6 — Create `Parser/TS_AuraScanner.lua`

Create a new file at `Parser/TS_AuraScanner.lua`.

Contents:

- `_watchedUnits = {"player", "target", "party1", "party2", "party3", "party4"}` — default unit list.
- `_auraSnapshot = {}` — keyed by unit, value = list of `{spellID, name, expirationTime, duration}` tables built from `TS_Taint.SafeAuraExtract` results.
- `TS_AuraScanner.ScanUnit(unit)` — iterates aura slots for `unit` via `UnitAura(unit, index, "HELPFUL|PLAYER")` inside pcall (use `TS_Taint.SafeAuraExtract`). Builds `_auraSnapshot[unit]`. MUST check `InCombatLockdown()` first — if in combat, abort and return existing snapshot unchanged.
- `TS_AuraScanner.ScanAllWatchedUnits()` — calls `ScanUnit` for each unit in `_watchedUnits`. Only valid out of combat. Guard with `InCombatLockdown()`.
- `TS_AuraScanner.SnapshotAllWatchedUnits()` — returns `_auraSnapshot` (read-only reference, used by CTURouter during attribution).
- `TS_AuraScanner.OnUnitAura(unit)` — called when `UNIT_AURA` fires. If not in combat and unit is in `_watchedUnits`, calls `ScanUnit(unit)`. After scan, checks the updated snapshot for any newly-appeared spells designated as HoT in the registry and calls `TS_SlotManager.NewHotSlot(...)` for them if no live slot already exists for that spellID+unit pair.
- Guard: pre-combat scan gated on `TRUESTRIKE_PRECOMBAT_AURA_SCAN`.
- Add FLAGGED block for `TRUESTRIKE_INCOMBAT_HOT_CREATION` at the location where in-combat HoT slot creation would have lived. The block must explain that Q2 verdict is unconfirmed, the feature is OFF, and current behavior falls back to lease-clock only.
- Add DISPROVEN tombstone adjacent for `GetBuffDataByIndex` in combat.
- Log prefix: `[TS_AURA]`

---

### Task 7 — Create `Parser/TS_CastAnchor.lua`

Create a new file at `Parser/TS_CastAnchor.lua`.

Contents:

- Private state: `_pendingCasts = {}` keyed by `castGUID` string, value `{spellID, spellName, target, sentTime}`. `_lastSucceededSpellID = nil`, `_lastSucceededTime = nil`.
- `TS_CastAnchor.GetLastSucceeded()` — returns `_lastSucceededSpellID, _lastSucceededTime`.
- `TS_CastAnchor.OnSpellcastSent(unit, target, castGUID, spellID)` — guard `unit ~= "player"`. Store entry in `_pendingCasts[castGUID]` with `target = TS_Taint.SafeStr(target)`, `sentTime = GetTime()`. Log `CAST_ANCHOR {spellID, castGUID, target, desig, timestamp}` where desig comes from `TS_Registry.GetDesignation(spellID)`.
- `TS_CastAnchor.OnSpellcastSucceeded(unit, target, castGUID, spellID)` — guard `unit ~= "player"`. Look up `_pendingCasts[castGUID]`. If found: set `_lastSucceededSpellID = spellID`, `_lastSucceededTime = GetTime()`. If spell designation is HoT: call `TS_AuraScanner.ScanUnit("player")` (out-of-combat only) to refresh snapshot before tick attribution. If spellID is the HST summon ID (`5394`) and `TRUESTRIKE_SYNTHETIC_TOTEM_SLOTS` is on: call `TS_SlotManager.CreateSyntheticTotemSlot(5394, 52042, "Healing Stream", 15)`. Remove entry from `_pendingCasts`. Log `CAST_ANCHOR` resolved.
- `TS_CastAnchor.OnSpellcastFailed(unit, target, castGUID, spellID)` — remove entry from `_pendingCasts[castGUID]`.
- `TS_CastAnchor.OnSpellcastInterrupted(unit, target, castGUID, spellID)` — same as Failed.
- `TS_CastAnchor.PruneStale(maxAge)` — removes entries from `_pendingCasts` where `sentTime < GetTime() - maxAge`. Call with `maxAge = 10` seconds. Called by CTURouter before attribution.
- Guard: entire module gated on `TRUESTRIKE_CAST_ANCHOR_ENABLED`.
- Log prefix: `[TS_ANCHOR]`

---

### Task 8 — Create `Parser/TS_CTURouter.lua`

Create a new file at `Parser/TS_CTURouter.lua`. This is the `COMBAT_TEXT_UPDATE` handler and attribution dispatcher.

Contents:

- `TS_CTURouter.CTU_SLOT_FAMILY` table:

```lua
TS_CTURouter.CTU_SLOT_FAMILY = {
    HEAL                 = "Heal",
    HEAL_CRIT            = "Heal",
    PERIODIC_HEAL        = "HoT",
    PERIODIC_HEAL_CRIT   = "HoT",
    SPELL_DAMAGE         = "Damage",
    SPELL_DAMAGE_CRIT    = "Damage",
    PERIODIC_DAMAGE      = "DoT",
    PERIODIC_DAMAGE_CRIT = "DoT",
    DAMAGE               = "Melee",
}
```

- `TS_CTURouter.OnCombatTextUpdate(ctuType, value)` — the handler. Steps in order:
  1. Call `TS_CastAnchor.PruneStale(10)`.
  2. Call `TS_SlotManager.PruneExpiredSlots()`.
  3. `local valueStr = TS_Taint.SafeStr(value)` — this is the ONLY storage or use of `value`. Never do anything else with it.
  4. Look up `expectedDesig = CTU_SLOT_FAMILY[ctuType]`. If nil and `ctuType` not in a known-ignorable set, log `UNKNOWN_OBSERVED`.
  5. Call `TS_CTURouter.AttributeTick(ctuType, auraSnapshot, lastSpellID, lastSpellTime)` where `auraSnapshot = TS_AuraScanner.SnapshotAllWatchedUnits()` and `lastSpellID, lastSpellTime = TS_CastAnchor.GetLastSucceeded()`.
  6. Log `CTU_CAPTURED {seq, ctuType, valueStr, correlatedSpellID, desig}`.
  7. If attribution succeeded, dispatch to TrueStrike display (see Task 9 for the integration boundary).

- Add the following DISPROVEN tombstone blocks inside `OnCombatTextUpdate`:
  - Arithmetic on `value`
  - `tonumber(value)`
  - `value` as table key

- Add FLAGGED block for the `DAMAGE` / Melee routing path — UNIT_COMBAT Outcome A confirmed incoming-only, so `CTU_SLOT_FAMILY["DAMAGE"] = "Melee"` is plumbed but outgoing melee attribution is gated behind `TRUESTRIKE_MELEE_ATTRIBUTION = false`.

- `TS_CTURouter.AttributeTick(ctuType, auraSnapshot, lastSpellID, lastSpellTime)` — two-pass attribution:
  - **Pass 1 (anchor-preferred):** If `(GetTime() - lastSpellTime) < PROMOTION_WINDOW_SECONDS`, check if `TS_Registry.GetDesignation(lastSpellID)` matches `expectedDesig`. If yes, call `TS_SlotManager.FindHotSlot(lastSpellID, "player")`. If slot found: return `{slotID, spellID = lastSpellID, confidence = "HIGH"}`.
  - **Pass 2 (general):** Iterate `TS_SlotManager.GetActiveSlots()`. For each slot, if `TS_Registry.GetDesignation(slot.spellID) == expectedDesig`: confidence = HIGH if `auraSnapshot["player"]` contains this spellID, else MEDIUM. Return first match. Log `TICK_ATTRIBUTED`.
  - If no match: return nil. Log the miss as `UNKNOWN_OBSERVED`.
  - Earth Shield spell IDs (974, 383648, 379) are PROC-designated in the registry; the type gate prevents false PERIODIC_HEAL matches naturally. Add a comment pointing to this.

- Log prefix: `[TS_CTU]`

---

### Task 9 — Integration boundary: connect TS_CTURouter to TrueStrike display

Find `Parser/HealAttribution.lua`. This file currently owns `COMBAT_TEXT_UPDATE` registration and heal attribution.

Steps:

1. Search for where `COMBAT_TEXT_UPDATE` is registered in `HealAttribution.lua` (or in `Core/Core.lua` or `Core/Init.lua` if wired there).
2. **Do not remove the existing attribution logic.** Instead, add a gated call: if `TS_DesigConfig` exists and `TS_DesigConfig.TRUESTRIKE_CAST_ANCHOR_ENABLED` is true, call `TS_CTURouter.OnCombatTextUpdate(ctuType, value)` **before** the existing logic runs. The existing logic remains as the fallback.
3. Add a comment: `-- DESIGNATION ENGINE: TS_CTURouter runs first when enabled. Existing attribution below is fallback.`
4. The display dispatch from `TS_CTURouter` (Task 8, step 7) must call whatever the current TrueStrike display emission function is. Search for the function that takes an attributed heal/damage event and routes it to the scrolling text display. Use that function. If it is ambiguous, leave a `-- TODO: wire to display emit function` comment and do not guess.

---

### Task 10 — Event registration in `Core/Init.lua` or the appropriate event frame

Find where TrueStrike registers `UNIT_SPELLCAST_SENT`, `UNIT_SPELLCAST_SUCCEEDED`, `UNIT_SPELLCAST_FAILED`, `UNIT_SPELLCAST_INTERRUPTED`, and `UNIT_AURA` events (search the repo for these strings).

Add registrations for the Designation Engine handlers at the same location, gated appropriately:

- `UNIT_SPELLCAST_SENT` → `TS_CastAnchor.OnSpellcastSent`
- `UNIT_SPELLCAST_SUCCEEDED` → `TS_CastAnchor.OnSpellcastSucceeded`
- `UNIT_SPELLCAST_FAILED` → `TS_CastAnchor.OnSpellcastFailed`
- `UNIT_SPELLCAST_INTERRUPTED` → `TS_CastAnchor.OnSpellcastInterrupted`
- `UNIT_AURA` → `TS_AuraScanner.OnUnitAura`
- `SPELLS_CHANGED` → `TS_SpellbookScanner.OnSpellsChanged`

All registrations must happen inside a `PLAYER_ENTERING_WORLD` handler or the existing safe-init hook. NEVER at file load scope. NEVER inside `InCombatLockdown()`.

If existing handlers for these events already exist, chain to the Designation Engine handlers rather than replacing them.

---

### Task 11 — Initialization sequence in `Core/Init.lua`

Find the `PLAYER_ENTERING_WORLD` handler or the Ace3 `:OnEnable()` equivalent that runs after world load.

Add, in this order:

1. `TS_Registry.SeedKnownSpells()` — seeds the Restoration Shaman spell table. Guard with `TRUESTRIKE_KNOWN_SPELLS_OVERRIDE`.
2. `TS_SpellbookScanner.ScanSpellbook()` — initial scan. Guard with `TRUESTRIKE_SPELLBOOK_SCAN`.
3. `TS_AuraScanner.ScanAllWatchedUnits()` — pre-combat snapshot. Guard with `TRUESTRIKE_PRECOMBAT_AURA_SCAN`. Add `InCombatLockdown()` guard — skip if re-entering from a loading screen mid-combat.

---

### Task 12 — SavedVariables: structured log table

Find where `TrueStrikeDB` (or the equivalent SavedVariables table) is declared in `Core/Defaults.lua` or `Core/Init.lua`.

Add a `designationLog` subtable with these keys initialized to empty tables or 0:

```lua
designationLog = {
    castAnchors     = {},
    hotSlots        = {},
    tickAttributed  = {},
    ctuCaptured     = {},
    spellPromoted   = {},
    typeGateFired   = {},
    unknownObserved = {},
    taintErrors     = {},
    sessionSummary  = {},
}
```

Logging calls in all Designation Engine modules must append to these subtables using the field shapes from Section F.

---

### Task 13 — Session summary on `PLAYER_LEAVING_WORLD`

Find where `PLAYER_LEAVING_WORLD` is handled, or add a handler.

On this event, write a `SESSION_END` entry to `designationLog.sessionSummary`:

- `totalCTU` — count of `ctuCaptured` entries
- `promotionCount` — count of `spellPromoted` entries
- `unknownCount` — count of `unknownObserved` entries
- `taintErrors` — count of `taintErrors` entries
- `slotCount` — count of `hotSlots` created entries
- `meleeCount` — count of `ctuCaptured` entries with `desig == "Melee"` (only relevant if `TRUESTRIKE_MELEE_ATTRIBUTION` was on during session)
- `timestamp = GetServerTime()`

---

### Task 14 — UNIT_COMBAT FLAGGED stub (FLAG 1)

In `Parser/TS_CTURouter.lua` or in a clearly named comment block in `Core/Init.lua`, add a FLAGGED comment block for `TRUESTRIKE_UNIT_COMBAT_PROBE`:

```lua
--[[ FLAGGED: UNIT_COMBAT outgoing melee probe
     Why flagged:         UNIT_COMBAT confirmed Outcome A (incoming-only for
                          RegisterUnitEvent("UNIT_COMBAT","player")). Outgoing melee
                          via this path is disproven for RegisterUnitEvent.
                          Flag preserved in case a new API path is discovered.
     Evidence gap:        No new API path identified. UNIT_COMBAT delivers
                          player-targeted incoming events only.
     Acceptance criteria: New empirical probe demonstrates outgoing WOUND+PHYSICAL
                          events accessible from a non-UNIT_COMBAT API.
     Default behavior:    No UNIT_COMBAT handler registered. Melee attribution
                          entirely inactive.
     Feature flag:        TRUESTRIKE_MELEE_ATTRIBUTION = false
--]]
```

Do NOT register `UNIT_COMBAT`. Do NOT add any melee attribution logic. Flag only.

---

### Task 15 — `GetAuraDataByAuraInstanceID` FLAGGED stub (FLAG 2)

In `Parser/TS_AuraScanner.lua`, at the location where in-combat HoT slot creation would have been, add:

```lua
--[[ FLAGGED: GetAuraDataByAuraInstanceID in-combat HoT creation
     Why flagged:         GetAuraDataByAuraInstanceID Q2 probe fired in v12 but the
                          DB verdict field (CLEAN/TAINTED) was not manually verified.
     Evidence gap:        Manual DB review of Q2 verdict required from a dungeon
                          session with >= 100 PERIODIC_HEAL events.
     Acceptance criteria: registry shows verdict="CLEAN" for Q2 probe.
     Default behavior:    In-combat HoT creation disabled. Lease-clock lifecycle only
                          (UnitAura pre-combat scan).
     Feature flag:        TRUESTRIKE_INCOMBAT_HOT_CREATION = false
--]]
```

Add a DISPROVEN tombstone adjacent for `GetBuffDataByIndex` in combat.

---

### Task 16 — Non-self incoming heal FLAGGED stub (FLAG 3)

In `Parser/TS_CTURouter.lua`, in the HEAL/HEAL_CRIT routing branch, add:

```lua
--[[ FLAGGED: Non-self incoming heals via CTU
     Why flagged:         Does CTU fire for heals received FROM other players?
                          Completely untested.
     Evidence gap:        No session data exists for CTU HEAL events where the
                          player cast nothing.
     Acceptance criteria: Observed CTU HEAL event confirmed from external source
                          in at least one session.
     Default behavior:    HEAL/HEAL_CRIT routing proceeds as self-cast only.
                          External heals will attribute as Unknown if no SENT anchor
                          or HoT slot matches.
     Feature flag:        TRUESTRIKE_INCOMING_HEAL_PROBE = false
--]]
```

---

### Task 17 — Multi-class DB FLAGGED stubs (FLAG 5)

In `Parser/TS_Registry.lua`, after the Restoration Shaman seed block, add FLAGGED comment blocks for each non-Shaman class using this template:

```lua
--[[ FLAGGED: Multi-class spell database — {CLASS}
     Why flagged:         All confirmed spell ID data is Restoration Shaman only
                          (Pyrite, Kael'thas). Every other class requires its own
                          OutgoingHealCapture discovery run.
     Evidence gap:        No session data for any non-Shaman class.
     Acceptance criteria: Full session (>=500 events) with class OutgoingHealCapture
                          producing a verified KNOWN_SPELLS table.
     Default behavior:    No spell IDs registered for this class. All spells will
                          scan as UNKNOWN until a class-specific discovery run is
                          completed and merged.
     Feature flag:        TRUESTRIKE_CLASS_DB_{CLASS} = false
--]]
```

Include stubs for: DRUID, PRIEST, PALADIN, MONK. Leave clearly marked space for additional classes.

---

### Task 18 — Update `TrueStrike.toc`

Add the new Designation Engine files to the `.toc` load order. They must load in this exact order, after all existing Parser files but before any UI files:

```
Parser/TS_DesigConfig.lua
Parser/TS_Taint.lua
Parser/TS_Registry.lua
Parser/TS_SlotManager.lua
Parser/TS_SpellbookScanner.lua
Parser/TS_AuraScanner.lua
Parser/TS_CastAnchor.lua
Parser/TS_CTURouter.lua
```

Do NOT add any file beginning with `ZZ_` to the `.toc`.

---

## D) FILES TO MODIFY

List every file you will change before changing it. Report any path discrepancies found during repo search.

| File | Action |
|------|--------|
| `Parser/TS_DesigConfig.lua` | CREATE |
| `Parser/TS_Taint.lua` | CREATE |
| `Parser/TS_Registry.lua` | CREATE |
| `Parser/TS_SlotManager.lua` | CREATE |
| `Parser/TS_SpellbookScanner.lua` | CREATE |
| `Parser/TS_AuraScanner.lua` | CREATE |
| `Parser/TS_CastAnchor.lua` | CREATE |
| `Parser/TS_CTURouter.lua` | CREATE |
| `Parser/HealAttribution.lua` | MODIFY (chain existing CTU handler) |
| `Core/Init.lua` | MODIFY (event registration, init sequence) |
| `Core/Defaults.lua` | MODIFY (add designationLog subtable) |
| `TrueStrike.toc` | MODIFY (add load order entries) |

---

## E) FEATURE FLAGS

All flags live in `TS_DesigConfig` in `Parser/TS_DesigConfig.lua`.

| Flag | Default | Basis |
|------|---------|-------|
| `TRUESTRIKE_CAST_ANCHOR_ENABLED` | `true` | CONFIRMED — SENT/SUCCEEDED castGUID correlation, 13/13 sessions |
| `TRUESTRIKE_HOT_SLOT_LIFECYCLE` | `true` | CONFIRMED — lease-clock lifecycle reliable in instanced combat |
| `TRUESTRIKE_TYPE_GATE` | `true` | CONFIRMED — Voltaic Blaze stable across 1,073 events |
| `TRUESTRIKE_SPELLBOOK_SCAN` | `true` | CONFIRMED — SPELLS_CHANGED scan with spellbookScanned flag |
| `TRUESTRIKE_PRECOMBAT_AURA_SCAN` | `true` | CONFIRMED — pre-combat UnitAura snapshot |
| `TRUESTRIKE_SYNTHETIC_TOTEM_SLOTS` | `true` | CONFIRMED — HST ticks correctly attributed v12 |
| `TRUESTRIKE_KNOWN_SPELLS_OVERRIDE` | `true` | CONFIRMED — Restoration Shaman seed table complete |
| `TRUESTRIKE_UNIT_COMBAT_PROBE` | `false` | FLAGGED 1 — Outcome A confirmed; no outgoing melee path exists |
| `TRUESTRIKE_MELEE_ATTRIBUTION` | `false` | FLAGGED 1 — gated on future probe result |
| `TRUESTRIKE_AURA_INSTANCE_PROBE` | `false` | FLAGGED 2 — Q2 verdict unverified |
| `TRUESTRIKE_INCOMBAT_HOT_CREATION` | `false` | FLAGGED 2 — depends on aura instance probe |
| `TRUESTRIKE_INCOMING_HEAL_PROBE` | `false` | FLAGGED 3 — entirely untested |
| `TRUESTRIKE_CLASS_DB_DRUID` | `false` | FLAGGED 5 — no discovery data |
| `TRUESTRIKE_CLASS_DB_PRIEST` | `false` | FLAGGED 5 — no discovery data |
| `TRUESTRIKE_CLASS_DB_PALADIN` | `false` | FLAGGED 5 — no discovery data |
| `TRUESTRIKE_CLASS_DB_MONK` | `false` | FLAGGED 5 — no discovery data |
| `DEBUG_LOGGING` | `false` | Verbosity gate |

FLAGGED flags must have their corresponding `FLAGGED:` comment block in the code as described in Section B.

---

## F) LOGGING

All Designation Engine logs use structured string format, written to both `print()` (when `DEBUG_LOGGING` is true) and the appropriate `designationLog` subtable in SavedVariables.

Required log prefixes by module:

| Module | Prefix |
|--------|--------|
| TS_DesigConfig | `[TS_CFG]` |
| TS_Taint | `[TS_TAINT]` |
| TS_Registry | `[TS_REG]` |
| TS_SlotManager | `[TS_SLOT]` |
| TS_SpellbookScanner | `[TS_BOOK]` |
| TS_AuraScanner | `[TS_AURA]` |
| TS_CastAnchor | `[TS_ANCHOR]` |
| TS_CTURouter | `[TS_CTU]` |

Required log event shapes — match these field names exactly, as post-session analysis depends on consistency:

```
CAST_ANCHOR       {spellID, castGUID, target, desig, timestamp}
HOT_SLOT_CREATED  {slotID, spellID, unit, expirationTime, source}
HOT_SLOT_EXPIRED  {slotID, spellID, tickCount}
TICK_ATTRIBUTED   {slotID, spellID, ctuType, confidence, deltaPrev}
CTU_CAPTURED      {seq, ctuType, valueStr, correlatedSpellID, desig}
SPELL_PROMOTED    {spellID, fromDesig, toDesig, confidence, source}
TYPE_GATE_FIRED   {spellID, requestedDesig, currentDesig, blocked}
UNKNOWN_OBSERVED  {spellID, spellName, ctuType, timestamp}
TAINT_ERROR       {function, error, context}
SESSION_END       {totalCTU, promotionCount, unknownCount, taintErrors, slotCount, meleeCount, timestamp}
```

Use `string.format` for all log line construction. Do not concatenate secret values into log strings — `valueStr` is already safe (converted via SafeStr before log time).

---

## G) DONE MEANS

Integration is complete when ALL of the following are true:

1. **Addon loads without Lua errors** — `/reload` produces no error dialog.
2. **No ZZ_ runtime references** — grep Parser/ and Core/ for `ZZ_` and find zero results in any `require`, function call, or variable reference.
3. **All FLAGGED comment blocks present** — grep for `TRUESTRIKE_MELEE_ATTRIBUTION`, `TRUESTRIKE_AURA_INSTANCE_PROBE`, `TRUESTRIKE_INCOMBAT_HOT_CREATION`, `TRUESTRIKE_INCOMING_HEAL_PROBE`, and `TRUESTRIKE_UNIT_COMBAT_PROBE`. Each must have an adjacent `FLAGGED:` comment block.
4. **All DISPROVEN tombstones present** — grep for `DISPROVEN:` and confirm blocks exist for: arithmetic on CTU value, `tonumber` on CTU value, secret value as table key, string laundering, `GetBuffDataByIndex` in combat, `isFromPlayerOrPlayerPet` in combat, `sourceUnit == "player"` aura comparison.
5. **CONFIRMED integration compiles and flags are wired** — with all CONFIRMED flags at `true`, entering combat and casting Riptide produces `HOT_SLOT_CREATED`, `TICK_ATTRIBUTED`, and `CTU_CAPTURED` entries in `designationLog`.
6. **Earth Shield stays Proc** — no `HOT_SLOT_CREATED` for spellIDs 974, 383648, or 379.
7. **Voltaic Blaze stays Damage_AoE** — no `SPELL_PROMOTED` for spellID 470411.
8. **150ms window is not user-configurable** — `PROMOTION_WINDOW_SECONDS` is a hardcoded constant, not in SavedVariables, not in the options UI.
9. **Version strings consistent** — TOC version, `SESSION_START` version field in the session summary, and any print-on-load version string all match.
10. **`designationLog` persists across reloads** — after `/reload`, the log table survives in SavedVariables and is not wiped on re-init.

Items gated behind FLAGGED flags (melee attribution, in-combat HoT creation, non-self heals) are **explicitly excluded** from Done Means for this integration. They are separate feature tracks.
