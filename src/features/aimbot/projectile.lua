local proj = {}

local playerSim = require("src.features.aimbot.simulation.player")
local projSim = require("src.features.aimbot.simulation.proj")

local PREFERRED_BONES = { 4, 3, 10, 7, 1 }
local predicted_pos = nil
local best_target = nil
local total_time = 0

local vector = Vector3

local simulated_pos = {}

local displayed_projectile_path = {}
local displayed_path = {}
local displayed_time = 0

---@type table<integer, integer>
local ItemDefinitions = {}
do
	local defs = {
		[222] = 11,
		[812] = 12,
		[833] = 12,
		[1121] = 11,
		[18] = -1,
		[205] = -1,
		[127] = -1,
		[228] = -1,
		[237] = -1,
		[414] = -1,
		[441] = -1,
		[513] = -1,
		[658] = -1,
		[730] = -1,
		[800] = -1,
		[809] = -1,
		[889] = -1,
		[898] = -1,
		[907] = -1,
		[916] = -1,
		[965] = -1,
		[974] = -1,
		[1085] = -1,
		[1104] = -1,
		[15006] = -1,
		[15014] = -1,
		[15028] = -1,
		[15043] = -1,
		[15052] = -1,
		[15057] = -1,
		[15081] = -1,
		[15104] = -1,
		[15105] = -1,
		[15129] = -1,
		[15130] = -1,
		[15150] = -1,
		[442] = -1,
		[1178] = -1,
		[39] = 8,
		[351] = 8,
		[595] = 8,
		[740] = 8,
		[1180] = 0,
		[19] = 5,
		[206] = 5,
		[308] = 5,
		[996] = 6,
		[1007] = 5,
		[1151] = 4,
		[15077] = 5,
		[15079] = 5,
		[15091] = 5,
		[15092] = 5,
		[15116] = 5,
		[15117] = 5,
		[15142] = 5,
		[15158] = 5,
		[20] = 1,
		[207] = 1,
		[130] = 3,
		[265] = 3,
		[661] = 1,
		[797] = 1,
		[806] = 1,
		[886] = 1,
		[895] = 1,
		[904] = 1,
		[913] = 1,
		[962] = 1,
		[971] = 1,
		[1150] = 2,
		[15009] = 1,
		[15012] = 1,
		[15024] = 1,
		[15038] = 1,
		[15045] = 1,
		[15048] = 1,
		[15082] = 1,
		[15083] = 1,
		[15084] = 1,
		[15113] = 1,
		[15137] = 1,
		[15138] = 1,
		[15155] = 1,
		[588] = -1,
		[997] = 9,
		[17] = 10,
		[204] = 10,
		[36] = 10,
		[305] = 9,
		[412] = 10,
		[1079] = 9,
		[56] = 7,
		[1005] = 7,
		[1092] = 7,
		[58] = 11,
		[1083] = 11,
		[1105] = 11,
	}
	local maxIndex = 0
	for k, _ in pairs(defs) do
		if k > maxIndex then
			maxIndex = k
		end
	end
	for i = 1, maxIndex do
		ItemDefinitions[i] = defs[i] or false
	end
end

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

	local dir_xy = NormalizeVector(vector(diff.x, diff.y, 0))
	local aim = vector(dir_xy.x * math.cos(angle), dir_xy.y * math.cos(angle), math.sin(angle))

	return NormalizeVector(aim)
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

