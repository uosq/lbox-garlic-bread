--[[
  This is deprecated, i'm making a new version of this
--]]

---@diagnostic disable:cast-local-type
--- doesnt use GB_GLOBALS for performance reasons

---@type Entity?, boolean, Vector3?, EulerAngles?, EulerAngles?, Entity?, Vector3?, Vector3?, Entity?, number?, EulerAngles?
local m_localplayer, m_debug, m_target_pos, m_viewangles, m_target_angle, m_target, m_localplayer_pos, m_shootpos, m_weapon, m_closest_fov, m_target_angle_diff

GB_GLOBALS.m_bIsAimbotShooting = false

---@type boolean
local m_bReadyToBackstab = false

local lastFire = 0
local nextAttack = 0
local old_weapon = nil

local m_hitboxes = {
	Head = 1,
	Body = 3,
	--LeftHand = 9,
	LeftArm = 8,
	--RightHand = 12,
	RightArm = 11,
	--LeftFeet = 15,
	--RightFeet = 18,
	LeftLeg = 14,
	RightLeg = 17,
}

local SpecialWeaponIndexes = {
	[230] = "SYDNEY_SLEEPER",
	[61] = "AMBASSADOR",
	[1006] = "FESTIVE AMBASSADOR",
}

local m_hitbox_center = 3

m_debug = false
local M_RADPI = 57.295779513082

local aimbot = {}

local aimbot_mode = {
	plain = 1,
	smooth = 2,
	silent = 3,
}

local m_settings = {

	key = E_ButtonCode.KEY_LSHIFT,
	fov = 30,
	autoshoot = true,
	mode = aimbot_mode.silent,
	lock_aim = false,
	smooth_value = 60,
	melee_rage = false,

	--- should aimbot run when using one of them?
	bullet = true,
	melee = true,
	projectile = true,

	autobackstab = true,

	--- engineer
	aim_friendly_buildings = true,

	ignore = {
		cloaked = true,
		disguised = false,
		taunting = false,
		bonked = true,
		friends = false,
		deadringer = false,
	},

	aim = {
		players = true,
		npcs = true,
		sentries = true,
		other_buildings = false,
	},
}

local BUILDINGS = {
	CObjectSentrygun = true,
	CObjectTeleporter = true,
	CObjectDispenser = true,
}

function aimbot:SetLocalPlayer()
	m_localplayer = entities:GetLocalPlayer()
	if m_localplayer then
		m_localplayer_pos = m_localplayer:GetAbsOrigin()
		m_shootpos = m_localplayer_pos + m_localplayer:GetPropVector("m_vecViewOffset[0]")
		m_weapon = m_localplayer:GetPropEntity("m_hActiveWeapon")
	else
		m_localplayer_pos = nil
		m_shootpos = nil
		m_weapon = nil
	end
end

function aimbot:GetSettings()
	return m_settings
end

function aimbot:SetDebug(bool)
	m_debug = bool
end

---@param entity Entity
---@param selected_hitbox integer
---@return Vector3?
local function GetHitboxPos(entity, selected_hitbox)
	local boneMatrices = entity:SetupBones()
	local boneMatrix = boneMatrices[selected_hitbox]
	if boneMatrix then
		local pos = Vector3(boneMatrix[1][4], boneMatrix[2][4], boneMatrix[3][4])
		if m_debug then
			warn(string.format("GetHitboxPos: [%s, %s, %s]", pos:Unpack()))
		end
		return pos
	end

	return nil
end

---@deprecated
local function GetHitboxPosCache(selected_hitbox, hitboxes, boneMatrices)
	--boneMatrices is an array of 3x4 float matrices
	local hitbox = hitboxes[selected_hitbox]
	local bone = hitbox:GetBone()
	local boneMatrix = boneMatrices[bone]
	if boneMatrix then
		local pos = Vector3(boneMatrix[1][4], boneMatrix[2][4], boneMatrix[3][4])
		if m_debug then
			warn(string.format("GetHitboxPos: [%s, %s, %s]", pos:Unpack()))
		end
		return pos
	end

	return nil
end

