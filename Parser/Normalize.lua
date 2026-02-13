------------------------------------------------------------------------
-- TrueStrike - Parser Normalization Helpers (Skeleton)
-- Responsibility: normalize raw game data into a consistent event table.
------------------------------------------------------------------------
local ADDON_NAME, TSBT = ...

TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.Normalize = TSBT.Parser.Normalize or {}
local Normalize = TSBT.Parser.Normalize
local Addon     = TSBT.Addon

-- Create a normalized event shell (placeholder)
function Normalize:NewEvent(kind, payload)
    local evt = payload or {}
    evt.kind = kind or "UNKNOWN"

    -- Timestamp is optional; avoid forcing behavior.
    -- The parser may set it later using GetTime().
    return evt
end
