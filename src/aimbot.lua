local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "aimbot: gb is nil!")
assert(gb_settings, "aimbot: GB_SETTINGS is nil!")

local bReadyToBackstab = false

---@type Entity?, Entity?, integer?
local localplayer, weapon, m_team = nil, nil, nil

local width, height = draw.GetScreenSize()

--- TODO: rename later to CLASS_BONES
local CLASS_HITBOXES = require("src.hitboxes")

local HEADSHOT_WEAPONS_INDEXES = {
	[230] = true, --- SYDNEY SLEEPER
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
local PI = math.pi
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

---@param bone Matrix3x4
local function GetBoneOrigin(bone)
	return Vector3(bone[1][4], bone[2][4], bone[3][4])
end

---@param usercmd UserCmd
---@param targetIndex integer
local function MakeWeaponShoot(usercmd, targetIndex)
	usercmd.buttons = usercmd.buttons | IN_ATTACK
	gb.nAimbotTarget = targetIndex
	gb.bIsAimbotShooting = true
end

--- Only run this in CreateMove, after localplayer and weapon are valid!
---@param usercmd UserCmd
local function RunMelee(usercmd)
	if not weapon then return end
	if weapon:IsMeleeWeapon() then
		local swing_trace = weapon:DoSwingTrace()

		if swing_trace and swing_trace.entity and swing_trace.fraction >= gb.flVisibleFraction then
			local entity = swing_trace.entity
			local entity_team = entity:GetTeamNumber()
			local index = entity:GetIndex()

			if entity_team ~= m_team and entity:IsAlive() then
				if weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_KNIFE then
					return
				end

				if gb_settings.aimbot.ignore.cloaked and entity:InCond(E_TFCOND.TFCond_Cloaked) then
					return
				end

				MakeWeaponShoot(usercmd, index)
				return true
			end
		end
	end
	return false
end

local function calc_fov(fov, aspect_ratio)
	local halfanglerad = fov * (0.5 * math.pi / 180)
	local t = math.tan(halfanglerad) * (aspect_ratio / (4/3))
	local ret = (180 / math.pi) * math.atan(t)
	return ret * 2
end

---@param usercmd UserCmd
local function CreateMove(usercmd)
	gb.bIsAimbotShooting = false
	gb.nAimbotTarget = nil

	--- if antiaim is enabled or we aren't sending the packet for some reason
	--- dont run the aimbot, could be detected as psilent on a community server
	if not usercmd.sendpacket then return end

	if (gb.bSpectated and not gb_settings.aimbot.ignore.spectators) or not gb_settings.aimbot.enabled then
		return
	end

	localplayer = entities:GetLocalPlayer()
	if not localplayer or not localplayer:IsAlive() then return end
	m_team = localplayer:GetTeamNumber()

	weapon = localplayer:GetPropEntity("m_hActiveWeapon")
	if not weapon then return end

	if not input.IsButtonDown(gb_settings.aimbot.key) then return end
	if engine.IsChatOpen() then return end

	if (gb_settings.aimbot.auto_spinup and weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_MINIGUN) then
		usercmd.buttons = usercmd.buttons | IN_ATTACK2
	end
	
	if weapon:IsMeleeWeapon() then RunMelee(usercmd) return end

	if (weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0) then return end

	--- try to make stac dont ban us :3
	local m_AimbotMode = gb.bIsStacRunning and gb.aimbot_modes.smooth or gb_settings.aimbot.mode
	local m_SmoothValue = gb.bIsStacRunning and 20 or gb_settings.aimbot.smooth_value
	local m_nAspectRatio = (gb.nAspectRatio == 0 and gb.nPreAspectRatio or gb.nAspectRatio)
	local viewfov =  calc_fov(localplayer:InCond(E_TFCOND.TFCond_Zoomed) and 20 or gb.flCustomFOV, m_nAspectRatio)
	local m_Fov = gb_settings.aimbot.fov * (math.tan(math.rad(viewfov / 2)) / math.tan(math.rad(45)))

	local shoot_pos = GetShootPosition()
	if not shoot_pos then
		return
	end

	local punchangles = weapon:GetPropVector("m_vecPunchAngle") or Vector3()
	local should_aim_at_head = ShouldAimAtHead()

	--- trust me, i tried like 3 or 4 different math combinations
	--- and i decided to just give up and paste amalgam for the fov xd

	---@type EulerAngles?
	local best_angle, best_fov, target = nil, m_Fov, nil

	---@param class Entity[]
	local function CheckBuilding(class)
		for _, entity in pairs(class) do
			local mins, maxs = entity:GetMins(), entity:GetMaxs()
			local center = entity:GetAbsOrigin() + ((mins + maxs) * 0.5)

			local trace = TraceLine(shoot_pos, center, MASK_SHOT_HULL)
			if trace and trace.entity == entity and trace.fraction >= gb.flVisibleFraction then
				local angle = gb.ToAngle(center - shoot_pos) - (usercmd.viewangles - punchangles)
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
		elseif entity:InCond(E_TFCOND.TFCond_Cloaked) and gb_settings.aimbot.ignore.cloaked then
			goto continue
		elseif gb_settings.aimbot.ignore.bonked and entity:InCond(E_TFCOND.TFCond_Bonked) then
			goto continue
		elseif gb_settings.aimbot.ignore.deadringer and entity:InCond(E_TFCOND.TFCond_DeadRingered) then
			goto continue
		elseif gb_settings.aimbot.ignore.disguised and entity:InCond(E_TFCOND.TFCond_Disguised) then
			goto continue
		elseif gb_settings.aimbot.ignore.friends and playerlist.GetPriority(entity) == -1 then
			goto continue
		elseif gb_settings.aimbot.ignore.taunting and entity:InCond(E_TFCOND.TFCond_Taunting) then
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

		local function do_aimbot_calc()
			local angle = gb.ToAngle(bone_position - shoot_pos) - (usercmd.viewangles - punchangles)
			local fov = sqrt((angle.x ^ 2) + (angle.y ^ 2))

			if fov < best_fov then
				best_fov = fov
				best_angle = angle
				target = entity:GetIndex() --- not saving the whole entity here, too much memory used!
				return true
			end
			return false
		end

		if trace and trace.entity == entity and trace.fraction >= gb.flVisibleFraction then
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
					if trace.entity == entity and trace.fraction >= gb.flVisibleFraction then
						do_aimbot_calc()
					end
				end
				::skip_bone::
			end
		end
		::continue::
	end

	if gb_settings.aimbot.aim.sentries then
		CheckBuilding(Sentries)
	end

	if gb_settings.aimbot.aim.other_buildings then
		CheckBuilding(Dispensers)
		CheckBuilding(Teleporters)
	end

	local can_shoot = gb.CanWeaponShoot() or gb_settings.aimbot.lock_aim -- if autoshoot is off and player is trying to shoot, we aim for them

	if best_angle and target then
		local viewangle = engine:GetViewAngles()

		local smoothval = vecMultiply(best_angle, (m_SmoothValue * 0.01 --[[/100]]))

		if gb_settings.aimbot.humanized_smooth then
			smoothval.x = smoothval.x * engine.RandomFloat(0.5, 5)
			smoothval.y = smoothval.y * engine.RandomFloat(0.5, 5)
		end

		local smoothed = viewangle + smoothval
		local angle = viewangle + best_angle
		local distance = math.sqrt(best_angle.x^2 + best_angle.y^2)

		if can_shoot then
			if m_AimbotMode == gb.aimbot_modes.smooth or m_AimbotMode == gb.aimbot_modes.assistance then
				if distance <= 1 then
					--usercmd.buttons = usercmd.buttons | IN_ATTACK
					MakeWeaponShoot(usercmd, target)
				end
			else
				if gb_settings.aimbot.autoshoot then
					MakeWeaponShoot(usercmd, target)
				end
			end
		end

		local bIsShooting = usercmd.buttons & IN_ATTACK == 1

		if m_AimbotMode == gb.aimbot_modes.plain and can_shoot and bIsShooting then
			engine.SetViewAngles(EulerAngles(angle:Unpack()))
		elseif m_AimbotMode == gb.aimbot_modes.smooth then
			engine.SetViewAngles(EulerAngles(smoothed:Unpack()))
			usercmd.viewangles = smoothed
		elseif m_AimbotMode == gb.aimbot_modes.assistance and (usercmd.mousedx ~= 0 or usercmd.mousedy ~= 0) then
			usercmd.viewangles = smoothed
			engine.SetViewAngles(EulerAngles(smoothed:Unpack()))
		elseif m_AimbotMode == gb.aimbot_modes.silent and can_shoot and bIsShooting then
			usercmd.viewangles = usercmd.viewangles + best_angle
		end

		--- im not gonna do individually all of them
		--- even if inlining is probably better
		if m_AimbotMode == gb.aimbot_modes.smooth then
			usercmd.mousedx = math.floor(smoothval.x)
			usercmd.mousedy = math.floor(smoothval.y)
		else
			usercmd.mousedx = math.floor(angle.x)
			usercmd.mousedy = math.floor(angle.y)
		end
	end
end

local function Draw()
	if not gb_settings.aimbot.aimfov or not gb_settings.aimbot.enabled then return end
	if (engine:IsGameUIVisible() or engine:Con_IsVisible()) then return end

	if localplayer and localplayer:IsAlive() and gb_settings.aimbot.fov <= 89 then
		local viewfov = gb.flCustomFOV
		local aspectratio = (gb.nAspectRatio == 0 and gb.nPreAspectRatio or gb.nAspectRatio)
		viewfov = calc_fov(viewfov, aspectratio)
		local aimfov = gb_settings.aimbot.fov * (math.tan(math.rad(viewfov / 2)) / math.tan(math.rad(45)))
		if (not aimfov or not viewfov) then return end --- wtf why is it a "number?"
		local radius = (math.tan(math.rad(aimfov)/2))/(math.tan(math.rad(viewfov)/2)) * width
		draw.Color(255,255,255,255)
		draw.OutlinedCircle(math.floor(width/2), math.floor(height/2), math.floor(radius), 64)
	end
end

local function cmd_ChangeAimbotMode(args)
	if (not args or #args == 0) then return end
	local mode = tostring(args[1])
	gb_settings.aimbot.mode = gb.aimbot_modes[mode]
end

local function cmd_ChangeAimbotKey(args)
	if (not args or #args == 0) then return end

	local key = string.upper(tostring(args[1]))

	local selected_key = E_ButtonCode["KEY_" .. key]
	if (not selected_key) then print("Invalid key!") return end

	gb_settings.aimbot.key = selected_key
end

local function cmd_ChangeAimbotFov(args)
	if (not args or #args == 0 or not args[1]) then return end
	gb_settings.aimbot.fov = tonumber(args[1])
end

local function cmd_ChangeAimbotIgnore(args)
	if (not args or #args == 0) then return end
	if (not args[1] or not args[2]) then return end

	local option = tostring(args[1])
	local ignoring = gb_settings.aimbot.ignore[option] and "aiming for" or "ignoring"

	gb_settings.aimbot.ignore[option] = not gb_settings.aimbot.ignore[option]

	printc(150, 255, 150, 255, "Aimbot is now " .. ignoring .. " " .. option)
end

local function cmd_ToggleAimLock()
	gb_settings.aimbot.lock_aim = not gb_settings.aimbot.lock_aim
	printc(150, 255, 150, 255, "Aim lock is now " .. (gb_settings.aimbot.lock_aim and "enabled" or "disabled"))
end

local function cmd_ToggleAimFov()
	gb_settings.aimbot.aimfov = not gb_settings.aimbot.aimfov
end

local function cmd_ChangeAimSmoothness(args, num_args)
	if not args or #args ~= num_args then return end
	local new_value = tonumber(args[1])
	if not new_value then printc(255, 150, 150, 255, "Invalid value!") return end
	gb_settings.aimbot.smooth_value = new_value
end

gb.RegisterCommand("aimbot->change->mode", "Change aimbot mode | args: mode (plain, smooth or silent)", 1, cmd_ChangeAimbotMode)
gb.RegisterCommand("aimbot->change->key", "Changes aimbot key | args: key (w, f, g, ...)", 1, cmd_ChangeAimbotKey)
gb.RegisterCommand("aimbot->change->fov", "Changes aimbot fov | args: fov (number)", 1, cmd_ChangeAimbotFov)
gb.RegisterCommand("aimbot->ignore->toggle", "Toggles a aimbot ignore option (like ignore cloaked) | args: option name (string)", 1, cmd_ChangeAimbotIgnore)
gb.RegisterCommand("aimbot->toggle->aimlock", "Makes the aimbot not stop looking at the targe when shooting", 0, cmd_ToggleAimLock)
gb.RegisterCommand("aimbot->toggle->fovindicator", "Toggles aim fov circle", 0, cmd_ToggleAimFov)
gb.RegisterCommand("aimbot->change->smoothness", "Changes the smoothness value | args: new value (number, 0 to 1)", 1, cmd_ChangeAimSmoothness)

local aimbot = {}
aimbot.CreateMove = CreateMove
aimbot.Draw = Draw

local function unload()
	localplayer, weapon, m_team = nil, nil, nil
	width, height = nil, nil
	CLASS_HITBOXES = nil
	HEADSHOT_WEAPONS_INDEXES = nil
	TraceLine = nil
	sqrt = nil
	vecMultiply = nil
	aimbot = nil
end

aimbot.unload = unload
return aimbot