-- Returns (offset, forward velocity, upward velocity, collision hull, gravity, drag)
local function GetProjectileInformation(pWeapon, bDucking, iCase, iDefIndex, iWepID)
	local chargeTime = pWeapon:GetPropFloat("m_flChargeBeginTime") or 0
	if chargeTime ~= 0 then
		chargeTime = globals.CurTime() - chargeTime
	end

	-- Predefined offsets and collision sizes:
	local offsets = {
		Vector3(16, 8, -6), -- Index 1: Sticky Bomb, Iron Bomber, etc.
		Vector3(23.5, -8, -3), -- Index 2: Huntsman, Crossbow, etc.
		Vector3(23.5, 12, -3), -- Index 3: Flare Gun, Guillotine, etc.
		Vector3(16, 6, -8), -- Index 4: Syringe Gun, etc.
	}
	local collisionMaxs = {
		Vector3(0, 0, 0), -- For projectiles that use TRACE_LINE (e.g. rockets)
		Vector3(1, 1, 1),
		Vector3(2, 2, 2),
		Vector3(3, 3, 3),
	}

	if iCase == -1 then
		-- Rocket Launcher types: force a zero collision hull so that TRACE_LINE is used.
		local vOffset = Vector3(23.5, -8, bDucking and 8 or -3)
		local vCollisionMax = collisionMaxs[1] -- Zero hitbox
		local fForwardVelocity = 1200
		if iWepID == 22 or iWepID == 65 then
			vOffset.y = (iDefIndex == 513) and 0 or 12
			fForwardVelocity = (iWepID == 65) and 2000 or ((iDefIndex == 414) and 1550 or 1100)
		elseif iWepID == 109 then
			vOffset.y, vOffset.z = 6, -3
		else
			fForwardVelocity = 1200
		end
		return vOffset, fForwardVelocity, 0, vCollisionMax, 0, nil
	elseif iCase == 1 then
		return offsets[1], 900 + clamp(chargeTime / 4, 0, 1) * 1500, 200, collisionMaxs[3], 0, nil
	elseif iCase == 2 then
		return offsets[1], 900 + clamp(chargeTime / 1.2, 0, 1) * 1500, 200, collisionMaxs[3], 0, nil
	elseif iCase == 3 then
		return offsets[1], 900 + clamp(chargeTime / 4, 0, 1) * 1500, 200, collisionMaxs[3], 0, nil
	elseif iCase == 4 then
		return offsets[1], 1200, 200, collisionMaxs[4], 400, 0.45
	elseif iCase == 5 then
		local vel = (iDefIndex == 308) and 1500 or 1200
		local drag = (iDefIndex == 308) and 0.225 or 0.45
		return offsets[1], vel, 200, collisionMaxs[4], 400, drag
	elseif iCase == 6 then
		return offsets[1], 1440, 200, collisionMaxs[3], 560, 0.5
	elseif iCase == 7 then
		return offsets[2],
			1800 + clamp(chargeTime, 0, 1) * 800,
			0,
			collisionMaxs[2],
			200 - clamp(chargeTime, 0, 1) * 160,
			nil
	elseif iCase == 8 then
		-- Flare Gun: Use a small nonzero collision hull and a higher drag value to make drag noticeable.
		return Vector3(23.5, 12, bDucking and 8 or -3), 2000, 0, Vector3(0.1, 0.1, 0.1), 120, 0.5
	elseif iCase == 9 then
		local idx = (iDefIndex == 997) and 2 or 4
		return offsets[2], 2400, 0, collisionMaxs[idx], 80, nil
	elseif iCase == 10 then
		return offsets[4], 1000, 0, collisionMaxs[2], 120, nil
	elseif iCase == 11 then
		return Vector3(23.5, 8, -3), 1000, 200, collisionMaxs[4], 450, nil
	elseif iCase == 12 then
		return Vector3(23.5, 8, -3), 3000, 300, collisionMaxs[3], 900, 1.3
	end
end

local function GetShootPos(pLocal, pWeapon)
	local iItemDefinitionIndex = pWeapon:GetPropInt("m_iItemDefinitionIndex")
	local iItemDefinitionType = ItemDefinitions[iItemDefinitionIndex] or 0
	if iItemDefinitionType == 0 then
		predicted_pos = nil
		simulated_pos = {}
		best_target = nil
		return {}
	end

	local vOffset, fForwardVelocity, fUpwardVelocity, vCollisionMax, fGravity, fDrag = GetProjectileInformation(
		pWeapon,
		(pLocal:GetPropInt("m_fFlags") & FL_DUCKING) == 2,
		iItemDefinitionType,
		iItemDefinitionIndex,
		pWeapon:GetWeaponID()
	)

	if not (vOffset or fForwardVelocity or fUpwardVelocity or vCollisionMax or fGravity or fDrag) then
		predicted_pos = nil
		simulated_pos = {}
		best_target = nil
		return {}
	end

	local vCollisionMin = -vCollisionMax

	-- i stole this from terminator
	local vStartPosition = pLocal:GetAbsOrigin() + pLocal:GetPropVector("localdata", "m_vecViewOffset[0]")
	local vStartAngle = engine.GetViewAngles()

	return vStartPosition
		+ (vStartAngle:Forward() * vOffset.x)
		+ (vStartAngle:Right() * (vOffset.y * (pWeapon:IsViewModelFlipped() and -1 or 1)))
		+ (vStartAngle:Up() * vOffset.z)
end

