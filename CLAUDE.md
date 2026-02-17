# TrueStrike Development Guide

This file provides context and guidelines for working on the TrueStrike addon with Claude Code.

## Project Overview

**TrueStrike Battle Text** is a World of Warcraft addon that provides accurate floating combat text with confidence-based attribution. It displays combat events in real-time with sophisticated damage/heal tracking and attribution logic.

- **Current Version**: 0.2.0
- **WoW Interface**: 120000, 120001 (The War Within)
- **Repository**: https://github.com/Wyveryx/TrueStrike
- **Primary Language**: Lua (WoW AddOn)

## Project Structure

```
TrueStrike/
├── Core/                  # Core logic and coordination
│   ├── Constants.lua      # Game constants, spell IDs, thresholds
│   ├── Defaults.lua       # Default configuration values
│   ├── Init.lua           # Addon initialization
│   ├── Diagnostics.lua    # Debug and logging utilities
│   ├── Core.lua           # Main addon coordination
│   ├── Display_Decide.lua # Display decision logic
│   ├── Combat_Decide.lua  # Combat state decisions
│   ├── Cooldowns_Decide.lua # Cooldown tracking decisions
│   ├── Incoming_Probe.lua # Incoming damage analysis
│   ├── Outgoing_Probe.lua # Outgoing damage analysis
│   └── MinimapButton.lua  # Minimap button interface
├── Parser/                # Event detection and parsing
│   ├── Normalize.lua      # Event normalization
│   ├── CombatLog_Detect.lua # Combat log event detection
│   ├── Cooldowns_Detect.lua # Cooldown detection
│   ├── Incoming_Detect.lua  # Incoming event detection
│   └── Outgoing_Detect.lua  # Outgoing event detection
├── UI/                    # User interface components
│   ├── Config.lua         # Configuration UI assembly
│   ├── ConfigTabs.lua     # Configuration tab definitions
│   └── ScrollAreaFrames.lua # Scrolling combat text frames
├── Libs/                  # Third-party libraries (Ace3, LibSharedMedia)
├── TrueStrike.toc        # AddOn manifest file
├── README.md             # User-facing documentation
└── CHANGELOG.md          # Version history

```

## Architecture

TrueStrike follows a **separation of concerns** pattern:

1. **Parser Layer** - Detects and normalizes WoW combat log events
2. **Core Layer** - Makes decisions about what to display and when
3. **UI Layer** - Renders the actual combat text and configuration interface

### Key Design Principles

- **Confidence-Based Attribution**: Uses probability scoring to attribute damage/healing to the correct source
- **Event Normalization**: Converts WoW's complex combat log events into consistent internal formats
- **Modular Architecture**: Each module handles a specific concern (incoming, outgoing, cooldowns, etc.)
- **Ace3 Framework**: Uses Ace3 libraries for addon structure, config, and DB management

## Development Workflow

### Load Order (from .toc)

The `.toc` file defines the exact load order. Files are loaded sequentially:

1. **Libraries** (LibStub, Ace3, LibSharedMedia)
2. **Core Fundamentals** (Constants → Defaults → Init → Diagnostics)
3. **Core Coordination** (Core.lua and decision modules)
4. **Parser Modules** (Detection and normalization)
5. **UI Modules** (ConfigTabs → Config → ScrollAreaFrames)

**Important**: Never change the load order without understanding dependencies.

### Common Tasks

#### Adding a New Feature
1. Identify which layer (Parser/Core/UI) the feature belongs to
2. Create/modify the appropriate module file
3. Update the `.toc` if adding new files
4. Test in-game with `/tsbt` to open config
5. Update version in `.toc` and `README.md`

#### Debugging
- Use `Core/Diagnostics.lua` for logging utilities
- Enable debug mode via `/tsbt` config
- Check for Lua errors in WoW's error display

#### Configuration
- Config structure defined in `Core/Defaults.lua`
- UI tabs defined in `UI/ConfigTabs.lua`
- Assembly happens in `UI/Config.lua`

## Conventions

### Code Style
- **Indentation**: Tabs (consistent with existing codebase)
- **Naming**: PascalCase for files, camelCase for functions, UPPER_CASE for constants
- **Comments**: Use `--` for single-line, `--[[ ]]--` for multi-line blocks
- **Event Handlers**: Prefix with `On` (e.g., `OnCombatLogEvent`)