local function GetAimPosition()
	assert(m_localplayer, "GetAimPosition -> m_localplayer is nil!")
	assert(m_weapon, "GetAimPosition -> m_weapon is nil!")
	local class = m_localplayer:GetPropInt("m_PlayerClass", "m_iClass")
	local item_def_idx = m_weapon:GetPropInt("m_Item", "m_iItemDefinitionIndex")

	if class == TF2_Sniper then
		if SpecialWeaponIndexes[item_def_idx] then
			return m_hitbox_center
		end
		return m_localplayer:InCond(E_TFCOND.TFCond_Zoomed) and m_hitboxes.Head or m_hitboxes.Body
	elseif class == TF2_Spy then
		if SpecialWeaponIndexes[item_def_idx] then
			return m_weapon:GetWeaponSpread() > 0 and m_hitboxes.Body or m_hitboxes.Head
		end
	end

	return m_hitboxes.Body
end

---@param entity Entity
function aimbot:IsVisible(entity)
	assert(m_localplayer, "Aimbot -> IsVisible: m_localplayer is nil!")
	assert(entity, "Aimbot -> IsVisible: entity is nil!")
	assert(m_shootpos, "Aimbot -> IsVisible: m_shootpos is nil! Check Aimbot:SetLocalPlayer!")
	if entity:IsDormant() or not entity:IsAlive() or entity:InCond(E_TFCOND.TFCond_Ubercharged) then
		return false
	end

	local center = GetHitboxPos(entity, GetAimPosition())
	assert(center, "Aimbot -> IsVisible: center is nil! WTF")
	local trace = engine.TraceLine(m_shootpos, center, MASK_SHOT_HULL)

	if trace.entity == entity and trace.fraction < 0.99 then
		m_target_pos = center

		if m_debug then
			local dbg_string = "Aimbot -> IsVisible: m_target_pos: [%s, %s, %s]"
			warn(string.format(dbg_string, m_target_pos:Unpack()))
		end

		return true
	else
		--[[
		local model = entity:GetModel()
		local studioHdr = models.GetStudioModel(model)

		local myHitBoxSet = entity:GetPropInt("m_nHitboxSet")
		local hitboxSet = studioHdr:GetHitboxSet(myHitBoxSet)
		local hitboxes = hitboxSet:GetHitboxes()
		local boneMatrices = entity:SetupBones()]]

		for _, hitbox in pairs(m_hitboxes) do
			local pos = GetHitboxPos(entity, hitbox)
			--local pos = GetHitboxPosCache(hitbox, hitboxes, boneMatrices)
			if pos then
				trace = engine.TraceLine(m_shootpos, pos, MASK_SHOT_HULL)
				if trace.entity == entity and trace.fraction < 0.98 then
					m_target_pos = pos

					if m_debug then
						local dbg_string = "Aimbot -> IsVisible: m_target_pos [%s, %s, %s]"
						warn(string.format(dbg_string, m_target_pos:Unpack()))
					end

					return true
				end
			end
		end
	end
	return false
end

---@param source Vector3
---@param dest Vector3
---@return EulerAngles
function CalcAngle(source, dest)
	local angles = Vector3()
	local delta = (source - dest)
	local fHyp = math.sqrt((delta.x * delta.x) + (delta.y * delta.y))

	angles.x = (math.atan(delta.z / fHyp) * M_RADPI)
	angles.y = (math.atan(delta.y / delta.x) * M_RADPI)
	angles.z = 0.0

	if delta.x >= 0.0 then
		angles.y = angles.y + 180.0
	end

	return EulerAngles(angles:Unpack())
end

---@param src EulerAngles
---@param dst EulerAngles
---@return number
function CalcFov(src, dst)
	local v_source = src:Forward()
	local v_dest = dst:Forward()
	local result = math.deg(math.acos(v_dest:Dot(v_source) / v_dest:LengthSqr()))

	if result ~= result or result == math.huge then
		result = 0.0
	end

	return result
end

