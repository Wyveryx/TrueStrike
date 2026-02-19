# TrueStrike Battle Text - Master Developer Guide
**Current Version:** 0.3.0 | **WoW Interface:** 120000, 120001 (The War Within / Midnight)

## 1. Project Overview & Architecture
TrueStrike provides accurate floating combat text with confidence-based attribution. It bypasses WoW 12.0's API restrictions using `COMBAT_TEXT_UPDATE` passthrough logic.

**Core Layers:**
1. **Parser Layer:** Detects and normalizes WoW events (`Incoming_Detect.lua`, `Outgoing_Detect.lua`).
2. **Core Layer:** Decision logic and coordination (`Core.lua`, `Combat_Decide.lua`).
3. **UI Layer:** Renders the text via Ace3 (`ScrollAreaFrames.lua`).

**Load Order (Strict):**
Libs -> Core Fundamentals (Constants, Defaults) -> Core Coordination -> Parser Modules -> UI Modules.

---

## 2. WoW 12.0 "Secret Values" Constraints (CRITICAL)
WoW 12.0 heavily restricts combat log payloads. Values like `info.amount` or `arg3` are **Secret Values**. They can be displayed, but NOT processed.

* **DO NOT** perform arithmetic (`+`, `-`, etc.) on combat amounts.
* **DO NOT** use `tonumber()` on Secret Values.
* **DO NOT** use comparison operators (`==`, `>`, `<`) on amounts or caster names (`data`).
* **DO:** Pass values directly to UI elements using `tostring()`. (e.g., `fontString:SetText(tostring(arg3))`).
* **DO:** Treat `info.critical` as a truthy/falsey flag only.
* **DO:** Use named keys from payloads instead of positional unpacking when using CLEU.

---

## 3. The CTU Passthrough System
Because of Secret Values, TrueStrike relies on `COMBAT_TEXT_UPDATE` (CTU) combined with `C_CombatText.GetCurrentEventInfo()`. 

**What CTU Can Do:**
* Provides `data` (caster name), `arg3` (amount), `arg4` (extra).
* Fires for self-heals, incoming heals, energize events, and indirect effects (e.g., Earth Shield reporting back).
* Works independently of Blizzard's Floating Combat Text (`enableFloatingCombatText = 0`).

**What CTU Cannot Do:**
* Does **not** fire for outgoing damage.
* Does **not** fire for direct heals on other players.
* Does **not** provide the spell name.

---

## 4. Spell Attribution & Event Timing
Because CTU doesn't provide the spell name, TrueStrike must correlate CTU events with `UNIT_SPELLCAST` events.

**The Proven Event Order:**
1.  `UNIT_SPELLCAST_SENT`: Fires immediately. (Use this to queue instant casts like Riptide).
2.  `UNIT_SPELLCAST_START`: Fires as cast bar begins. (Use this for cast-time spells like Healing Wave).
3.  `COMBAT_TEXT_UPDATE` (CTU): The heal lands and the amount is passed through.
4.  `UNIT_SPELLCAST_SUCCEEDED`: **Fires AFTER the CTU event.** Do not use this to pre-populate attribution queues.

**HoT Tracking Strategy:**
Use `UNIT_AURA` to track active HoTs on the player. When a `PERIODIC_HEAL` CTU fires, check the active aura list to attribute the tick.

---

## 5. Taint & Combat Lockdown Rules (Error Resolution)
To prevent `ADDON_ACTION_FORBIDDEN` errors, follow strict lifecycle rules:
* **Frame Creation:** Create parser frames at the **module/file scope** during load time. NEVER create a frame inside an `Enable()` function.
* **Registration:** Only use `RegisterEvent` / `UnregisterEvent` inside `Enable()` / `Disable()`.
* **Combat Checks:** If `InCombatLockdown()` is true during `Enable()`, defer the registration by hooking `PLAYER_REGEN_ENABLED`.
* **Initialization Point:** Use `PLAYER_ENTERING_WORLD` to safely activate parsers, as it always fires outside of combat after the protected loading sequence completes.