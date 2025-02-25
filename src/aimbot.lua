local aimbot_mode = { plain = 1, smooth = 2, silent = 3 }

local settings = {
	fov = 10,
	key = E_ButtonCode.KEY_LSHIFT,
	autoshoot = true,
	mode = aimbot_mode.silent,
	lock_aim = true,
	smooth_value = 10, --- lower value, smoother aimbot (10 = very smooth, 100 = basically plain aimbot)
	auto_spinup = true,
	aimfov = true,

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
		other_buildings = true,
	},
}

local m_bReadyToBackstab = false

---@type Entity?, Entity?, integer?
local localplayer, weapon, m_team = nil, nil, nil

local width, height = draw.GetScreenSize()

--- TODO: rename later to CLASS_BONES
local CLASS_HITBOXES = require("src.hitboxes")

local VISIBLE_FRACTION = 0.4

local lastFire = 0
local nextAttack = 0
local old_weapon = nil

local HEADSHOT_WEAPONS_INDEXES = {
	--[230] = true, --- SYDNEY SLEEPER i dont think a sydney sleeper is necessary here
	[61] = true, --- AMBASSADOR
	[1006] = true, --- FESTIVE AMBASSADOR
}

--- stuff used by melee aimbot
local ENGINEER_CLASS = 9
local MAX_UPGRADE_LEVEL = 3
local BUILDINGS = {
	CObjectSentrygun = true,
	CObjectDispenser = true,
	CObjectTeleporter = true,
}

--- Cache some important functions

local TraceLine = engine.TraceLine
local sqrt = math.sqrt
local atan = math.atan
local PI = math.pi
local RADPI = 180 / PI
local vecMultiply = vector.Multiply

---

--- some people call it eye position
local function GetShootPosition()
	if localplayer then
		return localplayer:GetAbsOrigin() + localplayer:GetPropVector("m_vecViewOffset[0]")
	end
	return nil
end

--- returns true for head and false for body
local function ShouldAimAtHead()
	if localplayer and weapon then
		--[[
    if weapon_index and HEADSHOT_WEAPONS_INDEXES[weapon_index] then
      return HITBOXES.Head
    end]]

		local weapon_id = weapon:GetWeaponID()
		local Head, Body = true, false

		if
			weapon_id == E_WeaponBaseID.TF_WEAPON_SNIPERRIFLE
			or weapon_id == E_WeaponBaseID.TF_WEAPON_SNIPERRIFLE_DECAP
		then
			return localplayer:InCond(E_TFCOND.TFCond_Zoomed) and Head or Body
		end

		local weapon_index = weapon:GetPropInt("m_Item", "m_iItemDefinitionIndex")

		if weapon_index and HEADSHOT_WEAPONS_INDEXES[weapon_index] then
			return weapon:GetWeaponSpread() > 0 and Body or Head
		end

		return Body
	end
	return nil
end

local function GetLastFireTime()
	return weapon and weapon:GetPropFloat("LocalActiveTFWeaponData", "m_flLastFireTime") or 0
end

local function GetNextPrimaryAttack()
	return weapon and weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack") or 0
end

--- https://www.unknowncheats.me/forum/team-fortress-2-a/273821-canshoot-function.html
local function CanWeaponShoot()
	if not weapon or weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0 then
		return false
	end
	local lastfiretime = GetLastFireTime()
	if lastFire ~= lastfiretime or weapon ~= old_weapon then
		lastFire = lastfiretime
		nextAttack = GetNextPrimaryAttack()
	end
	old_weapon = weapon
	return nextAttack <= globals.CurTime()
end

GB_GLOBALS.CanWeaponShoot = CanWeaponShoot

---@param bone Matrix3x4
local function GetBoneOrigin(bone)
	return Vector3(bone[1][4], bone[2][4], bone[3][4])
end

---@param vec Vector3
local function ToAngle(vec)
	local hyp = sqrt((vec.x * vec.x) + (vec.y * vec.y))
	return Vector3(atan(-vec.z, hyp) * RADPI, atan(vec.y, vec.x) * RADPI, 0)
end

---@param usercmd UserCmd
---@param targetIndex integer
local function MakeWeaponShoot(usercmd, targetIndex)
	usercmd.buttons = usercmd.buttons | IN_ATTACK
	GB_GLOBALS.m_nAimbotTarget = targetIndex
	GB_GLOBALS.m_bIsAimbotShooting = true
end