local function FilterBuildings(class)
	if not m_closest_fov or type(m_closest_fov) ~= "number" then
		m_closest_fov = math.huge
	end
	if not m_shootpos or not m_viewangles or not m_localplayer then
		return
	end

	for _, building in pairs(class) do
		if building:GetHealth() <= 0 or building:IsDormant() then
			goto skipbuilding
		end
		local mins, maxs = building:GetMins(), building:GetMaxs()
		local center = building:GetAbsOrigin() + ((mins + maxs) * 0.5)
		local trace = engine.TraceLine(m_shootpos, center, MASK_SHOT_HULL)

		if trace.entity == building and trace.fraction < 0.99 then
			local angle = CalcAngle(m_shootpos, center)
			if not angle then
				goto skipbuilding
			end

			local fov = CalcFov(m_viewangles, angle)
			if not fov then
				goto skipbuilding
			end

			if fov > m_closest_fov or fov > m_settings.fov then
				goto skipbuilding
			end

			m_closest_fov = fov
			m_target_pos = center
			m_target = building
		end
		::skipbuilding::
	end
end

local function GetOtherBuildings()
	if not m_closest_fov or type(m_closest_fov) ~= "number" then
		m_closest_fov = math.huge
	end
	if not m_shootpos or not m_viewangles or not m_localplayer then
		return
	end

	if m_settings.aim.sentries and Sentries then
		FilterBuildings(Sentries)
	end

	if m_settings.aim.other_buildings then
		if Dispensers then
			FilterBuildings(Dispensers)
		end

		if Teleporters then
			FilterBuildings(Teleporters)
		end
	end
end

--- Returns the valid entities from the parameters
function aimbot:GetTargetAngle()
	assert(m_localplayer, "Aimbot -> GetTarget: m_localplayer is nil!")
	assert(m_viewangles, "Aimbot -> GetTarget: m_viewangles is nil! Check Aimbot:SetLocalPlayer!")
	assert(m_localplayer_pos, "Aimbot -> GetTarget: m_localplayer_pos is nil! Check Aimbot.Run!")
	assert(m_weapon, "Aimbot -> GetTarget: m_weapon is nil! Check Aimbot.SetLocalPlayer!")
	assert(m_shootpos, "Aimbot -> GetTarget: m_shootpos is nil! Check Aimbot.SetLocalPlayer!")
	m_closest_fov = math.huge
	m_target_pos = nil
	m_target = nil
	m_target_angle = nil

	GetOtherBuildings()

	if m_settings.aim.players and Players then
		for _, player in pairs(Players) do
			if self:IsVisible(player) then
				assert(m_target_pos, "Aimbot -> GetTarget: m_target_pos is nil! Check Aimbot:SetLocalPlayer!")

				if m_settings.ignore.cloaked and player:InCond(E_TFCOND.TFCond_Cloaked) then
					goto continue
				end
				if m_settings.ignore.bonked and player:InCond(E_TFCOND.TFCond_Bonked) then
					goto continue
				end
				if m_settings.ignore.deadringer and player:InCond(E_TFCOND.TFCond_DeadRingered) then
					goto continue
				end
				if m_settings.ignore.disguised and player:InCond(E_TFCOND.TFCond_Disguised) then
					goto continue
				end
				if m_settings.ignore.friends and playerlist.GetPriority(player) == -1 then
					goto continue
				end
				if m_settings.ignore.taunting and player:InCond(E_TFCOND.TFCond_Taunting) then
					goto continue
				end

				local angle = CalcAngle(m_shootpos, m_target_pos)
				if not angle then
					goto continue
				end

				local fov = CalcFov(m_viewangles, angle)
				if not fov then
					goto continue
				end
				if fov > m_closest_fov or fov > m_settings.fov then
					goto continue
				end

				m_closest_fov = fov
				m_target = player
				m_target_angle = angle
			end
			::continue::
		end
	end
end

---@param usercmd UserCmd
local function AimAtTarget(usercmd)
	if m_target_angle then
		if GB_GLOBALS.m_bNoRecoil then
			local punchangle = (m_weapon and m_weapon:GetPropVector("m_vecPunchAngle") or Vector3())
			m_target_angle = EulerAngles((m_target_angle - punchangle):Unpack())
		end

		if m_settings.mode == aimbot_mode.plain then
			engine.SetViewAngles(m_target_angle)
			usercmd.viewangles = Vector3(m_target_angle:Unpack())
		elseif m_settings.mode == aimbot_mode.smooth then
			local old_angle = engine:GetViewAngles()
			local new_angle = m_target_angle - Vector3(old_angle:Unpack())
			local delta = new_angle / m_settings.smooth_value
			local new_smooth_angle = old_angle + Vector3(delta:Unpack())
			local smooth_angle = EulerAngles(new_smooth_angle:Unpack())
			engine.SetViewAngles(smooth_angle)
			usercmd.viewangles = Vector3(smooth_angle:Unpack())
		elseif m_settings.mode == aimbot_mode.silent then
			usercmd:SetViewAngles(m_target_angle:Unpack())
		end
	end
