local proj = {}

local playerSim = require("src.features.aimbot.simulation.player")

local PREFERRED_BONES = { 4, 3, 10, 7, 1 }
local predicted_pos = nil
local best_target = nil

local simulated_pos = {}

local function NormalizeVector(vec)
	return vec / vec:Length()
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
local function EstimateTravelTime(shootPos, targetPos, speed)
	local distance = (targetPos - shootPos):Length()
	return distance / speed
end

---@param val number
---@param min number
---@param max number
local function clamp(val, min, max)
	return math.max(min, math.min(val, max))
end

--- wtf is this? whyy the hell is it like this
local function RemapValClamped(val, A, B, C, D)
	if A == B then
		return val >= B and D or C
	end

	local cVal = (val - A) / (B - A)
	cVal = clamp(cVal, 0, 1)

	return C + (D - C) * cVal
end

--- this is definitely not mine
--- i stole... borrowed this from Terminator's PAimbot
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

-- Fixed GetClosestPlayerToFov function
---@param players table<integer, Entity>
---@param plocal Entity
---@param utils GB_Utils
---@param settings GB_Settings
---@param ent_utils GB_EntUtils
---@return PlayerInfo
local function GetClosestPlayerToFov(plocal, settings, utils, ent_utils, players)
	local info = {
		angle = nil,
		fov = settings.aimbot.fov, -- Start with infinite FOV instead of settings.aimbot.fov
		index = nil,
		center = nil,
		pos = nil,
	}

	local viewangle = engine:GetViewAngles()
	local shootpos = ent_utils.GetShootPosition(plocal)

	for _, player in pairs(players) do
		if
			not player:IsDormant()
			and player:IsAlive()
			and player:GetTeamNumber() ~= plocal:GetTeamNumber()
			and player:InCond(E_TFCOND.TFCond_Cloaked) == false
		then
			-- Get the visible body part info for this player
			local player_info = ent_utils.FindVisibleBodyPart(player, shootpos, utils, viewangle, PREFERRED_BONES)

			-- Check if this player is visible and within the configured FOV limit
			if player_info and player_info.fov and player_info.fov < settings.aimbot.fov then
				-- Check if this player is closer to crosshair than our current best
				if player_info.fov < info.fov then
					info = player_info
					info.index = player:GetIndex()
				end
			end
		end
	end

	return info
end

-- Modified RunBackground function with better target switching
function proj.RunBackground(plocal, weapon, players, settings, ent_utils, utils)
	if plocal:IsAlive() == false then
		return false, nil
	end

	local netchan = clientstate:GetNetChannel()
	if not netchan then
		predicted_pos = nil
		simulated_pos = {}
		best_target = nil
		return false, nil
	end

	playerSim.RunBackground(players)

	local projectile_info = GetProjectileInfo(weapon)
	if not projectile_info then
		predicted_pos = nil
		simulated_pos = {}
		best_target = nil
		return false, nil
	end

	-- Always re-evaluate targets instead of sticking to the old one
	-- This ensures we always pick the best available target
	local new_target = GetClosestPlayerToFov(plocal, settings, utils, ent_utils, players)

	best_target = new_target

	if not best_target or not best_target.index or not best_target.pos then
		predicted_pos = nil
		simulated_pos = {}
		return false, nil
	end

	local target_ent = entities.GetByIndex(best_target.index)
	if not target_ent then
		predicted_pos = nil
		simulated_pos = {}
		best_target = nil
		return false, nil
	end

	local projectile_speed = projectile_info[1]
	local shootPos = ent_utils.GetShootPosition(plocal)

	local max_iterations = 10
	local tolerance = 5.0 -- units
	local predicted_target_pos = target_ent:GetAbsOrigin()
	local travel_time = 0.0

	for i = 1, max_iterations do
		-- calculate travel time to predicted position
		travel_time = EstimateTravelTime(shootPos, predicted_target_pos, projectile_speed)

		-- predict where the target will be at that time
		local player_positions = playerSim.Run(shootPos, target_ent, travel_time)
		if not player_positions or #player_positions == 0 then
			break
		end

		local new_predicted_pos = player_positions[#player_positions]

		-- check if we've converged
		local distance_diff = (new_predicted_pos - predicted_target_pos):Length()
		if distance_diff < tolerance then
			predicted_target_pos = new_predicted_pos
			break
		end

		simulated_pos = player_positions
		predicted_target_pos = new_predicted_pos
	end

	-- the predicted position is where we think the target will be
	predicted_pos = predicted_target_pos

	-- is it not visible?
	if not IsVisible(shootPos, predicted_pos, target_ent) then
		-- try to find a visible bone position at the predicted time
		local player_positions = playerSim.Run(shootPos, target_ent, travel_time)
		if player_positions and #player_positions > 0 then
			local final_player_pos = player_positions[#player_positions]

			-- check visibility to different bone positions
			for _, bone_id in ipairs(PREFERRED_BONES) do
				local bone_pos = ent_utils.GetBones(target_ent)[bone_id]

				if bone_pos then
					-- offset the bone position by the predicted movement
					local movement_offset = final_player_pos - target_ent:GetAbsOrigin()
					local predicted_bone_pos = bone_pos + movement_offset

					if IsVisible(shootPos, predicted_bone_pos, target_ent) then
						predicted_pos = final_player_pos
						break
					end
				end
			end
		end
	end

	return true, best_target.index
end

local function DirectionToAngles(direction)
	local pitch = math.asin(-direction.z) * (180 / math.pi)
	local yaw = math.atan(direction.y, direction.x) * (180 / math.pi)
	return Vector3(pitch, yaw, 0)
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
		local shootpos = ent_utils.GetShootPosition(plocal)

		local trace = engine.TraceLine(shootpos, predicted_pos, MASK_SHOT_HULL, function()
			return false
		end)

		if trace and trace.fraction < 1 then
			return false, nil
		end

		local projectile_info = GetProjectileInfo(weapon)
		if not projectile_info then
			return false, nil
		end

		-- for projectiles with gravity, use ballistic arc calculation
		local angle = nil
		if projectile_info[2] > 0 then -- has gravity
			local gravity = client.GetConVar("sv_gravity") * projectile_info[2]
			local aim_dir = SolveBallisticArc(shootpos, predicted_pos, projectile_info[1], gravity)

			if aim_dir then
				angle = DirectionToAngles(aim_dir)
			end
		end

		-- fallback to direct aim if ballistic calculation fails or no gravity
		if not angle then
			angle = utils.math.PositionAngles(shootpos, predicted_pos)
		end

		if not angle then
			return false, nil
		end

		cmd:SetViewAngles(angle:Unpack())
		cmd.buttons = cmd.buttons | IN_ATTACK
		cmd:SetSendPacket(false)

		local target_index = best_target.index
		predicted_pos = nil
		best_target = nil

		return true, target_index
	end

	return false, nil
end

function proj.Draw()
	if not best_target or not best_target.index then
		return
	end

	draw.Color(255, 255, 255, 255)

	if simulated_pos and #simulated_pos >= 2 then
		local max_positions = #simulated_pos
		local last_pos = nil

		for i, pos in pairs(simulated_pos) do
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
	end
end

return proj