### Git Workflow
- Work in Claude-managed worktrees (current: `blissful-vaughan`)
- Commit messages: Use conventional format with co-author attribution
- PRs target `main` branch

### Version Numbering
- Format: `MAJOR.MINOR.PATCH-stage` (e.g., `0.2.0-alpha`)
- Update in: `.toc` (Version field), `README.md`, `CHANGELOG.md`

## Important Context

### WoW API Specifics
- Uses WoW's `COMBAT_LOG_EVENT_UNFILTERED` for combat events
- Frame-based UI system (CreateFrame, SetScript, etc.)
- SavedVariables: `TrueStrikeDB` persists config across sessions
- Slash command: `/tsbt` registered in Core

### Current State
- **Version 0.2.0+**: Active development on parser layer
- **Parser Layer Status**:
  - ✅ Incoming_Detect.lua - Fully implemented with UNIT_COMBAT event handling
  - ⚠️ Outgoing_Detect.lua - Implemented with COMBAT_LOG_EVENT_UNFILTERED (pending WoW 12.0 API verification)
  - ✅ Combat lockdown protection implemented in both parsers
  - ✅ Frame creation at module load time (taint-safe)
  - ⚠️ CombatLog_Detect.lua - Stub (needs implementation)
  - ⚠️ Cooldowns_Detect.lua - Stub (needs implementation)
  - ⚠️ Normalize.lua - Stub (normalization currently inline in parsers)
- **Core Layer Status**:
  - ✅ Init.lua - Full implementation with PLAYER_ENTERING_WORLD initialization
  - ✅ Taint mitigation via module-scope frame creation
  - ⚠️ Core.lua - Skeleton (needs decision routing implementation)
  - ⚠️ IncomingProbe/OutgoingProbe - Stubs (need capture/replay logic)
  - ⚠️ Display_Decide.lua - Stub (needs implementation)
- **UI Layer Status**:
  - ✅ Config framework established via Ace3
  - ⚠️ ScrollAreaFrames.lua - Needs combat text rendering implementation
- **Known Blockers**:
  - 🚫 WoW 12.0 Midnight API restrictions on COMBAT_LOG_EVENT_UNFILTERED (requires investigation/alternative approach)

### Known Dependencies
- **Ace3**: Addon framework (AceAddon, AceConfig, AceDB, etc.)
- **LibSharedMedia-3.0**: Font and texture sharing
- **LibStub**: Library versioning system

## Decision Log

### 2026-02-15: Changelog Infrastructure
- **Decision**: Added `CHANGELOG.md` for version tracking
- **Rationale**: Need structured way to track changes across releases
- **Impact**: Sets up sustainable release note workflow

### 2026-02-16: Parser Layer Implementation & Taint Mitigation
- **Decision**: Implemented core parser modules (Incoming_Detect, Outgoing_Detect)
- **Rationale**: Need working event detection before building decision/display layers
- **Implementation Details**:
  - Added combat lockdown protection to prevent taint errors
  - Implemented deferred initialization using PLAYER_ENTERING_WORLD
  - Moved frame creation to module load time (file scope) instead of lazy creation in Enable()
  - Incoming parser uses UNIT_COMBAT event (player-only, no GUID usage)
  - Outgoing parser uses COMBAT_LOG_EVENT_UNFILTERED with player source filtering
- **Impact**: Parsers now functional and safe during combat/addon interaction
- **Taint Lessons Learned**:
  - RegisterEvent/UnregisterEvent cannot be called during InCombatLockdown()
  - Bazooka (and similar broker addons) can create tainted call stacks
  - Frame creation must happen at module load time, NOT in Enable() methods
  - PLAYER_ENTERING_WORLD is the safest initialization point (always outside combat, after protected loading)
  - C_Timer.After() does NOT escape taint - it only delays execution in same context

### 2026-02-16: WoW 12.0 Midnight API Restrictions Discovery
- **Issue**: ADDON_ACTION_FORBIDDEN errors when registering COMBAT_LOG_EVENT_UNFILTERED
- **Root Cause**: WoW 12.0 (Midnight expansion) introduced severe restrictions to combat log APIs
- **Blizzard's Changes**:
  - Introduced "secret values" system - combat events can be displayed but not processed for automated decisions
  - COMBAT_LOG_EVENT_UNFILTERED may now be protected and restricted during addon loading
  - Server-side damage meter is now the primary data source (Details! and others now interface with this)
  - Enemy player information hidden via secret values (GUIDs, names, classes, etc.)
  - Combat log still available for external analysis (Warcraft Logs), but restricted in-game