--- Only run this in CreateMove, after localplayer and weapon are valid!
---@param usercmd UserCmd
local function RunMelee(usercmd)
	if weapon and weapon:IsMeleeWeapon() then
		local swing_trace = weapon:DoSwingTrace()

		if swing_trace and swing_trace.entity and swing_trace.fraction <= 0.95 then
			local entity = swing_trace.entity
			local entity_team = entity:GetTeamNumber()
			local index = entity:GetIndex()
			if
				settings.aim_friendly_buildings
				and BUILDINGS[entity:GetClass()]
				and localplayer
				and localplayer:GetPropInt("m_PlayerClass", "m_iClass") == ENGINEER_CLASS
				and (
					(entity:GetHealth() >= 1 and entity:GetHealth() < entity:GetMaxHealth())
					or (entity:GetPropInt("m_iUpgradeLevel") < MAX_UPGRADE_LEVEL)
				)
			then
				MakeWeaponShoot(usercmd, index)
				return true
			end

			if entity_team ~= m_team and entity:IsAlive() then
				if weapon and weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_KNIFE and settings.autobackstab then
					if m_bReadyToBackstab then
						MakeWeaponShoot(usercmd, index)
					end

					--- dont run after this or it will try to butterknife
					GB_GLOBALS.m_nAimbotTarget = index
					GB_GLOBALS.m_bIsAimbotShooting = false
					return true
				end

				MakeWeaponShoot(usercmd, index)
				return true
			end
		end
	end
	return false
end

