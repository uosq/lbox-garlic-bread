local sim = {}

local simulated_pos = {}
local position_samples = {}
local velocity_samples = {}
local MAX_PREDICTED_TICKS = 66
local SAMPLE_COUNT = 16

---@param pEntity Entity
---@return Vector3[]
local function GetPlayerPositionSamples(pEntity)
	return position_samples[pEntity:GetIndex()]
end

---@param pEntity Entity
---@return Vector3[]
local function GetPlayerVelocitySamples(pEntity)
	return velocity_samples[pEntity:GetIndex()]
end

--- ngl im proud of this function
--- this little fella is the goat
---@param pEntity Entity
local function AddPositionSample(pEntity)
	local index = pEntity:GetIndex()

	if not position_samples[index] then
		position_samples[index] = {}
		velocity_samples[index] = {}
	end

	local current_pos = pEntity:GetAbsOrigin()
	position_samples[index][#position_samples[index] + 1] = current_pos

	-- calculate velocity from position difference
	if #position_samples[index] >= 2 then
		local prev_pos = position_samples[index][#position_samples[index] - 1]
		local velocity = (current_pos - prev_pos) / globals.TickInterval()
		velocity_samples[index][#velocity_samples[index] + 1] = velocity
	end

	-- keep only recent samples
	if #position_samples[index] > SAMPLE_COUNT then
		local temp_pos = {}
		local temp_vel = {}
		for i = 1, SAMPLE_COUNT do
			temp_pos[i] = position_samples[index][i + (#position_samples[index] - SAMPLE_COUNT)]
		end
		for i = 1, SAMPLE_COUNT - 1 do
			temp_vel[i] = velocity_samples[index][i + (#velocity_samples[index] - (SAMPLE_COUNT - 1))]
		end
		position_samples[index] = temp_pos
		velocity_samples[index] = temp_vel
	end
end

---@param pEntity Entity
---@return Vector3 -- smoothed velocity
local function GetSmoothedVelocity(pEntity)
	local vel_samples = GetPlayerVelocitySamples(pEntity)
	if not vel_samples or #vel_samples < 2 then
		return pEntity:EstimateAbsVelocity()
	end

	-- weighted average with more recent samples having higher weight
	local total_weight = 0
	local weighted_vel = Vector3(0, 0, 0)

	for i = 1, #vel_samples do
		local weight = i / #vel_samples -- linear weighting
		weighted_vel = weighted_vel + (vel_samples[i] * weight)
		total_weight = total_weight + weight
	end

	return weighted_vel / total_weight
end

---
---@param pEntity Entity
---@return number -- smoothed angular velocity in degrees per tick
local function GetSmoothedAngularVelocity(pEntity)
	local samples = GetPlayerPositionSamples(pEntity)
	if not samples or #samples < 4 then
		return 0
	end

	local function GetYaw(vec)
		if vec.x == 0 and vec.y == 0 then
			return 0
		end
		return math.deg(math.atan(vec.y, vec.x))
	end

	local angular_velocities = {}
	for i = 1, #samples - 2 do
		local delta1 = samples[i + 1] - samples[i]
		local delta2 = samples[i + 2] - samples[i + 1]

		local yaw1 = GetYaw(delta1)
		local yaw2 = GetYaw(delta2)

		local ang_diff = yaw2 - yaw1
		-- Normalize angle to [-180, 180]
		ang_diff = (ang_diff + 180) % 360 - 180

		angular_velocities[#angular_velocities + 1] = ang_diff
	end

	if #angular_velocities == 0 then
		return 0
	end

	-- calculate weighted average
	local total_weight = 0
	local weighted_ang_vel = 0

	for i = 1, #angular_velocities do
		local weight = i / #angular_velocities
		weighted_ang_vel = weighted_ang_vel + (angular_velocities[i] * weight)
		total_weight = total_weight + weight
	end

	return weighted_ang_vel / total_weight
end

---@param position Vector3
---@param mins Vector3
---@param maxs Vector3
---@return boolean
local function IsOnGround(position, mins, maxs)
	local function shouldHit(ent)
		return false
	end

	-- Use hull trace instead of line trace for better accuracy
	-- Trace from current position down by a small amount (2 units)
	local trace_start = position
	local trace_end = position + Vector3(0, 0, -2)

	local trace = engine.TraceHull(trace_start, trace_end, mins, maxs, MASK_SHOT_HULL, shouldHit)

	-- Much stricter ground check - only consider grounded if we hit something very close
	return trace and trace.fraction < 0.9
end

---@param pEntity Entity
---@return Vector3[]
local function SimulatePlayer(pEntity)
	local smoothed_velocity = GetSmoothedVelocity(pEntity)
	local angular_velocity = GetSmoothedAngularVelocity(pEntity)
	local last_pos = pEntity:GetAbsOrigin()
	local tick_interval = globals.TickInterval()
	local positions = {}

	local mins, maxs = pEntity:GetMins(), pEntity:GetMaxs()

	---@param ent Entity
	---@param contentsMask number
	local function shouldHitEntity(ent, contentsMask)
		return ent:GetIndex() ~= pEntity:GetIndex()
	end

	-- apply slight loss in angular velocity to prevent infinite spinning (there arent many people that use the strategy of spinning like a beyblade to dodge projectiles)
	local ang_vel_decay = 0.95

	for i = 1, MAX_PREDICTED_TICKS do
		-- apply angular velocity with decay
		local yaw = math.rad(angular_velocity)
		local cos_yaw, sin_yaw = math.cos(yaw), math.sin(yaw)
		local vx, vy = smoothed_velocity.x, smoothed_velocity.y

		-- 2D rotation on XY plane
		smoothed_velocity.x = vx * cos_yaw - vy * sin_yaw
		smoothed_velocity.y = vx * sin_yaw + vy * cos_yaw

		-- Check if we're on ground BEFORE applying gravity
		local onground = IsOnGround(last_pos, mins, maxs)

		-- Apply gravity if not on ground
		if not onground then
			smoothed_velocity.z = smoothed_velocity.z - (800 * tick_interval)
		else
			-- If on ground and moving downward, stop downward movement
			if smoothed_velocity.z < 0 then
				smoothed_velocity.z = 0
			end
		end

		local predicted_pos = last_pos + (smoothed_velocity * tick_interval)

		local trace = engine.TraceHull(last_pos, predicted_pos, mins, maxs, MASK_SHOT_HULL, shouldHitEntity)

		if trace then
			if trace.fraction < 1 then
				-- Calculate the actual end position
				local actual_pos = last_pos + (predicted_pos - last_pos) * trace.fraction

				-- Calculate remaining velocity after collision
				local remaining_fraction = 1 - trace.fraction
				local remaining_velocity = smoothed_velocity * remaining_fraction

				-- Reflect velocity off the surface normal
				local dot = remaining_velocity:Dot(trace.plane)
				smoothed_velocity = remaining_velocity - (trace.plane * dot)

				-- Set position to collision point with small offset to prevent getting stuck
				last_pos = actual_pos + (trace.plane * 0.1)
				positions[#positions + 1] = last_pos

				-- If velocity is nearly zero, stop simulation
				if smoothed_velocity:LengthSqr() < 1 then
					break
				end
			else
				-- No collision, continue with predicted position
				positions[#positions + 1] = predicted_pos
				last_pos = predicted_pos
			end
		else
			-- No trace result, this shouldn't happen
			-- but just in case it does, just continue as if it didnt error
			positions[#positions + 1] = predicted_pos
			last_pos = predicted_pos
		end

		-- add decay to angular velocity
		angular_velocity = angular_velocity * ang_vel_decay
	end

	return positions
end

local function GetEnemyTeam()
	local pLocal = entities.GetLocalPlayer()
	if not pLocal then
		return
	end

	return pLocal:GetTeamNumber() == 2 and 3 or 2
end

local function AddAllPlayerSample(enemy_team)
	local players = entities.FindByClass("CTFPlayer")
	for _, player in pairs(players) do
		--if player:GetTeamNumber() == enemy_team and player:IsAlive() and not player:IsDormant() then
		AddPositionSample(player)
		--end
	end
end

---@param uCmd UserCmd
local function CreateMove(uCmd)
	--local enemy_team = GetEnemyTeam()
	--AddAllPlayerSample(enemy_team)

	local players = entities.FindByClass("CTFPlayer")

	for _, player in pairs(players) do
		--- no need to predict our own team
		--if player:GetTeamNumber() == enemy_team and player:IsAlive() and not player:IsDormant() then
		AddPositionSample(player)
		simulated_pos[player:GetIndex()] = SimulatePlayer(player)
		--end
	end
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
---@param time number The time in seconds we want to predict
function sim.Run(pTarget, time)
	local smoothed_velocity = GetSmoothedVelocity(pTarget)
	local angular_velocity = GetSmoothedAngularVelocity(pTarget)
	local last_pos = pTarget:GetAbsOrigin()
	local tick_interval = globals.TickInterval()
	local positions = {}

	local mins, maxs = pTarget:GetMins(), pTarget:GetMaxs()

	---@param ent Entity
	---@param contentsMask number
	local function shouldHitEntity(ent, contentsMask)
		return ent:GetIndex() ~= pTarget:GetIndex()
	end

	-- apply slight loss in angular velocity to prevent infinite spinning (there arent many people that use the strategy of spinning like a beyblade to dodge projectiles)
	local ang_vel_decay = 0.95

	for i = 1, (time * 67) // 1 do
		-- apply angular velocity with decay
		local yaw = math.rad(angular_velocity)
		local cos_yaw, sin_yaw = math.cos(yaw), math.sin(yaw)
		local vx, vy = smoothed_velocity.x, smoothed_velocity.y

		-- 2D rotation on XY plane
		smoothed_velocity.x = vx * cos_yaw - vy * sin_yaw
		smoothed_velocity.y = vx * sin_yaw + vy * cos_yaw

		-- Check if we're on ground BEFORE applying gravity
		local onground = IsOnGround(last_pos, mins, maxs)

		-- Apply gravity if not on ground
		if not onground then
			smoothed_velocity.z = smoothed_velocity.z - (800 * tick_interval)
		else
			-- If on ground and moving downward, stop downward movement
			if smoothed_velocity.z < 0 then
				smoothed_velocity.z = 0
			end
		end

		local predicted_pos = last_pos + (smoothed_velocity * tick_interval)

		local trace = engine.TraceHull(last_pos, predicted_pos, mins, maxs, MASK_SHOT_HULL, shouldHitEntity)

		if trace then
			if trace.fraction < 1 then
				-- Calculate the actual end position
				local actual_pos = last_pos + (predicted_pos - last_pos) * trace.fraction

				-- Calculate remaining velocity after collision
				local remaining_fraction = 1 - trace.fraction
				local remaining_velocity = smoothed_velocity * remaining_fraction

				-- Reflect velocity off the surface normal
				local dot = remaining_velocity:Dot(trace.plane)
				smoothed_velocity = remaining_velocity - (trace.plane * dot)

				-- Set position to collision point with small offset to prevent getting stuck
				last_pos = actual_pos + (trace.plane * 0.1)
				positions[#positions + 1] = last_pos

				-- If velocity is nearly zero, stop simulation
				if smoothed_velocity:LengthSqr() < 1 then
					break
				end
			else
				-- No collision, continue with predicted position
				positions[#positions + 1] = predicted_pos
				last_pos = predicted_pos
			end
		else
			-- No trace result, this shouldn't happen
			-- but just in case it does, just continue as if it didnt error
			positions[#positions + 1] = predicted_pos
			last_pos = predicted_pos
		end

		-- add decay to angular velocity
		angular_velocity = angular_velocity * ang_vel_decay
	end

	return positions
end

return sim
