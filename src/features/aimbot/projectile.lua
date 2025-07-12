local proj = {}

--local projSim = require("src.features.aimbot.simulation.proj")

local PREFERRED_BONES = { 4, 3, 10, 7, 1 }
local predicted_pos = nil
local best_target = nil

local simulated_pos = {}
local position_samples = {}
local velocity_samples = {}
local MAX_PREDICTED_TICKS = 66
local SAMPLE_COUNT = 16

local MAX_SPEED = {
	[E_Character.TF2_Demoman] = 280,
	[E_Character.TF2_Engineer] = 300,
	[E_Character.TF2_Heavy] = 230,
	[E_Character.TF2_Medic] = 320,
	[E_Character.TF2_Pyro] = 300,
	[E_Character.TF2_Scout] = 400,
	[E_Character.TF2_Sniper] = 300,
	[E_Character.TF2_Soldier] = 240,
	[E_Character.TF2_Spy] = 320,
}

local function NormalizeVector(vec)
	return vec / vec:Length()
end

---@param position Vector3
---@return boolean
local function IsOnGround(position)
	local function shouldHit(ent)
		return false
	end

	local trace = engine.TraceLine(position, position + Vector3(0, 0, -100), MASK_SHOT_HULL, shouldHit)
	return trace and trace.fraction <= 0.1
end

---@param p0 Vector3 -- shooter origin
---@param p1 Vector3 -- target position
---@param speed number -- projectile speed
---@param gravity number -- gravity (e.g., 800 * gravity_scale)
---@return Vector3? -- aim direction or nil if unreachable
local function SolveBallisticArc(p0, p1, speed, gravity)
	local diff = p1 - p0
	local dx = math.sqrt(diff.x ^ 2 + diff.y ^ 2)
	local dy = diff.z

	local speed2 = speed * speed
	local g = gravity
	local root = speed2 * speed2 - g * (g * dx * dx + 2 * dy * speed2)

	if root < 0 then
		return nil
	end -- no solution

	local sqrt_root = math.sqrt(root)
	local angle = math.atan((speed2 - sqrt_root) / (g * dx)) -- low arc

	local dir_xy = NormalizeVector(Vector3(diff.x, diff.y, 0))
	local aim = Vector3(dir_xy.x * math.cos(angle), dir_xy.y * math.cos(angle), math.sin(angle))

	return NormalizeVector(aim)
end

---@param from Vector3
---@param to Vector3
---@param target Entity
---@return boolean
local function IsVisible(from, to, target)
	local trace = engine.TraceLine(from, to, MASK_SHOT_HULL, function(ent)
		return ent:GetIndex() ~= target:GetIndex()
	end)
	return trace and trace.fraction >= 1.0
end

---@param shootPos Vector3
---@param targetPos Vector3
---@param speed number
---@return number
local function ComputeTravelTime(shootPos, targetPos, speed)
	local distance = (targetPos - shootPos):Length()
	return distance / speed
end

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
		velocity_samples[index][1] = pEntity:EstimateAbsVelocity()
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

local function AddAllPlayerSample(enemy_team, players)
	for _, player in pairs(players) do
		if player:GetTeamNumber() == enemy_team and player:IsAlive() and not player:IsDormant() then
			AddPositionSample(player)
		end
	end
end