---@param players table<integer, Entity>
---@param plocal Entity
---@param utils GB_Utils
---@param settings GB_Settings
---@param ent_utils GB_EntUtils
---@return PlayerInfo
local function GetClosestPlayerToFov(plocal, weapon, settings, utils, ent_utils, players)
	local info = {
		angle = nil,
		fov = settings.aimbot.fov,
		index = nil,
		center = nil,
		pos = nil,
	}

	local viewangle = engine:GetViewAngles()

	local shootpos = GetShootPos(plocal, weapon)

	for _, player in pairs(players) do
		if
			not player:IsDormant()
			and player:IsAlive()
			and player:GetTeamNumber() ~= plocal:GetTeamNumber()
			and player:InCond(E_TFCOND.TFCond_Cloaked) == false
		then
			if (player:GetAbsOrigin() - plocal:GetAbsOrigin()):Length() < settings.aimbot.m_iMaxDistance then
				-- get the visible body part info for this player
				local player_info = ent_utils.FindVisibleBodyPart(player, shootpos, utils, viewangle, PREFERRED_BONES)

				-- check if this player is visible and within the configured FOV limit
				if player_info and player_info.fov and player_info.fov < settings.aimbot.fov then
					-- check if this player is closer to crosshair than our current best
					if player_info.fov < info.fov then
						info = player_info
						info.index = player:GetIndex()
					end
				end
			end
		end
	end

	return info
end