---@param usercmd UserCmd
local function CreateMove(usercmd)
	GB_GLOBALS.m_bIsAimbotShooting = false
	GB_GLOBALS.m_nAimbotTarget = nil

	localplayer = entities:GetLocalPlayer()
	if not localplayer or not localplayer:IsAlive() then return end
	m_team = localplayer:GetTeamNumber()

	weapon = localplayer:GetPropEntity("m_hActiveWeapon")
	if not weapon then return end

	if not input.IsButtonDown(settings.key) then return end
	if engine.IsChatOpen() or engine.Con_IsVisible() or engine.IsGameUIVisible() then return end

	--- if it returns true, it means it was a melee weapon and it did the proper math for them
	if weapon:IsMeleeWeapon() then
		RunMelee(usercmd)
		return
	end

	if (weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0) then return end

	--- try to make stac dont ban us :3
	local m_AimbotMode = GB_GLOBALS.m_bIsStacRunning and aimbot_mode.smooth or settings.mode
	local m_SmoothValue = GB_GLOBALS.m_bIsStacRunning and 20 or settings.smooth_value
	local viewfov = localplayer:InCond(E_TFCOND.TFCond_Zoomed) and 20 or GB_GLOBALS.m_flCustomFOV
	local m_Fov = settings.fov * (math.tan(math.rad(viewfov / 2)) / math.tan(math.rad(45)))

	local shoot_pos = GetShootPosition()
	if not shoot_pos then
		return
	end

	local punchangles = weapon:GetPropVector("m_vecPunchAngle") or Vector3()
	local should_aim_at_head = ShouldAimAtHead()

	--- trust me, i tried like 3 or 4 different math combinations
	--- and i decided to just give up and paste amalgam for the fov xd

	local best_angle, best_fov, target, looking_at_target = nil, m_Fov, nil, false

	---@param class Entity[]
	local function CheckBuilding(class)
		for _, entity in pairs(class) do
			local mins, maxs = entity:GetMins(), entity:GetMaxs()
			local center = entity:GetAbsOrigin() + ((mins + maxs) * 0.5)

			local trace = TraceLine(shoot_pos, center, MASK_SHOT_HULL)
			if trace and trace.entity == entity and trace.fraction >= VISIBLE_FRACTION then
				local angle = ToAngle(center - shoot_pos) - (usercmd.viewangles - punchangles)
				local fov = sqrt((angle.x ^ 2) + (angle.y ^ 2))

				if fov < best_fov then
					best_fov = fov
					best_angle = angle
					target = entity:GetIndex() --- not saving the whole entity here, too much memory used!
				end
			end
		end
	end

	for _, entity in pairs(Players) do
		if not entity or entity:IsDormant() or not entity:IsAlive() or entity:GetTeamNumber() == m_team then
			goto continue
		end

		--- not the best way, probably using a single if statement would be better
		--- but i think its clearer what it does like this
		if entity:InCond(E_TFCOND.TFCond_Ubercharged) then
			goto continue
		elseif entity:InCond(E_TFCOND.TFCond_Cloaked) and settings.ignore.cloaked then
			goto continue
		elseif settings.ignore.bonked and entity:InCond(E_TFCOND.TFCond_Bonked) then
			goto continue
		elseif settings.ignore.deadringer and entity:InCond(E_TFCOND.TFCond_DeadRingered) then
			goto continue
		elseif settings.ignore.disguised and entity:InCond(E_TFCOND.TFCond_Disguised) then
			goto continue
		elseif settings.ignore.friends and playerlist.GetPriority(entity) == -1 then
			goto continue
		elseif settings.ignore.taunting and entity:InCond(E_TFCOND.TFCond_Taunting) then
			goto continue
		end

		local enemy_class = entity:GetPropInt("m_PlayerClass", "m_iClass")
		local best_bone_for_weapon = nil

		if should_aim_at_head == nil then
			goto continue
		elseif should_aim_at_head == true then
			best_bone_for_weapon = CLASS_HITBOXES[enemy_class][1]
		elseif should_aim_at_head == false then
			best_bone_for_weapon = #CLASS_HITBOXES[enemy_class] == 6 and CLASS_HITBOXES[enemy_class][2]
				or CLASS_HITBOXES[enemy_class][3] --- if size is 6 then we have no HeadUpper as the first value
		end

		local bones = entity:SetupBones()
		if not bones then goto continue end

		local bone_position = GetBoneOrigin(bones[best_bone_for_weapon])
		if not bone_position then goto continue end

		local trace = TraceLine(shoot_pos, bone_position, MASK_SHOT_HULL)
		if not trace then goto continue end

		local looking_at_trace =
			TraceLine(shoot_pos, shoot_pos + engine:GetViewAngles():Forward() * 1000, MASK_SHOT_HULL)
		if not looking_at_trace then
			goto continue
		end

		local function do_aimbot_calc()
			local angle = ToAngle(bone_position - shoot_pos) - (usercmd.viewangles - punchangles)
			local fov = sqrt((angle.x ^ 2) + (angle.y ^ 2))

			if fov < best_fov then
				best_fov = fov
				best_angle = angle
				target = entity:GetIndex() --- not saving the whole entity here, too much memory used!
				return true
			end
			return false
		end

		if trace and trace.entity == entity and trace.fraction >= VISIBLE_FRACTION then
			--- for smooth aimbot, ensure we are aiming somewhat close to the target so we can shoot
			if looking_at_trace and looking_at_trace.entity and looking_at_trace.entity == entity then
				looking_at_target = true
			end

			do_aimbot_calc()
		else
			local BONES = CLASS_HITBOXES[enemy_class]
			for _, bone in ipairs(BONES) do
				--- already tried the best one
				if bone ~= best_bone_for_weapon then
					bone_position = GetBoneOrigin(bones[bone])
					if not bone_position then goto skip_bone end

					trace = TraceLine(shoot_pos, bone_position, MASK_SHOT_HULL)
					if not trace then goto skip_bone end

					if trace.entity == entity and trace.fraction >= VISIBLE_FRACTION then
						if
							not looking_at_target and looking_at_trace
							and looking_at_trace.entity and looking_at_trace.entity == entity
							and looking_at_trace.hitbox ~= 0 then
							looking_at_target = true
						end

						do_aimbot_calc()
					end
				end
				::skip_bone::
			end
		end
		::continue::
	end

	if settings.aim.sentries then
		CheckBuilding(Sentries)
	end

	if settings.aim.other_buildings then
		CheckBuilding(Dispensers)
		CheckBuilding(Teleporters)
	end

	local can_shoot = CanWeaponShoot() or settings.lock_aim -- if autoshoot is off and player is trying to shoot, we aim for them

	if best_angle then
		local smoothed = engine:GetViewAngles() + vecMultiply(best_angle, (m_SmoothValue * 0.01 --[[/100]]))
		if can_shoot then
			usercmd.viewangles = usercmd.viewangles + (m_AimbotMode == aimbot_mode.smooth and smoothed or best_angle)
		end

		if m_AimbotMode == aimbot_mode.plain and can_shoot then
			local angle = engine:GetViewAngles() + best_angle
			engine.SetViewAngles(EulerAngles(angle:Unpack()))
		elseif m_AimbotMode == aimbot_mode.smooth then
			engine.SetViewAngles(EulerAngles(smoothed:Unpack()))
			usercmd.viewangles = smoothed
		end

		if can_shoot then
			if m_AimbotMode ~= aimbot_mode.smooth then
				usercmd.buttons = usercmd.buttons | IN_ATTACK
			else
				if looking_at_target then
					usercmd.buttons = usercmd.buttons | IN_ATTACK
				end

			end
			GB_GLOBALS.m_bIsAimbotShooting = true
			GB_GLOBALS.m_nAimbotTarget = target
		end
	end

	if (settings.auto_spinup and weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_MINIGUN and usercmd.buttons & IN_ATTACK == 0) then
		usercmd.buttons = usercmd.buttons | IN_ATTACK2
	end