end

local function GetLastFireTime()
	return m_weapon and m_weapon:GetPropFloat("LocalActiveTFWeaponData", "m_flLastFireTime") or 0
end

local function GetNextPrimaryAttack()
	return m_weapon and m_weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack") or 0
end

--- https://www.unknowncheats.me/forum/team-fortress-2-a/273821-canshoot-function.html
local function CanWeaponShoot()
	if
		not m_weapon
		or not m_localplayer
		or not m_localplayer:IsAlive()
		or m_weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0
	then
		return false
	end
	local lastfiretime = GetLastFireTime()
	if lastFire ~= lastfiretime or m_weapon ~= old_weapon then
		lastFire = lastfiretime
		nextAttack = GetNextPrimaryAttack()
	end
	old_weapon = m_weapon
	return nextAttack <= globals.CurTime()
end

local function CanWeaponShootSimple()
	if GB_GLOBALS.m_hLocalPlayer then
		return GB_GLOBALS.m_hLocalPlayer:GetPropFloat("m_flNextAttack") <= globals.CurTime()
	end
	return true
end

---@param usercmd UserCmd
function aimbot.RunHitscan(usercmd)
	if
		not input.IsButtonDown(m_settings.key)
		or engine.IsChatOpen()
		or engine.IsGameUIVisible()
		or engine.Con_IsVisible()
		or not m_settings.bullet
	then
		GB_GLOBALS.m_bIsAimbotShooting = false
		GB_GLOBALS.m_hAimbotTarget = nil
		return
	end

	assert(m_weapon, "Aimbot -> RunMelee: m_weapon is nil! Check aimbot:SetLocalPlayer!")
	assert(m_localplayer_pos, "Aimbot -> RunHitscan: m_localplayer_pos is nil! Check aimbot:SetLocalPlayer!")
	assert(Players, "Aimbot -> RunHitscan: (global) Players is nil! Check background.lua -> Background()")
	assert(Sentries, "Aimbot -> RunHitscan: (global) Sentries is nil! Check background.lua -> Background()")
	assert(Dispensers, "Aimbot -> RunHitscan: (global) Dispensers is nil! Check background.lua -> Background()")
	assert(Teleporters, "Aimbot -> RunHitscan: (global) Teleporters is nil! Check background.lua -> Background()")
	aimbot:GetTargetAngle()

	if
		m_settings.autoshoot
		and m_target
		and m_target_angle
		and m_target_pos
		and (m_settings.lock_aim and CanWeaponShootSimple() or CanWeaponShoot())
	then
		usercmd.buttons = usercmd.buttons | IN_ATTACK
	end

	if usercmd.buttons & IN_ATTACK ~= 0 then
		AimAtTarget(usercmd)
		m_viewangles = usercmd.viewangles

		GB_GLOBALS.m_bIsAimbotShooting = true
		GB_GLOBALS.m_hAimbotTarget = m_target
	end
end

function aimbot:GetCurrentTarget()
	return m_target, m_target_angle
end

local function NormalizeVector(vec)
	return Vector3(vec.x / vec:Length(), vec.y / vec:Length(), vec.z / vec:Length())
end

