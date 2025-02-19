local aimbot_mode = { plain = 1, smooth = 2, silent = 3 }

local settings = {
	fov = 30,
	key = E_ButtonCode.KEY_LSHIFT,
	autoshoot = true,
	mode = aimbot_mode.silent,
	lock_aim = false,
	smooth_value = 60,
	melee_rage = false,

	--- should aimbot run when using one of them?
	hitscan = true,
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

local HITBOXES = {
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

local lastFire = 0
local nextAttack = 0
local old_weapon = nil

local HEADSHOT_WEAPONS_INDEXES = {
	--[230] = true, --- SYDNEY SLEEPER i dont think a sydney sleeper is necessary here
	[61] = true, --- AMBASSADOR
	[1006] = true, --- FESTIVE AMBASSADOR
}

--- some people call it eye position
local function GetShootPosition()
	if GB_GLOBALS and GB_GLOBALS.m_hLocalPlayer then
		return GB_GLOBALS.m_hLocalPlayer:GetAbsOrigin() + GB_GLOBALS.m_hLocalPlayer:GetPropVector("m_vecViewOffset[0]")
	end
	return nil
end

local function GetBestBoneForWeapon()
	if GB_GLOBALS and GB_GLOBALS.m_hLocalPlayer and GB_GLOBALS.m_hActiveWeapon then
		--[[
    if weapon_index and HEADSHOT_WEAPONS_INDEXES[weapon_index] then
      return HITBOXES.Head
    end]]

		local weapon_id = GB_GLOBALS.m_hActiveWeapon:GetWeaponID()

		if
			weapon_id == E_WeaponBaseID.TF_WEAPON_SNIPERRIFLE
			or weapon_id == E_WeaponBaseID.TF_WEAPON_SNIPERRIFLE_DECAP
		then
			return GB_GLOBALS.m_hLocalPlayer:InCond(E_TFCOND.TFCond_Zoomed) and HITBOXES.Head or HITBOXES.Body
		end

		local weapon_index = GB_GLOBALS.m_hActiveWeapon:GetPropInt("m_Item", "m_iItemDefinitionIndex")

		if weapon_index and HEADSHOT_WEAPONS_INDEXES[weapon_index] then
			return GB_GLOBALS.m_hActiveWeapon:GetWeaponSpread() > 0 and HITBOXES.Body or HITBOXES.Head
		end

		return HITBOXES.Body
	end
	return nil
end

local function GetLastFireTime()
	return GB_GLOBALS.m_hActiveWeapon
			and GB_GLOBALS.m_hActiveWeapon:GetPropFloat("LocalActiveTFWeaponData", "m_flLastFireTime")
		or 0
end

local function GetNextPrimaryAttack()
	return GB_GLOBALS and GB_GLOBALS.m_hActiveWeapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack") or 0
end

--- https://www.unknowncheats.me/forum/team-fortress-2-a/273821-canshoot-function.html
local function CanWeaponShoot()
	if GB_GLOBALS.m_hActiveWeapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0 then
		return false
	end
	local lastfiretime = GetLastFireTime()
	if lastFire ~= lastfiretime or GB_GLOBALS.m_hActiveWeapon ~= old_weapon then
		lastFire = lastfiretime
		nextAttack = GetNextPrimaryAttack()
	end
	old_weapon = GB_GLOBALS.m_hActiveWeapon
	return nextAttack <= globals.CurTime()
end

---@param bone Matrix3x4
local function GetBoneOrigin(bone)
	return Vector3(bone[0][3], bone[1][3], bone[2][3])
end

---@param vec Vector3
local function ToAngle(vec)
	local hyp = math.sqrt((vec.x ^ 2 + vec.y ^ 2))
	return Vector3(math.atan(-vec.z, hyp) * (180 / math.pi), math.atan(vec.y, vec.x) * (180 / math.pi), 0)
end

---@param usercmd UserCmd
local function CreateMove(usercmd)
	GB_GLOBALS.m_bIsAimbotShooting = false

	if not input.IsButtonDown(settings.key) then
		return
	end

	if not GB_GLOBALS or not GB_GLOBALS.m_hLocalPlayer or not GB_GLOBALS.m_hActiveWeapon then
		return
	end

	if not GB_GLOBALS.m_hLocalPlayer:IsAlive() then
		return
	end

	local best_angle, best_fov = nil, settings.fov

	local players = entities.FindByClass("CTFPlayer")

	for _, player in pairs(players) do
		if player:IsDormant() or not player:IsAlive() then
			goto continue
		end

		if player:GetTeamNumber() == GB_GLOBALS.m_hLocalPlayer:GetTeamNumber() then
			goto continue
		end

		if player:InCond(E_TFCOND.TFCond_Ubercharged) then
			goto continue
		end

		local bones = player:SetupBones()
		if not bones then
			goto continue
		end

		local weapon_best_bone = GetBestBoneForWeapon()
		if not weapon_best_bone then
			goto continue
		end

		local shoot_pos = GetShootPosition()
		if not shoot_pos then
			goto continue
		end

		local punchangles = GB_GLOBALS.m_bNoRecoil and GB_GLOBALS.m_hActiveWeapon:GetPropVector("m_vecPunchAngle")
			or Vector3()
		if not punchangles then
			goto continue
		end

		local trace = engine.TraceLine(shoot_pos, GetBoneOrigin(bones[weapon_best_bone]), MASK_SHOT_HULL)

		if trace and trace.entity and trace.fraction >= 0.98 then
			local angle = ToAngle(GetBoneOrigin(bones[weapon_best_bone]) - shoot_pos)
				- (usercmd.viewangles - punchangles)
			local fov = math.sqrt(angle.x ^ 2 + angle.y ^ 2)
			if fov < best_fov then
				best_fov = fov
				best_angle = angle
			end
		end
		::continue::
	end

	local can_shoot = CanWeaponShoot()

	if best_angle then
		if can_shoot then
			usercmd.viewangles = usercmd.viewangles
				+ (
					settings.mode == aimbot_mode.smooth
						and vector.Multiply(best_angle, (settings.smooth_value / 100))
					or best_angle
				)
		end

		if aimbot_mode.plain and can_shoot then
			engine.SetViewAngles(EulerAngles(best_angle:Unpack()))
		elseif aimbot_mode.smooth then
			local smoothed = vector.Multiply(best_angle, (settings.smooth_value / 100))
			engine.SetViewAngles(EulerAngles(smoothed:Unpack()))
		end

		if can_shoot and settings.autoshoot then
			usercmd.buttons = usercmd.buttons | IN_ATTACK
			GB_GLOBALS.m_bIsAimbotShooting = true
		end
	end
end

local aimbot = {}
aimbot.CreateMove = CreateMove

return aimbot
