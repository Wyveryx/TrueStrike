# TrueStrike Development Guide

## WoW 12.0 Midnight Combat API Constraints

WoW 12.0 returns combat log data as a table from `CombatLogGetCurrentEventInfo()`.
Treat the returned values as display-oriented data and avoid assumptions that they are plain numbers.

### Required Patterns
- Use named keys from combat log payloads (for example: `info.subEvent`, `info.amount`, `info.critical`).
- Prefer handler signatures that accept the `info` table directly (`function(self, event, info)`).
- Keep parser event lifecycle safe:
  - Respect `InCombatLockdown()` when registering/unregistering parser events.
  - Create frames at module/file scope rather than inside `Enable()`.
  - Use `PLAYER_ENTERING_WORLD` as the safe initialization point for parser activation.

## Breaking Changes and Migration Rules (WoW 12.0)

The parser stack now follows the constraints below:
- `CombatLog_Detect.lua`, `Incoming_Detect.lua`, and `Outgoing_Detect.lua` consume named-key payloads instead of positional unpacking.
- Secret Value fields must not be force-cast with `tonumber()`.
- Do not run numeric comparisons or arithmetic directly on Secret Value-backed combat amount fields.
- Do not zero/normalize overheal via numeric mutation in parser layers.

## Deprecated Patterns (Do Not Reintroduce)

- Positional unpacking of combat log tables.
- `tonumber()` calls on Secret Value-backed combat values.
- Numeric gating at parser layer for amount acceptance/rejection.

## Display Layer Guidance (UI/ScrollAreaFrames.lua)

Display code is responsible for formatting behavior when Secret Values are involved.

### Current Guidance
- Pass `info.amount` through to text/render objects without arithmetic coercion.
- Treat `info.critical` as a truthy/falsey flag only.
- Hide or format overheal in presentation logic rather than mutating value payloads.

### Future Considerations
- If magnitude-based visual scaling is required, gate it behind an explicit `C_CurveUtil` path.
- Keep room for a future server-side damage-meter integration path for cross-player metrics.