- **TrueStrike Requirements** (will need alternative approaches):
  - ✅ Player's own outgoing damage/healing (including auto-attacks)
  - ✅ Pet/totem/guardian damage and healing
  - ✅ Incoming damage to player (from enemies)
  - ⚠️ **Challenge**: May need heuristic methods due to CLEU restrictions
- **Potential Solutions** (to be investigated):
  1. **Blizzard's Server-Side Damage Meter API**: Interface with built-in damage meter (Details! approach)
  2. **Hybrid Event Approach**:
     - UNIT_COMBAT for incoming damage (already working)
     - UNIT_HEALTH/UNIT_POWER changes for damage heuristics
     - Visual combat feedback parsing
  3. **Test CLEU Player-Only Access**: Verify if player's own data still accessible via COMBAT_LOG_EVENT_UNFILTERED
- **Status**: Under active investigation - next step is testing current implementation after taint fixes
- **References**:
  - [Blizzard's Combat Philosophy - Midnight](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight)
  - [Patch 12.0.0 API Changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes)
  - [Damage Meter Shortcomings - Wowhead](https://www.wowhead.com/news/blizzards-damage-meter-shortcomings-in-midnight-pre-patch-and-addon-alternatives-379992)

### Session Context (2026-02-15)
- Created `CLAUDE.md` to maintain project context across Claude Code sessions
- Established documentation structure for development workflow
- Added CHANGELOG.md infrastructure

## Future Considerations

### Potential Enhancements
- Implement actual combat text display logic (currently skeletal)
- Add more sophisticated attribution algorithms
- Performance optimization for high-event-rate scenarios
- Support for custom fonts/textures via LibSharedMedia
- Profile system for different characters/specs

### Technical Debt
- **CRITICAL**: WoW 12.0 Midnight API compatibility - need to verify/replace COMBAT_LOG_EVENT_UNFILTERED approach
  - May require complete parser redesign using Blizzard's server-side damage meter API
  - Or hybrid heuristic approach (UNIT_HEALTH, UNIT_POWER, visual feedback)
- Core decision modules (Display_Decide, Combat_Decide, Cooldowns_Decide) need implementation
- Probe modules (IncomingProbe, OutgoingProbe) need capture/replay logic
- ScrollAreaFrames needs combat text rendering implementation
- CombatLog_Detect and Cooldowns_Detect parsers need implementation
- Consider extracting inline normalization to Normalize.lua module
- Need comprehensive testing framework
- Documentation could be expanded with inline API docs
- Consider performance profiling tools

## Resources

- **WoW API Documentation**: https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
- **Ace3 Documentation**: https://www.wowace.com/projects/ace3
- **Combat Log Documentation**: https://wowpedia.fandom.com/wiki/COMBAT_LOG_EVENT

## Notes for Claude

- Always check `.toc` load order before modifying file structure
- Test changes in-game when possible (requires WoW client)
- Respect existing architecture patterns (Parser/Core/UI separation)
- Update version numbers in all relevant files when making releases
- Use git worktree workflow for all changes
- Add co-author attribution in commits: `Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>`
- **Combat Lockdown Rules**:
  - Never call RegisterEvent/UnregisterEvent during InCombatLockdown()
  - Always defer with PLAYER_REGEN_ENABLED when in combat
  - ❌ C_Timer.After() does NOT escape taint - only delays in same context
  - ✅ Use PLAYER_ENTERING_WORLD for safe initialization (always outside combat, after protected loading)
  - Test with Bazooka or similar broker addons installed
- **Parser Implementation Pattern**:
  - Use `_enabled` flag to track actual registration state
  - Use `_wantEnabled` flag to track desired state during lockdown
  - Implement Enable()/Disable() methods with lockdown checks
  - **CRITICAL**: Create frames at module load time (file scope), NOT in Enable() methods
  - Set up event handlers at module load time, register/unregister events in Enable/Disable
- **WoW 12.0 Midnight API Awareness**:
  - COMBAT_LOG_EVENT_UNFILTERED may be protected/restricted in 12.0+
  - Always verify combat log access for player-only data
  - Be prepared to pivot to alternative data sources (server-side damage meter API, heuristics)
  - See "WoW 12.0 Midnight API Restrictions Discovery" in Decision Log for details
