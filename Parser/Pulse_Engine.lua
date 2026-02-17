local ADDON_NAME, TSBT = ...

TSBT.Parser = TSBT.Parser or {}
TSBT.Parser.PulseEngine = TSBT.Parser.PulseEngine or {}
local Engine = TSBT.Parser.PulseEngine

local StateManager = TSBT.Parser.StateManager
local CorrelationLogic = TSBT.Parser.CorrelationLogic

Engine._enabled = Engine._enabled or false
Engine._pulseInterval = 0.020 -- 20ms target pulse (phase 1 requirement)
Engine._accumulator = Engine._accumulator or 0
Engine._bucket = Engine._bucket or {}
Engine._frame = Engine._frame or nil
Engine._maxBucketSize = Engine._maxBucketSize or 120
Engine._maxWorkPerPulse = Engine._maxWorkPerPulse or 80

local function now()
	return (GetTime and GetTime()) or 0
end

local function wipeTable(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

function Engine:collect(eventType, payload)
	if not self._enabled then return end
	if not eventType or not payload then return end

	local bucket = self._bucket
	if #bucket >= self._maxBucketSize then
		-- Drop oldest entries in overflow scenarios to protect frame budget.
		table.remove(bucket, 1)
	end

	payload.eventType = eventType
	bucket[#bucket + 1] = payload
end

function Engine:_emitOutgoing(ev)
	local parser = TSBT.Parser and TSBT.Parser.Outgoing
	if parser and parser.ProcessEvent then
		parser:ProcessEvent(ev)
	end
end

function Engine:_processSpellcast(sample)
	if not StateManager then return end
	if not sample then return end

	StateManager:createCastState(sample.spellId, sample.spellName, sample.unit, sample.timestamp, 0.50)
end

function Engine:_processHealthDamage(sample)
	if not sample or not CorrelationLogic or not StateManager then return end

	local activeCasts = StateManager:getActiveCasts()
	local bestCast, confidence = CorrelationLogic:findBestCast(activeCasts, sample)
	if bestCast and confidence ~= CorrelationLogic.CONFIDENCE.UNKNOWN then
		StateManager:markMatched(bestCast, sample)
	end

	local normalized = {
		kind = "damage",
		amount = sample.amount,
		spellName = bestCast and bestCast.spellName or nil,
		spellId = bestCast and bestCast.spellId or nil,
		targetName = sample.targetName,
		isCrit = sample.isCrit,
		timestamp = sample.timestamp,
		confidence = confidence or CorrelationLogic.CONFIDENCE.UNKNOWN,
		isPeriodic = sample.isPeriodic == true,
	}

	self:_emitOutgoing(normalized)
end

function Engine:_processHealthChangeSecret(sample)
	if not sample or not CorrelationLogic or not StateManager then return end

	sample.isSecret = true
	local activeCasts = StateManager:getActiveCasts()
	local bestCast, confidence = CorrelationLogic:findBestCast(activeCasts, sample)

	local normalized = {
		kind = "damage",
		amount = nil,
		spellName = bestCast and bestCast.spellName or nil,
		spellId = bestCast and bestCast.spellId or nil,
		targetName = sample.targetName,
		isCrit = false,
		timestamp = sample.timestamp,
		confidence = confidence or CorrelationLogic.CONFIDENCE.UNKNOWN,
		isPeriodic = false,
	}

	self:_emitOutgoing(normalized)
end

function Engine:_processHealth(_)
	-- General health change marker retained for future multi-signal heuristics.
end

function Engine:flushBucket()
	local bucket = self._bucket
	if #bucket == 0 then return end

	local work = math.min(#bucket, self._maxWorkPerPulse)
	for i = 1, work do
		local sample = bucket[i]
		if sample then
			if sample.eventType == "SPELLCAST_SUCCEEDED" then
				self:_processSpellcast(sample)
			elseif sample.eventType == "HEALTH_DAMAGE" then
				self:_processHealthDamage(sample)
			elseif sample.eventType == "HEALTH_CHANGE_SECRET" then
				self:_processHealthChangeSecret(sample)
			elseif sample.eventType == "UNIT_HEALTH" then
				self:_processHealth(sample)
			end
		end
	end

	if work >= #bucket then
		wipeTable(bucket)
	else
		for i = 1, (#bucket - work) do
			bucket[i] = bucket[i + work]
		end
		for i = #bucket, (#bucket - work + 1), -1 do
			bucket[i] = nil
		end
	end

	StateManager:expireStaleStates(now())
end

function Engine:_onUpdate(elapsed)
	self._accumulator = self._accumulator + (elapsed or 0)
	if self._accumulator < self._pulseInterval then
		return
	end

	-- Preserve overrun remainder rather than zeroing for stable pacing.
	self._accumulator = self._accumulator - self._pulseInterval
	self:flushBucket()
end

function Engine:Enable()
	if self._enabled then return end

	if not self._frame then
		self._frame = CreateFrame("Frame")
	end

	self._frame:SetScript("OnUpdate", function(_, elapsed)
		Engine:_onUpdate(elapsed)
	end)
	self._enabled = true
end

function Engine:Disable()
	if not self._enabled then return end
	if self._frame then
		self._frame:SetScript("OnUpdate", nil)
	end
	self._enabled = false
	self._accumulator = 0
	wipeTable(self._bucket)
	if StateManager then
		StateManager:clear()
	end
end