end

---@param stage E_ClientFrameStage
local function FrameStageNotify(stage)
	if stage == E_ClientFrameStage.FRAME_NET_UPDATE_END and localplayer and weapon then
		m_bReadyToBackstab = weapon:GetPropBool("m_bReadyToBackstab") or false
	end
end

local function Draw()
	if not settings.aimfov then return end
	if (engine:IsGameUIVisible() or engine:Con_IsVisible()) then return end

	if localplayer and localplayer:IsAlive() and settings.fov <= 89 then
		local viewfov = GB_GLOBALS.m_flCustomFOV
		local aimfov = settings.fov * (math.tan(math.rad(viewfov / 2)) / math.tan(math.rad(45)))
		if (not aimfov or not viewfov) then return end --- wtf why is it a "number?"
		local radius = (math.tan(math.rad(aimfov)/2))/(math.tan(math.rad(viewfov)/2)) * width
		draw.Color(255,255,255,255)
		draw.OutlinedCircle(math.floor(width/2), math.floor(height/2), math.floor(radius), 64)
	end
end

local function cmd_ChangeAimbotMode(args)
	if (not args or #args == 0) then return end
	local mode = tostring(args[1])
	settings.mode = aimbot_mode[mode]
end

local function cmd_ChangeAimbotKey(args)
	if (not args or #args == 0) then return end

	local key = string.upper(tostring(args[1]))

	local selected_key = E_ButtonCode["KEY_" .. key]
	if (not selected_key) then print("Invalid key!") return end

	settings.key = selected_key
end

local function cmd_ChangeAimbotFov(args)
	if (not args or #args == 0 or not args[1]) then return end
	settings.fov = tonumber(args[1])
end

local function cmd_ChangeAimbotIgnore(args)
	if (not args or #args == 0) then return end
	if (not args[1] or not args[2]) then return end

	local option = tostring(args[1])
	local ignoring = settings.ignore[option] and "aiming for" or "ignoring"

	settings.ignore[option] = not settings.ignore[option]

	printc(150, 255, 150, 255, "Aimbot is now " .. ignoring .. " " .. option)
end

local function cmd_ToggleAimLock()
	settings.lock_aim = not settings.lock_aim
	printc(150, 255, 150, 255, "Aim lock is now " .. (settings.lock_aim and "enabled" or "disabled"))
end

local function cmd_ToggleAimFov()
	settings.aimfov = not settings.aimfov
end

GB_GLOBALS.RegisterCommand("aimbot->change_mode", "Change aimbot mode | args: mode (plain, smooth or silent)", 1, cmd_ChangeAimbotMode)
GB_GLOBALS.RegisterCommand("aimbot->change_key", "Changes aimbot key | args: key (w, f, g, ...)", 1, cmd_ChangeAimbotKey)
GB_GLOBALS.RegisterCommand("aimbot->change_fov", "Changes aimbot fov | args: fov (number)", 1, cmd_ChangeAimbotFov)
GB_GLOBALS.RegisterCommand("aimbot->ignore->toggle", "Toggles a aimbot ignore option (like ignore cloaked) | args: option name (string)", 1, cmd_ChangeAimbotIgnore)
GB_GLOBALS.RegisterCommand("aimbot->toggle->aimlock", "Makes the aimbot not stop looking at the targe when shooting", 0, cmd_ToggleAimLock)
GB_GLOBALS.RegisterCommand("aimbot->toggle->fovindicator", "Toggles aim fov circle", 0, cmd_ToggleAimFov)

local aimbot = {}
aimbot.CreateMove = CreateMove
aimbot.FrameStageNotify = FrameStageNotify
aimbot.Draw = Draw

return aimbot
