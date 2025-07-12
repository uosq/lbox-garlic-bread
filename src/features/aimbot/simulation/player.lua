local sim = {}

local position_samples = {}
local velocity_samples = {}
local MAX_ALLOWED_SPEED = 2000 -- HU/sec
local SAMPLE_COUNT = 8

--- ngl im proud of this function
--- this little fella is the goat

---@class Sample
---@field pos Vector3
---@field time number

---@param pEntity Entity
local function AddPositionSample(pEntity)
	local index = pEntity:GetIndex()

	if not position_samples[index] then
		---@type Sample[]
		position_samples[index] = {}
		---@type Vector3[]
		velocity_samples[index] = {}
	end

	local current_time = globals.CurTime()
	local current_pos = pEntity:GetAbsOrigin()

	local sample = { pos = current_pos, time = current_time }
	local samples = position_samples[index]
	samples[#samples + 1] = sample

	-- Calculate velocity from last sample
	if #samples >= 2 then
		local prev = samples[#samples - 1]
		local dt = current_time - prev.time
		if dt > 0 then
			local vel = (current_pos - prev.pos) / dt

			-- reject outlier velocities
			if vel:Length() <= MAX_ALLOWED_SPEED then
				velocity_samples[index][#velocity_samples[index] + 1] = vel
			end
		end
	end

	-- Trim samples
	if #samples > SAMPLE_COUNT then
		for i = 1, #samples - SAMPLE_COUNT do
			table.remove(samples, 1)
		end
	end

	if #velocity_samples[index] > SAMPLE_COUNT - 1 then
		for i = 1, #velocity_samples[index] - (SAMPLE_COUNT - 1) do
			table.remove(velocity_samples[index], 1)
		end
	end
end

---@param position Vector3
---@param mins Vector3
---@param maxs Vector3
---@param pTarget Entity
---@return boolean, Vector3|nil
local function IsOnGround(position, mins, maxs, pTarget)
	local function shouldHit(ent)
		return ent:GetIndex() ~= pTarget:GetIndex()
	end

	-- Source engine step height is typically 18 units
	local step_height = 18
	local ground_check_distance = 2

	-- First, trace down from the bottom of the bounding box
	local bbox_bottom = position + Vector3(0, 0, mins.z)
	local trace_start = bbox_bottom
	local trace_end = bbox_bottom + Vector3(0, 0, -ground_check_distance)

	local trace =
		engine.TraceHull(trace_start, trace_end, Vector3(0, 0, 0), Vector3(0, 0, 0), MASK_SHOT_HULL, shouldHit)

	if trace and trace.fraction < 1 then
		-- Check if it's a walkable surface
		local surface_normal = trace.plane
		local ground_angle = math.deg(math.acos(surface_normal:Dot(Vector3(0, 0, 1))))

		if ground_angle <= 45 then
			-- Check if we can actually step on this surface
			local hit_point = trace_start + (trace_end - trace_start) * trace.fraction
			local step_test_start = hit_point + Vector3(0, 0, step_height)
			local step_test_end = position

			local step_trace = engine.TraceHull(step_test_start, step_test_end, mins, maxs, MASK_SHOT_HULL, shouldHit)

			-- If we can fit in the space above the ground, we're grounded
			if not step_trace or step_trace.fraction >= 1 then
				return true, surface_normal
			end
		end
	end

	return false, nil
end

---@param pEntity Entity
---@return boolean
local function IsPlayerOnGround(pEntity)
	local mins, maxs = pEntity:GetMins(), pEntity:GetMaxs()
	local origin = pEntity:GetAbsOrigin()
	local grounded = IsOnGround(origin, mins, maxs, pEntity)
	return grounded == true
end

--- exponential smoothing
--- is this better?
---@param pEntity Entity
---@return Vector3
local function GetSmoothedVelocity(pEntity)
	local samples = velocity_samples[pEntity:GetIndex()]
	if not samples or #samples == 0 then
		return pEntity:EstimateAbsVelocity()
	end

	local grounded = IsPlayerOnGround(pEntity)
	local alpha = grounded and 0.3 or 0.2 -- grounded = smoother, airborne = smootherer --more responsive

	local smoothed = samples[1]
	for i = 2, #samples do
		smoothed = (samples[i] * alpha) + (smoothed * (1 - alpha))
	end

	return smoothed
end

---@param pEntity Entity
---@return number
local function GetSmoothedAngularVelocity(pEntity)
	local samples = position_samples[pEntity:GetIndex()]
	if not samples or #samples < 3 then
		return 0
	end

	local function GetYaw(vec)
		return (vec.x == 0 and vec.y == 0) and 0 or math.deg(math.atan(vec.y, vec.x))
	end

	local ang_vels = {}

	for i = 1, #samples - 2 do
		local d1 = samples[i + 1].pos - samples[i].pos
		local d2 = samples[i + 2].pos - samples[i + 1].pos

		local yaw1 = GetYaw(d1)
		local yaw2 = GetYaw(d2)

		local diff = (yaw2 - yaw1 + 180) % 360 - 180
		ang_vels[#ang_vels + 1] = diff
	end

	if #ang_vels == 0 then
		return 0
	end

	local grounded = IsPlayerOnGround(pEntity)
	local alpha = grounded and 0.25 or 0.5 -- smoother if grounded

	local smoothed = ang_vels[1]
	for i = 2, #ang_vels do
		smoothed = (ang_vels[i] * alpha) + (smoothed * (1 - alpha))
	end

	local MAX_ANG_VEL = 45
	return math.max(-MAX_ANG_VEL, math.min(smoothed, MAX_ANG_VEL))
end

local function GetEnemyTeam()
	local pLocal = entities.GetLocalPlayer()
	if not pLocal then
		return
	end

	return pLocal:GetTeamNumber() == 2 and 3 or 2
end

function sim.RunBackground(players)
	local enemy_team = GetEnemyTeam()

	for _, player in pairs(players) do
		--- no need to predict our own team
		if player:GetTeamNumber() == enemy_team and player:IsAlive() and not player:IsDormant() then
			AddPositionSample(player)
		end
	end
end

---@param pTarget Entity The target
---@param shootPos Vector3
---@param time number The time in seconds we want to predict
function sim.Run(shootPos, pTarget, time)
	local smoothed_velocity = GetSmoothedVelocity(pTarget)
	local angular_velocity = GetSmoothedAngularVelocity(pTarget)
	local last_pos = pTarget:GetAbsOrigin()

	local tick_interval = globals.TickInterval()
	local positions = {}

	local mins, maxs = pTarget:GetMins(), pTarget:GetMaxs()
	local stepHeight = 25

	---@param ent Entity
	---@param contentsMask number
	local function shouldHitEntity(ent, contentsMask)
		return ent:GetIndex() ~= pTarget:GetIndex()
	end

	for i = 1, (time * 67) // 1 do
		-- Apply angular velocity
		local yaw = math.rad(angular_velocity)
		local cos_yaw, sin_yaw = math.cos(yaw), math.sin(yaw)
		local vx, vy = smoothed_velocity.x, smoothed_velocity.y
		smoothed_velocity.x = vx * cos_yaw - vy * sin_yaw
		smoothed_velocity.y = vx * sin_yaw + vy * cos_yaw

		-- Ground check
		local ground_trace = engine.TraceLine(last_pos, last_pos + Vector3(0, 0, -10), MASK_SHOT_HULL, shouldHitEntity)
		local onground = ground_trace and ground_trace.fraction < 1.0

		-- Gravity
		if not onground then
			smoothed_velocity.z = smoothed_velocity.z - (800 * tick_interval)
		elseif smoothed_velocity.z < 0 then
			smoothed_velocity.z = 0
		end

		local move_delta = smoothed_velocity * tick_interval
		local next_pos = last_pos + move_delta

		-- collision trace
		local trace = engine.TraceHull(last_pos, next_pos, mins, maxs, MASK_PLAYERSOLID, shouldHitEntity)

		if trace.fraction < 1.0 then
			-- try stair step
			local step_up = last_pos + Vector3(0, 0, stepHeight)
			local step_up_trace = engine.TraceHull(last_pos, step_up, mins, maxs, MASK_PLAYERSOLID, shouldHitEntity)

			if step_up_trace.fraction == 1.0 then
				local step_forward = step_up + move_delta
				local step_forward_trace =
					engine.TraceHull(step_up, step_forward, mins, maxs, MASK_PLAYERSOLID, shouldHitEntity)

				if step_forward_trace.fraction > 0 then
					-- successful stair step
					next_pos = step_forward_trace.endpos
					last_pos = next_pos
					positions[#positions + 1] = last_pos
					goto continue
				end
			end

			-- Failed to stair step: slide
			next_pos = trace.endpos
			local normal = trace.plane
			local dot = smoothed_velocity:Dot(normal)
			smoothed_velocity = smoothed_velocity - normal * dot
		end

		trace = engine.TraceLine(shootPos, next_pos, MASK_SHOT_HULL, shouldHitEntity)
		if trace and trace.fraction == 1 then
			last_pos = next_pos
			positions[#positions + 1] = last_pos
		end

		::continue::
	end

	return positions
end

return sim