---@param plocal Entity
---@param weapon Entity
---@param players table<integer, Entity>
---@param settings GB_Settings
---@param ent_utils GB_EntUtils
---@param utils GB_Utils
function proj.RunBackground(plocal, weapon, players, settings, ent_utils, utils)
	local netchan = clientstate:GetNetChannel()
	if not netchan then
		predicted_pos = nil
		simulated_pos = {}
		best_target = nil
		return false, nil
	end

	if plocal:IsAlive() == false then
		predicted_pos = nil
		simulated_pos = {}
		best_target = nil
		return false, nil
	end

	playerSim.RunBackground(players)

	local iItemDefinitionIndex = weapon:GetPropInt("m_iItemDefinitionIndex")
	local iItemDefinitionType = ItemDefinitions[iItemDefinitionIndex] or 0
	if iItemDefinitionType == 0 then
		predicted_pos = nil
		simulated_pos = {}
		best_target = nil
		return false, nil
	end

	local vOffset, fForwardVelocity, fUpwardVelocity, vCollisionMax, fGravity, fDrag = GetProjectileInformation(
		weapon,
		(plocal:GetPropInt("m_fFlags") & FL_DUCKING) == 2,
		iItemDefinitionType,
		iItemDefinitionIndex,
		weapon:GetWeaponID()
	)

	if not (vOffset or fForwardVelocity or fUpwardVelocity or vCollisionMax or fGravity or fDrag) then
		predicted_pos = nil
		simulated_pos = {}
		best_target = nil
		return false, nil
	end

	local new_target = GetClosestPlayerToFov(plocal, weapon, settings, utils, ent_utils, players)

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

	local projectile_speed = fForwardVelocity
	local shootPos = GetShootPos(plocal, weapon)

	local tolerance = 5.0 -- HU
	local stepSize = plocal:GetPropFloat("localdata", "m_flStepSize") or 18 -- i think 18 is the default, not sure

	local base_origin = target_ent:GetAbsOrigin()
	local dist = (shootPos - base_origin):Length()
	if dist > settings.aimbot.m_iMaxDistance then
		predicted_pos, simulated_pos, best_target = nil, {}, nil
		return false, nil
	end

	local charge_time = 0.0
	if weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_COMPOUND_BOW then
		charge_time = globals.CurTime() - weapon:GetChargeBeginTime()
		charge_time = (charge_time > 1.0) and 0 or charge_time
	elseif weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_PIPEBOMBLAUNCHER then
		charge_time = globals.CurTime() - weapon:GetChargeBeginTime()
		charge_time = (charge_time > 4.0) and 0 or charge_time
	end

	--- mmake the interations be based on the distance
	local max_iterations = (dist > (settings.aimbot.m_iMaxDistance * 0.5)) and 2 or 5
	local predicted_target_pos = base_origin

	for i = 1, max_iterations do
		local travel_time = math.sqrt((shootPos - predicted_target_pos):LengthSqr()) / projectile_speed
		total_time = travel_time + charge_time

		local player_positions = playerSim.Run(stepSize, target_ent, total_time)
		if not player_positions or #player_positions == 0 then
			break
		end

		local new_pos = player_positions[#player_positions]
		local delta = (new_pos - predicted_target_pos):Length()

		if delta < tolerance then
			predicted_target_pos = new_pos
			break
		end

		predicted_target_pos = new_pos
		simulated_pos = player_positions
	end

	-- the predicted position is where we think the target will be
	predicted_pos = predicted_target_pos

	-- this is very expensive, think of a better way of doing it damn it!
	-- is it not visible?
	--[[if not IsVisible(shootPos, predicted_pos, target_ent) then
		-- try to find a visible bone position at the predicted time
		local player_positions = playerSim.Run(stepSize, shootPos, target_ent, travel_time)
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
	end]]

	return true, best_target.index
end

local function DirectionToAngles(direction)
	local pitch = math.asin(-direction.z) * (180 / math.pi)
	local yaw = math.atan(direction.y, direction.x) * (180 / math.pi)
	return vector(pitch, yaw, 0)
end

---@param utils GB_Utils
---@param cmd UserCmd
---@param plocal Entity
---@param wep_utils GB_WepUtils
---@param weapon Entity
---@return boolean, integer?
function proj.Run(utils, wep_utils, plocal, weapon, cmd)
	if best_target and best_target.index and predicted_pos and wep_utils.CanShoot() then
		local iItemDefinitionIndex = weapon:GetPropInt("m_iItemDefinitionIndex")
		local iItemDefinitionType = ItemDefinitions[iItemDefinitionIndex] or 0
		if iItemDefinitionType == 0 then
			return false, nil
		end

		local vOffset, fForwardVelocity, fUpwardVelocity, vCollisionMax, fGravity, fDrag = GetProjectileInformation(
			weapon,
			(plocal:GetPropInt("m_fFlags") & FL_DUCKING) == 2,
			iItemDefinitionType,
			iItemDefinitionIndex,
			weapon:GetWeaponID()
		)

		if not (vOffset or fForwardVelocity or fUpwardVelocity or vCollisionMax or fGravity or fDrag) then
			return false, nil
		end

		local vCollisionMin = -vCollisionMax

		-- i stole this from terminator
		local vStartPosition = plocal:GetAbsOrigin() + plocal:GetPropVector("localdata", "m_vecViewOffset[0]")
		local vStartAngle = engine.GetViewAngles()

		local results = engine.TraceHull(
			vStartPosition,
			vStartPosition
				+ (vStartAngle:Forward() * vOffset.x)
				+ (vStartAngle:Right() * (vOffset.y * (weapon:IsViewModelFlipped() and -1 or 1)))
				+ (vStartAngle:Up() * vOffset.z),
			vCollisionMin,
			vCollisionMax,
			100679691
		)
		if results.fraction ~= 1 then
			return false, nil
		end

		local shootpos = results.endpos

		local trace = engine.TraceLine(shootpos, predicted_pos, MASK_SHOT_HULL, function()
			return false
		end)

		if trace and trace.fraction < 1 then
			return false, nil
		end

		local angle = nil
		local projectile_path

		--- ballistic
		if fGravity > 0 then
			local gravity = fGravity * globals.TickInterval()
			local aim_dir = SolveBallisticArc(shootpos, predicted_pos, fForwardVelocity, gravity)

			if aim_dir then
				projectile_path = projSim.Run(plocal, weapon, shootpos, aim_dir, total_time)
				angle = DirectionToAngles(aim_dir)
			end
		else -- straight line projectile
			if not angle then
				angle = utils.math.PositionAngles(shootpos, predicted_pos)
				projectile_path = projSim.Run(plocal, weapon, shootpos, angle:Forward(), total_time)
			end
		end

		if not angle then
			return false, nil
		end

		cmd:SetViewAngles(angle:Unpack())
		cmd.buttons = cmd.buttons | IN_ATTACK

		local charge
		charge = weapon:GetPropFloat("m_flChargeBeginTime") or weapon:GetPropFloat("m_flDetonateTime")
		if charge and charge > 0.0 then
			cmd.buttons = cmd.buttons & ~IN_ATTACK
		end

		cmd:SetSendPacket(false)

		local target_index = best_target.index
		predicted_pos = nil
		best_target = nil

		displayed_path = simulated_pos
		displayed_projectile_path = projectile_path
		displayed_time = globals.CurTime() + 1

		return true, target_index
	end

	return false, nil
end

function proj.Draw()
	local pLocal = entities.GetLocalPlayer()
	if not pLocal then
		return
	end

	if (globals.CurTime() - displayed_time) > 0 then
		displayed_path = {}
		displayed_projectile_path = {}
	end

	if pLocal:IsAlive() == false then
		return
	end

	draw.Color(255, 255, 255, 255)

	if displayed_path and #displayed_path >= 2 then
		local max_positions = #displayed_path
		local last_pos = nil

		for i, pos in pairs(displayed_path) do
			if last_pos then
				local screen_current = client.WorldToScreen(pos)
				local screen_last = client.WorldToScreen(last_pos)

				if screen_current and screen_last then
					-- sick ass fade
					local alpha = math.max(5, 255 - (i * 5))
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

	if displayed_projectile_path then
		local last_pos = nil
		for i, path in pairs(displayed_projectile_path) do
			if last_pos then
				local screen_current = client.WorldToScreen(path.pos)
				local screen_last = client.WorldToScreen(last_pos)

				if screen_current and screen_last then
					-- sick ass fade
					local alpha = math.max(25, 255 - (i * 5))
					draw.Color(255, 255, 255, alpha)
					draw.Line(screen_last[1], screen_last[2], screen_current[1], screen_current[2])
				end
			end
			last_pos = path.pos
		end
	end
end

return proj
