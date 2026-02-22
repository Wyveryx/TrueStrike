# TrueStrike (UI Shell Milestone)

This milestone provides a **custom UI shell**, runtime **scroll area frames**, and a synthetic **test harness**.
No combat parsing or attribution is implemented in this build.

## Setup
1. Copy this addon folder to: `Interface/AddOns/TrueStrike`
2. Drop in these library folders at addon root:
   - `TrueStrike/Ace3/` (full Ace3 distribution)
   - `TrueStrike/LibSharedMedia-3.0-v11.2.1/` (wrapper folder containing `LibSharedMedia-3.0/`)
3. Run `/reload`
4. Run `/truestrike` (or `/ts`) to open the UI shell
5. Go to **ScrollAreas** tab, enable areas, and use **Test Normal / Test Crit**

## Implemented
- LCARS-like custom shell with left navigation and content panels.
- General tab with persisted master settings and profile operations.
- Scroll Areas tab with group/area selectors, runtime unlock/move/resize, and per-area controls.
- Lightweight scroll engine (`UP`, `DOWN`, `PARABOLA`) with crit effects (`WIGGLE`, `POW`, `FLASH`).
- Test harness spawning synthetic normal/crit messages to all enabled areas.

## Notes
- LibSharedMedia is optional at load time. If missing, font/sound pickers are disabled and a message is printed.
- `disableBlizzardFCT` is currently stored only (not actively applied).
