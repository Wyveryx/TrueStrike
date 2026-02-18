# TrueStrike Battle Text - Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- _No unreleased changes yet._

---

## [0.3.0] - 2026-02-17

### Added
- Pulse-based outgoing event correlation scaffold for combat text processing.
- Health-delta bootstrap and heal pulse routing support.
- Fall damage detection in parser event collection.
- Incoming spellcast queue correlation for better damage attribution.

### Changed
- Outgoing damage detection now uses `UNIT_HEALTH` correlation instead of `UNIT_COMBAT`.
- Self-healing events now pass through combat text event plumbing.

### Fixed
- Removed secret-string comparison in combat text heal handler to avoid invalid value checks.

### Merged Pull Requests (Complete History to Date)
- **#1** (2026-02-16) `design-pulse-based-event-correlation-engine-162ov9`
  - `ca9b0a7` Add pulse-based outgoing correlation engine scaffold.
  - `f02924c` Fix outgoing damage detection by switching to `UNIT_HEALTH` correlation.
  - `18fa9c0` Fix health-delta bootstrap and add health-heal pulse routing.
- **#2** (2026-02-17) `implement-self-healing-display-in-truestrike`
  - `df37324` Add self-heal passthrough via combat text events.
  - `2c1a890` Remove secret-string compare from combat text heal handler.
- **#3** (2026-02-17) `implement-fall-damage-detection-in-parser/event_collector.lu`
  - `957799e` Add fall damage detection to event collector.
- **#4** (2026-02-17) `add-spell-damage-attribution-to-incoming_detect`
  - `3b33f31` Add incoming spellcast queue correlation for damage attribution.

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
