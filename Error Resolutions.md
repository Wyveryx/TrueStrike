# TrueStrike Error Resolutions

## Error #1: ADDON_ACTION_FORBIDDEN - RegisterEvent() During Addon Load

### Original Error:
```
14x [ADDON_ACTION_FORBIDDEN] AddOn 'TrueStrike' tried to call the protected function 'Frame:RegisterEvent()'.
[!BugGrabber/BugGrabber.lua]:586: in function '?'
[!BugGrabber/BugGrabber.lua]:510: in function <!BugGrabber/BugGrabber.lua:510>
[C]: in function 'RegisterEvent'
[TrueStrike/Parser/Outgoing_Detect.lua]:152: in function 'Enable'
[TrueStrike/Core/Init.lua]:88: in function <TrueStrike/Core/Init.lua:72>
[C]: ?
[Bazooka/libs/Ace3/AceAddon-3.0-13/AceAddon-3.0.lua]:66: in function <...dOns/Bazooka/libs/Ace3/AceAddon-3.0/AceAddon-3.0.lua:61>
[Bazooka/libs/Ace3/AceAddon-3.0-13/AceAddon-3.0.lua]:523: in function 'EnableAddon'
[Bazooka/libs/Ace3/AceAddon-3.0-13/AceAddon-3.0.lua]:626: in function <...dOns/Bazooka/libs/Ace3/AceAddon-3.0/AceAddon-3.0.lua:611>
```

### Root Cause:
The Ace3 `OnEnable()` callback runs during the protected addon loading sequence. Even though we're using `OnUpdate` to defer the actual `RegisterEvent()` call, the **frame creation itself** (`CreateFrame("Frame")`) happens inside `OnEnable()`, which is running in a tainted/protected context.

When addon loading happens during combat or in certain protected contexts (like after a `/reload` during combat), Blizzard's security model blocks **any** frame operations that could potentially call protected functions, including `RegisterEvent()`.

### Solution:

**Move frame creation to `OnInitialize()` instead of lazy-creating it in the parser Enable() method.**

The `OnInitialize()` hook fires **before** the protected loading sequence begins, so frame creation and initial event registration is safe. Then, only register/unregister events (not create frames) in the Enable/Disable methods.

#### Key Changes:
1. **Create the parser frame in `OnInitialize()`** (before PLAYER_LOGIN)
2. **Only register/unregister events** in Enable/Disable
3. **Keep the combat lockdown checks** for register/unregister operations
4. **Use `PLAYER_ENTERING_WORLD`** as an additional safe point to enable parsers (fires after all loading is complete and always outside combat)

#### Implementation Pattern:
```lua
-- In Parser/Outgoing_Detect.lua:
-- Create frame ONCE at file load (module scope, not in Enable)
local f = CreateFrame("Frame")
Outgoing._frame = f
Outgoing._enabled = false

-- In Enable(), only register events (don't create frame)
function Outgoing:Enable()
    if self._enabled then return end
    
    if InCombatLockdown() then
        -- defer until combat ends
        self._wantEnabled = true
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    
    f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self._enabled = true
end
```

#### Alternative: Use PLAYER_ENTERING_WORLD
```lua
-- In Init.lua OnEnable():
-- Instead of OnUpdate, register for PLAYER_ENTERING_WORLD which always fires outside combat
local enableFrame = CreateFrame("Frame")
enableFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
enableFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    
    if masterEnabled then
        if TSBT.Core and TSBT.Core.Enable then TSBT.Core:Enable() end
        EnableParsers()
    end
end)
```

### References:
- [WoW Wiki: InCombatLockdown](https://wowpedia.fandom.com/wiki/API_InCombatLockdown)
- [WoW Wiki: ADDON_ACTION_FORBIDDEN](https://wowpedia.fandom.com/wiki/ADDON_ACTION_FORBIDDEN)
- [WoW Wiki: Loading Process](https://wowwiki-archive.fandom.com/wiki/Loading_process)
- Key insight: `PLAYER_ENTERING_WORLD` fires after all protected loading is complete and always outside combat

### Status:
**✅ FIXED** - 2026-02-16

#### Implementation:
1. **Incoming_Detect.lua**: Moved frame creation from `Enable()` to module load scope (lines 24-27)
2. **Outgoing_Detect.lua**: Already had frame at module scope (line 109)
3. **Init.lua**: Changed from `OnUpdate` to `PLAYER_ENTERING_WORLD` event (lines 157-176)

#### Result:
- Frames are created during file load (safe, untainted context)
- Only event registration happens in Enable/Disable (respects combat lockdown)
- PLAYER_ENTERING_WORLD ensures parsers enable after all protected loading completes
- No more ADDON_ACTION_FORBIDDEN errors