---@param pEntity Entity
---@return Vector3 -- smoothed velocity with better air movement handling
local function GetSmoothedVelocity(pEntity)
	local vel_samples = GetPlayerVelocitySamples(pEntity)
	if not vel_samples or #vel_samples < 2 then
		return pEntity:EstimateAbsVelocity()
	end

	-- For airborne targets, use more recent samples with exponential weighting
	local is_airborne = not IsOnGround(pEntity:GetAbsOrigin())
	local total_weight = 0
	local weighted_vel = Vector3(0, 0, 0)

	for i = 1, #vel_samples do
		-- Use exponential weighting for airborne targets, linear for grounded
		local weight = is_airborne and (2 ^ (i - 1)) or (i / #vel_samples)
		weighted_vel = weighted_vel + (vel_samples[i] * weight)
		total_weight = total_weight + weight
	end

	local smoothed = weighted_vel / total_weight

	-- Clamp extreme velocities to prevent prediction chaos
	local max_vel = 4000 -- TF2 theoretical max velocity
	if smoothed:LengthSqr() > max_vel * max_vel then
		smoothed = NormalizeVector(smoothed) * max_vel
	end

	return smoothed
end

---
---@param pEntity Entity
---@return number -- smoothed angular velocity in degrees per tick
local function GetSmoothedAngularVelocity(pEntity)
	local samples = GetPlayerPositionSamples(pEntity)
	if not samples or #samples < 2 then
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

	-- apply slight loss in  angular velocity to prevent infinite spinning (there arent many people that use the strategy of spinning like a beyblade to dodge projectiles)
	local ang_vel_decay = 0.95

	for i = 1, MAX_PREDICTED_TICKS do
		-- apply angular velocity with decay
		local yaw = math.rad(angular_velocity)
		local cos_yaw, sin_yaw = math.cos(yaw), math.sin(yaw)
		local vx, vy = smoothed_velocity.x, smoothed_velocity.y

		-- 2D rotation on XY plane
		smoothed_velocity.x = vx * cos_yaw - vy * sin_yaw
		smoothed_velocity.y = vx * sin_yaw + vy * cos_yaw

		local predicted_pos = last_pos + (smoothed_velocity * tick_interval)
		local onground = IsOnGround(predicted_pos)

		if not onground then
			local class = pEntity:GetPropInt("m_iClass")
			--- max air acceleration is max ground speed * 10 (roughly)
			if smoothed_velocity.z < (MAX_SPEED[class] * 10) then
				smoothed_velocity.z = smoothed_velocity.z - (800 * tick_interval) --- apply gravity
			end
		else
			smoothed_velocity.z = 0
		end

		predicted_pos = last_pos + (smoothed_velocity * tick_interval)

		local trace = engine.TraceHull(last_pos, predicted_pos, mins, maxs, MASK_PLAYERSOLID, shouldHitEntity)

		if trace then
			if trace.fraction < 1 then
				-- collision detected
				local remaining_fraction = 1 - trace.fraction
				local blocked_velocity = smoothed_velocity * remaining_fraction

				-- slide along the wall
				-- the component of the velocity perpendicular to the wall's normal should be removed
				-- and the remaining parallel component retained
				local dot = blocked_velocity:Dot(trace.plane)
				smoothed_velocity = (blocked_velocity - (trace.plane * dot)) / remaining_fraction -- Recalculate full velocity component

				-- Move to the collision point
				last_pos = trace.endpos

				-- Apply a small offset from the wall to prevent immediate re-collision in the next tick
				last_pos = last_pos + (trace.plane * 0.01) -- Small push off the wall

				-- Add the collision point to positions
				positions[#positions + 1] = last_pos

				-- If the new velocity is very small, or we hit a corner, stop
				if smoothed_velocity:LengthSqr() < 1 then -- Arbitrary small value
					break
				end
			else
				-- no collision, continue with predicted position
				positions[#positions + 1] = predicted_pos
				last_pos = predicted_pos
			end
		else
			-- no trace result, this shouldn't happen
			-- but just in case it does, just continue as if it didnt error
			positions[#positions + 1] = predicted_pos
			last_pos = predicted_pos
		end

		-- add decay to angular velocity
		angular_velocity = angular_velocity * ang_vel_decay
	end

	return positions
end

---@param val number
---@param min number
---@param max number
local function clamp(val, min, max)
	return math.max(min, math.min(val, max))
end

--- wtf is this? whyy the fuck is it like this
local function RemapValClamped(val, A, B, C, D)
	if A == B then
		return val >= B and D or C
	end

	local cVal = (val - A) / (B - A)
	cVal = clamp(cVal, 0, 1)

	return C + (D - C) * cVal
end

---@param weapon Entity
local function GetProjectileInfo(weapon)
	-- Projectile info by definition index
	local projInfo = {
		[414] = { 1540, 0 }, -- Liberty Launcher
		[308] = { 1513.3, 0.4 }, -- Loch n' Load
		[595] = { 3000, 0.2 }, -- Manmelter
	}

	-- Projectile info by weapon ID
	local projInfoID = {
		[E_WeaponBaseID.TF_WEAPON_ROCKETLAUNCHER] = { 1100, 0 }, -- Rocket Launcher
		[E_WeaponBaseID.TF_WEAPON_DIRECTHIT] = { 1980, 0 }, -- Direct Hit
		[E_WeaponBaseID.TF_WEAPON_GRENADELAUNCHER] = { 1216.6, 0.5 }, -- Grenade Launcher
		[E_WeaponBaseID.TF_WEAPON_PIPEBOMBLAUNCHER] = { 1100, 0 }, -- Rocket Launcher
		[E_WeaponBaseID.TF_WEAPON_SYRINGEGUN_MEDIC] = { 1000, 0.2 }, -- Syringe Gun
		[E_WeaponBaseID.TF_WEAPON_FLAMETHROWER] = { 1000, 0.2, 0.33 }, -- Flame Thrower
		[E_WeaponBaseID.TF_WEAPON_FLAREGUN] = { 2000, 0.3 }, -- Flare Gun
		[E_WeaponBaseID.TF_WEAPON_CLEAVER] = { 3000, 0.2 }, -- Flying Guillotine
		[E_WeaponBaseID.TF_WEAPON_CROSSBOW] = { 2400, 0.2 }, -- Crusader's Crossbow
		[E_WeaponBaseID.TF_WEAPON_SHOTGUN_BUILDING_RESCUE] = { 2400, 0.2 }, -- Rescue Ranger
		[E_WeaponBaseID.TF_WEAPON_CANNON] = { 1453.9, 0.4 }, -- Loose Cannon
		[E_WeaponBaseID.TF_WEAPON_RAYGUN] = { 1100, 0 }, -- Bison
	}
	local id = weapon:GetWeaponID()
	local defIndex = weapon:GetPropInt("m_iItemDefinitionIndex")

	-- Special cases
	if id == E_WeaponBaseID.TF_WEAPON_COMPOUND_BOW then
		local charge = globals.CurTime() - weapon:GetChargeBeginTime()
		return {
			RemapValClamped(charge, 0.0, 1.0, 1800, 2600),
			RemapValClamped(charge, 0.0, 1.0, 0.5, 0.1),
		}
	elseif id == E_WeaponBaseID.TF_WEAPON_PIPEBOMBLAUNCHER then
		local charge = globals.CurTime() - weapon:GetChargeBeginTime()
		return {
			RemapValClamped(charge, 0.0, 4.0, 900, 2400),
			RemapValClamped(charge, 0.0, 4.0, 0.5, 0.0),
		}
	end

	return projInfo[defIndex] or projInfoID[id] or { 1100, 0.2 }
end

---@param players table<integer, Entity>
---@param plocal Entity
---@param utils GB_Utils
---@param settings GB_Settings
---@param ent_utils GB_EntUtils
---@return PlayerInfo
local function GetClosestPlayerToFov(plocal, settings, utils, ent_utils, players)
	local info = {
		angle = nil,
		fov = settings.aimbot.fov,
		index = nil,
		center = nil,
		pos = nil,
	}

	local viewangle = engine:GetViewAngles()
	local shootpos = ent_utils.GetShootPosition(plocal)

	for _, player in pairs(players) do
		if not player:IsDormant() and player:IsAlive() and player:GetTeamNumber() ~= plocal:GetTeamNumber() then
			-- Get the visible body part info for this player
			local player_info = ent_utils.FindVisibleBodyPart(player, shootpos, utils, viewangle, PREFERRED_BONES)

			-- Check if this player is visible and within FOV
			if player_info and player_info.fov and player_info.fov < info.fov then
				-- This player is closer to crosshair than our current best
				info = player_info
				info.index = player:GetIndex()
			end
		end
	end

	return info
end

---@param plocal Entity
---@param weapon Entity
---@param players table
---@param settings GB_Settings
---@param ent_utils GB_EntUtils
---@param utils GB_Utils
function proj.RunBackground(plocal, weapon, players, settings, ent_utils, utils)
	local enemy_team = plocal:GetTeamNumber() == 2 and 3 or 2
	AddAllPlayerSample(enemy_team, players)

	best_target = GetClosestPlayerToFov(plocal, settings, utils, ent_utils, players)

	if not best_target or not best_target.index or not best_target.pos then
		predicted_pos = nil
		return false, nil
	end

	local netchan = clientstate:GetNetChannel()
	if not netchan then
		predicted_pos = nil
		return false, nil
	end

	local target_ent = entities.GetByIndex(best_target.index)
	if not target_ent then
		predicted_pos = nil
		return false, nil
	end

	local projectile_info = GetProjectileInfo(weapon)
	if not projectile_info then
		predicted_pos = nil
		return false, nil
	end

	---
	local simulated_positions = SimulatePlayer(target_ent)
	if not simulated_positions or #simulated_positions == 0 then
		return false, nil
	end

	simulated_pos = simulated_positions

	local shootPos = ent_utils.GetShootPosition(plocal)
	local best_sim_pos = nil
	local best_time_error = math.huge

	--- returns a Vector3 table of all the positions the weapon's projectile would have until it hit a wall or the ground
	--local positions = projSim.Run(plocal, weapon)

	-- Prediction logic - now works for both rocket and gravity projectiles
	if weapon:GetWeaponProjectileType() == E_ProjectileType.TF_PROJECTILE_ROCKET then
		-- Direct projectile prediction (rockets, etc.)
		for tick, sim_pos in ipairs(simulated_positions) do
			if IsVisible(shootPos, sim_pos, target_ent) then
				local travel_time = ComputeTravelTime(shootPos, sim_pos, projectile_info[1])
				local sim_time = tick * globals.TickInterval()
				local time_error = math.abs(sim_time - travel_time)

				if time_error < best_time_error then
					best_time_error = time_error
					best_sim_pos = sim_pos
				end
			end
		end
	else --- for weapons with gravity
		local gravity = client.GetConVar("sv_gravity") * projectile_info[2]

		for tick, sim_pos in ipairs(simulated_positions) do
			if IsVisible(shootPos, sim_pos, target_ent) then
				-- check if we can solve the ballistic arc to this position
				local aim_dir = SolveBallisticArc(shootPos, sim_pos, projectile_info[1], gravity)

				if aim_dir then
					local travel_time = ComputeTravelTime(shootPos, sim_pos, projectile_info[1])
					local sim_time = tick * globals.TickInterval()
					local time_error = math.abs(sim_time - travel_time)

					if time_error < best_time_error then
						best_time_error = time_error
						best_sim_pos = sim_pos
					end
				end
			end
		end
	end

	predicted_pos = best_sim_pos
end

---@param utils GB_Utils
---@param cmd UserCmd
---@param plocal Entity
---@param wep_utils GB_WepUtils
---@param ent_utils GB_EntUtils
---@param weapon Entity
---@return boolean, integer?
function proj.Run(utils, wep_utils, ent_utils, plocal, weapon, cmd)
	if best_target and best_target.index and predicted_pos and wep_utils.CanShoot() then
		local target_ent = entities.GetByIndex(best_target.index)
		if not target_ent then
			return false, nil
		end

		local shootpos = ent_utils.GetShootPosition(plocal)
		local projectile_info = GetProjectileInfo(weapon)
		if not projectile_info then
			return false, nil
		end

		-- aim angle to direct line of sight
		local angle = utils.math.PositionAngles(shootpos, predicted_pos)

		if weapon:GetWeaponProjectileType() ~= E_ProjectileType.TF_PROJECTILE_ROCKET then
			local gravity = client.GetConVar("sv_gravity") * projectile_info[2]
			local aim_dir = SolveBallisticArc(shootpos, predicted_pos, projectile_info[1], gravity)

			if aim_dir then
				local direction_target = shootpos + aim_dir * 1000 -- scale to get a distant point
				angle = utils.math.PositionAngles(shootpos, direction_target)
			else
				-- if it somehow gives a nil value, just do this instead
				angle = utils.math.PositionAngles(shootpos, predicted_pos)
			end
		end

		if not angle then
			return false, nil
		end

		cmd:SetViewAngles(angle:Unpack())
		cmd.buttons = cmd.buttons | IN_ATTACK
		cmd:SetSendPacket(false)

		return true, best_target.index
	end

	return false, nil
end

function proj.Draw()
	if not best_target or not best_target.index then
		return
	end

	draw.Color(255, 255, 255, 255)

	local predicted_positions = simulated_pos
	if not predicted_positions or #predicted_positions < 2 then
		return
	end

	local max_positions = #predicted_positions

	local last_pos = nil
	for i, pos in pairs(predicted_positions) do
		if last_pos then
			local screen_current = client.WorldToScreen(pos)
			local screen_last = client.WorldToScreen(last_pos)

			if screen_current and screen_last then
				-- sick ass fade
				local alpha = math.max(50, 255 - (i * 5))
				draw.Color(255, 255, 255, alpha)
				draw.Line(screen_last[1], screen_last[2], screen_current[1], screen_current[2])

				--- last position
				if i == max_positions then
					local w, h = 10, 10
					draw.FilledRect(
						screen_current[1] - w,
						screen_current[2] - h,
						screen_current[1] + w,
						screen_current[2] + h
					)
				end
			end
		end

		last_pos = pos
	end

	if predicted_pos then
		local screen = client.WorldToScreen(predicted_pos)
		if screen ~= nil then
			draw.Color(255, 0, 0, 255)
			draw.FilledRect(screen[1] - 10, screen[2] - 10, screen[1] + 10, screen[2] + 10)
		end
	end
end

return proj