--- unreliable, for some fucking reason it depends on the position of the target
local function LookingAtBack()
	assert(m_localplayer, "LookingAtBack -> m_localplayer is nil!")
	assert(m_target, "LookingAtBack -> m_target is nil!")
	assert(m_shootpos, "LookingAtBack -> m_shootpos is nil!")

	local vecToTarget = m_target:GetAbsOrigin() - m_localplayer:GetAbsOrigin()
	vecToTarget.z = 0
	vecToTarget = NormalizeVector(vecToTarget)

	local forward = m_shootpos + engine:GetViewAngles():Forward()
	forward.z = 0
	forward = NormalizeVector(forward)

	local targetForward = m_target:GetAbsAngles():Forward()
	targetForward.z = 0
	targetForward = NormalizeVector(targetForward)

	local pos_vs_target = vecToTarget:Dot(targetForward) --- behind
	local pos_vs_owner = vecToTarget:Dot(forward) --- facing
	local viewangles = targetForward:Dot(forward) --- facestab

	local behind = pos_vs_target <= 0
	local facing = pos_vs_owner <= 0.5
	local view = viewangles <= -0.3

	if m_debug then
		local str = "behind: %s : %s, facing: %s : %s, viewangles: %s : %s"
		print(string.format(str, tostring(pos_vs_target), behind, tostring(pos_vs_owner), facing, viewangles, view))
	end
	return behind and facing
end

local function ShootWeapon(usercmd, target)
	GB_GLOBALS.m_bIsAimbotShooting = true
	GB_GLOBALS.m_hAimbotTarget = target
	usercmd.buttons = usercmd.buttons | IN_ATTACK
end

---@param usercmd UserCmd
function aimbot.RunMelee(usercmd)
	if
		not input.IsButtonDown(m_settings.key)
		or engine.IsChatOpen()
		or engine.IsGameUIVisible()
		or engine.Con_IsVisible()
		or not m_settings.melee
		or not CanWeaponShootSimple()
	then
		GB_GLOBALS.m_bIsAimbotShooting = false
		GB_GLOBALS.m_hAimbotTarget = nil
		return
	end

	if GB_GLOBALS.m_hLocalPlayer and GB_GLOBALS.m_hActiveWeapon then
		local swing_trace = GB_GLOBALS.m_hActiveWeapon:DoSwingTrace()

		if swing_trace and swing_trace.entity then
			if
				m_settings.aim_friendly_buildings
				and swing_trace.entity:GetTeamNumber() == GB_GLOBALS.m_hLocalPlayer:GetTeamNumber()
				and GB_GLOBALS.m_hLocalPlayer:GetPropInt("m_PlayerClass", "m_iClass") == 9
				and BUILDINGS[swing_trace.entity:GetClass()]
				and (
					(
						swing_trace.entity:GetHealth() >= 1
						and swing_trace.entity:GetHealth() < swing_trace.entity:GetMaxHealth()
					) or (swing_trace.entity:GetPropInt("m_iUpgradeLevel") < 3)
				)
			then
				ShootWeapon(usercmd, swing_trace.entity)
				return
			end

			if
				swing_trace.fraction < 0.99
				and swing_trace.entity:GetTeamNumber() ~= GB_GLOBALS.m_hLocalPlayer:GetTeamNumber()
			then
				if
					m_settings.autobackstab
					and GB_GLOBALS.m_hActiveWeapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_KNIFE
				then
					if m_bReadyToBackstab then
						ShootWeapon(usercmd, swing_trace.entity)
					end
					return
				end

				ShootWeapon(usercmd, swing_trace.entity)
			end
		end
	end
end

function aimbot.CreateMove(usercmd)
	m_viewangles = usercmd.viewangles
	aimbot:SetLocalPlayer()
	if not m_localplayer then
		return
	end
	assert(m_weapon, "aimbot -> CreateMove: m_weapon is nil!")

	GB_GLOBALS.m_bIsAimbotShooting = false
	if m_weapon:GetWeaponProjectileType() == E_ProjectileType.TF_PROJECTILE_BULLET then
		aimbot.RunHitscan(usercmd)
	elseif m_weapon:IsMeleeWeapon() then
		aimbot.RunMelee(usercmd)
	end
end

---E_ClientFrameStage.FRAME_NET_UPDATE_END
function aimbot.FrameStage(stage)
	if
		stage == E_ClientFrameStage.FRAME_NET_UPDATE_END
		and m_weapon
		and m_weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_KNIFE
	then
		m_bReadyToBackstab = m_weapon:GetPropBool("m_bReadyToBackstab") or false
	end
end

return aimbot
