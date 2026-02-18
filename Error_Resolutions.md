# TrueStrike Error Resolutions

## Error #2: WoW 12.0 Secret Value Misuse in Combat Events

### Symptoms
- Runtime instability or invalid comparisons when handling combat event amounts/critical flags.
- Parser logic behaving unpredictably when assuming numeric combat payloads.

### Root Cause
WoW 12.0 Midnight changed combat event behavior so key fields (for example `info.amount`, `info.critical`) can behave as Secret Value/display-oriented data rather than plain numeric scalars. Legacy parser logic attempted numeric conversion and arithmetic in places that now violate those constraints.

### Resolution
- Switched parser consumption to named-key payload access from `CombatLogGetCurrentEventInfo()`.
- Removed `tonumber()` casts on Secret Value-backed fields.
- Removed direct numeric comparisons/arithmetic on parser-side combat amount fields.
- Removed parser-side overheal zeroing/value mutation behavior.

### Status
**✅ FIXED** - 2026-02-17

### Prevention Checklist
- Never reintroduce `tonumber(info.amount)`-style casts in parser/detection code.
- Keep amount gating/formatting decisions in display logic where possible.
- Validate new parser work against WoW 12.0 named-key + Secret Value constraints.
