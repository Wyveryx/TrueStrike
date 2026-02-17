# TrueStrike Battle Text - Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- **WoW 12.0 Midnight Compliance**: Secret Values-aware combat log processing
- CombatLogGetCurrentEventInfo() returns table with named keys (WoW 12.0 behavior)
- Named key access for combat log info table (info.amount, info.subEvent, etc.)
- Combat lockdown protection for parser enable/disable operations
- PLAYER_ENTERING_WORLD event-based parser initialization (always fires outside combat)
- Frame creation at module load time to avoid taint during protected loading
- Incoming damage/healing detection via UNIT_COMBAT event
- Outgoing damage/healing detection via COMBAT_LOG_EVENT_UNFILTERED
- Event normalization for incoming and outgoing combat events
- Support for auto-attack detection and filtering modes
- Critical strike detection for damage and healing events
- Overheal tracking for healing events
- Error Resolutions.md documentation for troubleshooting common issues

### Changed
- **BREAKING (WoW 12.0)**: CombatLog_Detect.lua uses CombatLogGetCurrentEventInfo() with named keys
- **BREAKING (WoW 12.0)**: Outgoing_Detect.lua uses named keys instead of positional indexing
- **BREAKING (WoW 12.0)**: Incoming_Detect.lua uses named keys instead of positional indexing
- **BREAKING (WoW 12.0)**: Removed all tonumber() calls on Secret Values (info.amount, info.critical)
- **BREAKING (WoW 12.0)**: Removed numeric comparisons and math on damage/heal amounts
- **BREAKING (WoW 12.0)**: Removed overheal zeroing logic (Secret Value manipulation)
- Parser modules now respect InCombatLockdown() for safe event registration
- Moved frame creation from Enable() methods to module load scope
- Init.lua uses PLAYER_ENTERING_WORLD instead of OnUpdate for parser enable
- Incoming_Detect.lua event handler setup moved to module load time
- Combat log event handler signature: function(self, event, info) instead of varargs

### Fixed
- **WoW 12.0 Midnight compatibility** - Uses standard RegisterEvent (SecureFrameTemplate not needed)
- **Secret Values violations** - removed all arithmetic/comparisons on info.amount and info.critical
- Combat lockdown taint errors when enabling parsers during combat
- Bazooka addon compatibility - frames created at module load, not in Enable()
- Parser enable/disable race conditions during combat state changes
- ADDON_ACTION_FORBIDDEN errors from RegisterEvent during protected loading

### Deprecated
- **Positional unpacking** of combat log info table (use named keys instead)
- **tonumber() on Secret Values** - Blizzard now returns display-ready values
- **Numeric gating on amounts** - moved responsibility to display layer

### Technical Debt
- Display layer (ScrollAreaFrames.lua) must handle Secret Values properly:
  - Pass info.amount directly to text objects without manipulation
  - Use info.critical for truthy checks only (no numeric comparison)
  - Implement overheal hiding via formatting/visibility, not value zeroing
- If visual scaling by amount needed, user must provide C_CurveUtil implementation
- Consider server-side damage meter API as future enhancement for cross-player data

---

## [0.2.0] - 2026-02-15

### Added
- CHANGELOG.md for version tracking
- Initial changelog infrastructure setup

### Changed
- Established systematic release note workflow
- Documentation structure for tracking addon changes

---

## [0.1.1] - 2026-02-14

### Fixed
- Initial bug fixes and stability improvements

---

## [0.1.0] - 2026-02-13

### Added
- Initial release of TrueStrike Battle Text
- Core addon framework using Ace3
- Basic configuration UI with tabs
- Minimap button integration
- Profile system via AceDB
- Slash commands (/tsbt, /truestrike)
- Debug logging system
- LibSharedMedia-3.0 integration for fonts

### Notes
- Most parser and core modules are skeletal implementations
- UI framework established but combat text display needs implementation

