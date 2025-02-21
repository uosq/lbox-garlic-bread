--[[ Made by navet ]]
-- Bundled by luabundle {"version":"1.7.0"}
local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
	local loadingPlaceholder = {[{}] = true}

	local register
	local modules = {}

	local require
	local loaded = {}

	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	require = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name](require, loaded, register, modules)
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return require, loaded, register, modules
end)(require)
__bundle_register("__root", function(require, _LOADED, __bundle_register, __bundle_modules)
require("src.globals")
require("src.bitbuf")
require("src.anticheat")

local aimbot = require("src.aimbot")
local tickshift = require("src.tickshift")
local antiaim = require("src.antiaim")
local visuals = require("src.visuals")
local movement = require("src.movement")

require("src.background")
require("src.commands")

--aimbot:SetDebug(false)

callbacks.Unregister("CreateMove", "CM garlic bread cheat aimbot")
callbacks.Register("CreateMove", "CM garlic bread cheat aimbot", aimbot.CreateMove)
callbacks.Unregister("FrameStageNotify", "FSN garlic bread cheat aimbot frame stage")
callbacks.Register("FrameStageNotify", "FSN garlic bread cheat aimbot frame stage", aimbot.FrameStageNotify)
callbacks.Unregister("Draw", "DRAW garlic bread aimbot")
callbacks.Register("Draw", "DRAW garlic bread aimbot", aimbot.Draw)

callbacks.Unregister("CreateMove", "CM garlic bread tick shifting")
callbacks.Register("CreateMove", "CM garlic bread tick shifting", tickshift.CreateMove)
callbacks.Unregister("SendNetMsg", "NETMSG garlic bread tick shifting")
callbacks.Register("SendNetMsg", "NETMSG garlic bread tick shifting", tickshift.SendNetMsg)
callbacks.Unregister("Draw", "DRAW garlic bread tick shifting")
callbacks.Register("Draw", "DRAW garlic bread tick shifting", tickshift.Draw)

callbacks.Unregister("CreateMove", "CM garlic bread anti aim")
callbacks.Register("CreateMove", "CM garlic bread anti aim", antiaim.CreateMove)

callbacks.Unregister("RenderView", "RV garlic bread custom fov")
callbacks.Register("RenderView", "RV garlic bread custom fov", visuals.CustomFOV)

callbacks.Unregister("CreateMove", "CM garlic bread movement")
callbacks.Register("CreateMove", "CM garlic bread movement", movement.CreateMove)

callbacks.Register("Unload", "UL garlic bread unload", function()
	antiaim.unload()
	GB_GLOBALS = nil
	collectgarbage("collect")
end)

end)
__bundle_register("src.commands", function(require, _LOADED, __bundle_register, __bundle_modules)
local setvar = "setvar"
local getvars = "getvars"

---@param cmd StringCmd
local function SendStringCmd(cmd)
	if not GB_GLOBALS then
		return
	end
	local sent_command = cmd:Get()
	if sent_command:find(setvar) then
		local words = {}
		for word in string.gmatch(sent_command, "%S+") do
			words[#words + 1] = word
		end

		table.remove(words, 1)
		local var = table.remove(words, 1)

		if GB_GLOBALS[var] == nil then
			cmd:Set("echo Couldnt find var!")
			return
		elseif type(GB_GLOBALS[var]) == "function" then
			GB_GLOBALS[var]()
			cmd:Set("")
			return
		end

		local value = table.remove(words, 1)

		if value == "true" then
			value = true
		elseif value == "false" then
			value = false
		elseif string.find(var, "ang") or string.find(var, "vec") then --- assume its a EulerAngles or Vector3
			local mode = string.find(var, "ang") and "euler" or "vec"
			local x, y, z = table.remove(words, 1), table.remove(words, 1), table.remove(words, 1)
			x, y, z = tonumber(x), tonumber(y), tonumber(z)
			if mode == "vector" then
				value = Vector3(x, y, z)
			elseif mode == "euler" then
				value = EulerAngles(x, y, z)
			end
		else
			value = tonumber(value)
		end

		GB_GLOBALS[var] = value

		cmd:Set("")
	elseif sent_command:find(getvars) then
		for name, value in pairs(GB_GLOBALS) do
			printc(255, 255, 255, 255, name .. " = " .. tostring(value))
		end
		cmd:Set("")
	end
end

printc(
	200,
	255,
	200,
	255,
	"Guide on how to use the commands",
	"setvar -> sets the variable",
	"getvars -> prints all the variables here",
	" ",
	"example:",
	"setvar m_bNoRecoil false",
	"setvar m_vecShootPos vector 200 150 690",
	"setvar m_angViewAngles euler 420 159 69",
	" ",
	"you can run a function by just putting their name",
	"like this: setvar toggle_real_yaw"
)

callbacks.Register("SendStringCmd", "SSC garlic bread console commands", SendStringCmd)

end)
__bundle_register("src.background", function(require, _LOADED, __bundle_register, __bundle_modules)
local function Background()
	if clientstate:GetNetChannel() then
		Players = entities.FindByClass("CTFPlayer")
		Sentries = entities.FindByClass("CObjectSentrygun")
		Dispensers = entities.FindByClass("CObjectDispenser")
		Teleporters = entities.FindByClass("CObjectTeleporter")
	else
		Players, Sentries, Dispensers, Teleporters = nil, nil, nil, nil
	end
end

callbacks.Register("CreateMove", "CM garlic bread background", Background)

end)
__bundle_register("src.movement", function(require, _LOADED, __bundle_register, __bundle_modules)
local movement = {}

---@param usercmd UserCmd
local function CreateMove(usercmd)
	if GB_GLOBALS then
		local localplayer = entities:GetLocalPlayer()
		if not localplayer or not localplayer:IsAlive() then
			return
		end

		if GB_GLOBALS.m_bBhopEnabled then
			local flags = localplayer:GetPropInt("m_fFlags")
			local ground = flags & FL_ONGROUND == 1
			local jump = usercmd.buttons & IN_JUMP == 1
			if ground and jump then
				usercmd.buttons = usercmd.buttons | IN_JUMP
			elseif (not ground and jump) or (not ground and not jump) then
				usercmd.buttons = usercmd.buttons & ~IN_JUMP
			end
		end
	end
end

movement.CreateMove = CreateMove

return movement

end)
__bundle_register("src.visuals", function(require, _LOADED, __bundle_register, __bundle_modules)
local visuals = {}

---@param setup ViewSetup
local function CustomFOV(setup)
	if not GB_GLOBALS then
		return
	end

	GB_GLOBALS.m_nPreAspectRatio = setup.aspectRatio
	setup.aspectRatio = GB_GLOBALS.m_nAspectRatio == 0 and setup.aspectRatio or GB_GLOBALS.m_nAspectRatio

	if GB_GLOBALS.m_hLocalPlayer then
		local fov = GB_GLOBALS.m_hLocalPlayer:InCond(E_TFCOND.TFCond_Zoomed) and 20 or GB_GLOBALS.m_flCustomFOV
		setup.fov = fov

		if GB_GLOBALS.m_bNoRecoil and GB_GLOBALS.m_hLocalPlayer:GetPropInt("m_nForceTauntCam") == 0 then
			local punchangle = GB_GLOBALS.m_hLocalPlayer:GetPropVector("m_vecPunchAngle")
			setup.angles = EulerAngles((setup.angles - punchangle):Unpack())
		end
	end
end

visuals.CustomFOV = CustomFOV

return visuals

end)
__bundle_register("src.antiaim", function(require, _LOADED, __bundle_register, __bundle_modules)
---@diagnostic disable:cast-local-type
local antiaim = {}

---@param usercmd UserCmd
function antiaim.CreateMove(usercmd)
	if
		not GB_GLOBALS.m_bIsAimbotShooting
		and GB_GLOBALS.m_bAntiAimEnabled
		and usercmd.buttons & IN_ATTACK == 0
		and not GB_GLOBALS.m_bIsStacRunning
		and not GB_GLOBALS.m_bWarping
		and not GB_GLOBALS.m_bRecharging
	then
		--- make sure we aren't overchoking
		if clientstate:GetChokedCommands() >= 21 then
			usercmd.sendpacket = true
			return
		end

		local view = engine:GetViewAngles()
		local m_realyaw = view.y + (GB_GLOBALS.anti_aim.real_yaw and GB_GLOBALS.m_flRealYaw or 0)
		local m_fakeyaw = view.y + (GB_GLOBALS.anti_aim.fake_yaw and GB_GLOBALS.m_flFakeYaw or 0)
		if usercmd.tick_count % 2 == 0 then
			usercmd:SetViewAngles(GB_GLOBALS.anti_aim.real_pitch and GB_GLOBALS.m_flRealPitch or view.x, m_realyaw, 0)
			usercmd.sendpacket = false
		else
			--view = view + Vector3(m_settings.pitch.fake, m_fakeyaw, 0)
			usercmd:SetViewAngles(GB_GLOBALS.anti_aim.fake_pitch and GB_GLOBALS.m_flFakePitch or view.x, m_fakeyaw, 0)
		end
	end
end

function antiaim.unload()
	antiaim = nil
end

return antiaim

end)
__bundle_register("src.tickshift", function(require, _LOADED, __bundle_register, __bundle_modules)
local NEW_COMMANDS_SIZE = 4
local BACKUP_COMMANDS_SIZE = 3

local SIGNONSTATE_TYPE = 6
local CLC_MOVE_TYPE = 9

local charged_ticks = 0
local max_ticks = 0
local last_key_tick = 0
local next_passive_tick = 0

local shooting = false

local font = draw.CreateFont("TF2 BUILD", 16, 1000)

---@type number, boolean
local m_localplayer_speed, m_bIsRED
m_bIsRED = false

local function clc_Move()
	local moveMsg = { m_nNewCommands = 2, m_nBackupCommands = 1, buffer = BitBuffer() }

	setmetatable(moveMsg, {
		__close = function(this)
			this.m_nBackupCommands = nil
			this.m_nNewCommands = nil
			this.buffer:Delete()
			this.buffer = nil
		end,
	})

	function moveMsg:init()
		self.buffer:Reset()
		self.buffer:WriteInt(self.m_nNewCommands, NEW_COMMANDS_SIZE)
		self.buffer:WriteInt(self.m_nBackupCommands, BACKUP_COMMANDS_SIZE)
		self.buffer:Reset()
	end

	return moveMsg
end

local m_settings = {
	warp = {
		send_key = E_ButtonCode.MOUSE_5,
		recharge_key = E_ButtonCode.MOUSE_4,
		while_shooting = false,
		standing_still = false,

		recharge = {
			while_shooting = false,
			standing_still = true,
		},

		passive = {
			enabled = true,
			while_dead = true,
			min_time = 0.5,
			max_time = 5,
			toggle_key = E_ButtonCode.KEY_R,
		},
	},
}

local tickshift = {}

local function CanChoke()
	return clientstate:GetChokedCommands() < max_ticks
end

local function CanShift()
	return clientstate:GetChokedCommands() == 0
end

local function GetMaxServerTicks()
	local sv_maxusrcmdprocessticks = client.GetConVar("sv_maxusrcmdprocessticks")
	if sv_maxusrcmdprocessticks then
		return sv_maxusrcmdprocessticks > 0 and sv_maxusrcmdprocessticks or 9999999
	end
	return 24
end

---@param msg NetMessage
function HandleWarp(msg)
	if GB_GLOBALS.m_hLocalPlayer and m_localplayer_speed <= 0 and not m_settings.warp.standing_still then
		return
	end

	if
		GB_GLOBALS.m_bIsAimbotShooting
		and GB_GLOBALS.usercmd_buttons
		and GB_GLOBALS.usercmd_buttons & IN_ATTACK ~= 0
	then
		return
	end

	if GB_GLOBALS.m_hLocalPlayer and GB_GLOBALS.m_hLocalPlayer:IsAlive() and charged_ticks > 0 and CanShift() then
		--local moveMsg = clc_Move()

		--- the new BitBuffer lib
		local buffer = BitBuffer()
		buffer:Reset()
		CLC_Move:WriteToBitBuffer(buffer, 2, 1)
		msg:ReadFromBitBuffer(buffer)
		buffer:Delete()

		--moveMsg:init()
		--msg:ReadFromBitBuffer(moveMsg.buffer)
		charged_ticks = charged_ticks - 1
	end
end

local function HandlePassiveRecharge()
	assert(GB_GLOBALS.m_hLocalPlayer, "HandlePassiveRecharge: m_localplayer is nil!")
	if not m_settings.warp.passive.enabled or charged_ticks >= max_ticks then
		return false
	end

	if
		(globals.TickCount() >= next_passive_tick)
		or (m_settings.warp.passive.while_dead and not GB_GLOBALS.m_hLocalPlayer:IsAlive())
	then
		charged_ticks = charged_ticks + 1
		local time = engine.RandomFloat(m_settings.warp.passive.min_time, m_settings.warp.passive.max_time)
		next_passive_tick = globals.TickCount() + (time * 66.67)
		return true
	end

	return false
end

local function HandleRecharge()
	if
		(shooting and not m_settings.warp.recharge.while_shooting)
		or (m_localplayer_speed <= 0 and not m_settings.warp.recharge.standing_still)
	then
		return false
	end

	if CanChoke() and charged_ticks < max_ticks and GB_GLOBALS.m_bRecharging then
		charged_ticks = charged_ticks + 1
		return true
	end

	if HandlePassiveRecharge() then
		return true
	end

	return false
end

--- Resets the variables to their default state when joining a new server
---@param msg NetMessage
local function HandleJoinServers(msg)
	if clientstate:GetClientSignonState() == E_SignonState.SIGNONSTATE_SPAWN then
		m_localplayer_speed = 0
		m_bIsRED = false
		max_ticks = GetMaxServerTicks()
		charged_ticks = 0
		last_key_tick = 0
		next_passive_tick = 0
		shooting = false
	end
end

---@param msg NetMessage
---@param reliable boolean
---@param isvoice boolean
function tickshift.SendNetMsg(msg, reliable, isvoice)
	if msg:GetType() == SIGNONSTATE_TYPE then
		HandleJoinServers(msg)
	end

	if GB_GLOBALS.m_bIsStacRunning then
		return true
	end

	if engine.IsChatOpen() or engine.IsGameUIVisible() or engine.Con_IsVisible() then
		return true
	end

	if msg:GetType() == CLC_MOVE_TYPE then
		if GB_GLOBALS.m_bWarping and not GB_GLOBALS.m_bRecharging then
			HandleWarp(msg)
		elseif HandleRecharge() then
			return false
		end
	end

	return true
end

local function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

---@param usercmd UserCmd
function tickshift.CreateMove(usercmd)
	if engine.IsChatOpen() or engine.IsGameUIVisible() or engine.Con_IsVisible() or not GB_GLOBALS.m_hLocalPlayer then
		return
	end

	m_localplayer_speed = GB_GLOBALS.m_hLocalPlayer and GB_GLOBALS.m_hLocalPlayer:EstimateAbsVelocity():Length() or 0
	m_bIsRED = GB_GLOBALS.m_hLocalPlayer:GetTeamNumber() == 2
	max_ticks = GetMaxServerTicks()
	charged_ticks = clamp(charged_ticks, 0, max_ticks)

	GB_GLOBALS.m_bWarping = input.IsButtonDown(m_settings.warp.send_key)
	GB_GLOBALS.m_bRecharging = input.IsButtonDown(m_settings.warp.recharge_key)

	shooting = (usercmd.buttons & IN_ATTACK) ~= 0 or GB_GLOBALS.m_bIsAimbotShooting

	local state, tick = input.IsButtonPressed(m_settings.warp.passive.toggle_key)
	if state and last_key_tick < tick then
		m_settings.warp.passive.enabled = not m_settings.warp.passive.enabled
		last_key_tick = tick
		client.ChatPrintf("Passive recharge: " .. (m_settings.warp.passive.enabled and "ON" or "OFF"))
	end
end

function tickshift.Draw()
	if
		engine:Con_IsVisible()
		or engine:IsGameUIVisible()
		or (engine:IsTakingScreenshot() and gui.GetValue("clean screenshots") == 1)
	then
		return
	end

	local screenX, screenY = draw:GetScreenSize()
	local centerX, centerY = math.floor(screenX / 2), math.floor(screenY / 2)

	local formatted_text = string.format("%i / %i", charged_ticks, max_ticks)
	draw.SetFont(font)
	local textW, textH = draw.GetTextSize(formatted_text)
	local textX, textY = math.floor(centerX - (textW / 2)), math.floor(centerY + textH + 20)

	local barWidth = 80
	local offset = 2
	local percent = charged_ticks / max_ticks
	local barX, barY = centerX - math.floor(barWidth / 2), math.floor(centerY + textH + 20)

	draw.Color(30, 30, 30, 252)
	draw.FilledRect(
		math.floor(barX - offset),
		math.floor(barY - offset),
		math.floor(barX + barWidth + offset),
		math.floor(barY + textH + offset)
	)

	local color = m_bIsRED and { 236, 57, 57, 255 } or { 12, 116, 191, 255 }
	draw.Color(table.unpack(color))

	pcall(
		draw.FilledRect,
		math.floor(barX or 0),
		math.floor(barY or 0),
		math.floor((barX or 0) + ((barWidth * (percent or 0)) or 0)),
		math.floor((barY or 0) + (textH or 0))
	)

	draw.SetFont(font)
	draw.Color(255, 255, 255, 255)
	draw.TextShadow(textX, textY, formatted_text)
end

return tickshift

end)
__bundle_register("src.aimbot", function(require, _LOADED, __bundle_register, __bundle_modules)
local aimbot_mode = { plain = 1, smooth = 2, silent = 3 }

local settings = {
	fov = 30,
	key = E_ButtonCode.KEY_LSHIFT,
	autoshoot = true,
	mode = aimbot_mode.silent,
	lock_aim = false,
	smooth_value = 35, --- lower value, smoother aimbot (10 = very smooth, 100 = basically plain aimbot)
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
		other_buildings = true,
	},
}

local m_bReadyToBackstab = false

---@type Entity?, Entity?, integer?
local localplayer, weapon, m_team = nil, nil, nil

local width, height = draw.GetScreenSize()

--- TODO: rename later to CLASS_BONES
local CLASS_HITBOXES = require("src.hitboxes")

--- only works with STUDIO models
--[[local HITBOXES = {
	Head = 6,
	Body = 3,
	--LeftHand = 9,
	LeftArm = 8,
	--RightHand = 12,
	RightArm = 11,
	--LeftFeet = 15,
	--RightFeet = 18,
	LeftLeg = 14,
	RightLeg = 17,
}]]

local lastFire = 0
local nextAttack = 0
local old_weapon = nil

local HEADSHOT_WEAPONS_INDEXES = {
	--[230] = true, --- SYDNEY SLEEPER i dont think a sydney sleeper is necessary here
	[61] = true, --- AMBASSADOR
	[1006] = true, --- FESTIVE AMBASSADOR
}

GB_AIMBOT_GETSETTINGS = function()
	return settings
end

--- stuff used by melee aimbot
local ENGINEER_CLASS = 9
local MAX_UPGRADE_LEVEL = 3
local BUILDINGS = {
	CObjectSentrygun = true,
	CObjectDispenser = true,
	CObjectTeleporter = true,
}

--- stuff used by hitscan aimbot
local AcceptableEntities = {
	CObjectSentrygun = true,
	CObjectDispenser = true,
	CObjectTeleporter = true,
	CTFPlayer = true,
}

--- Cache some important functions

local TraceLine = engine.TraceLine
local sqrt = math.sqrt
local atan = math.atan
local PI = math.pi
local RADPI = 180 / PI
local vecMultiply = vector.Multiply
local GetByIndex = entities.GetByIndex

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

		if swing_trace and swing_trace.entity and swing_trace.entity and swing_trace.fraction <= 0.98 then
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

	if not input.IsButtonDown(settings.key) then
		return
	end

	if engine.IsChatOpen() or engine.Con_IsVisible() or engine.IsGameUIVisible() then
		return
	end

	localplayer = entities:GetLocalPlayer()
	if not localplayer or not localplayer:IsAlive() then
		return
	end

	weapon = localplayer:GetPropEntity("m_hActiveWeapon")
	if not weapon then
		return
	end

	m_team = localplayer:GetTeamNumber()

	--- if it returns true, it means it was a melee weapon and it did the proper math for them
	if weapon:IsMeleeWeapon() then
		RunMelee(usercmd)
		return
	end

	local shoot_pos = GetShootPosition()
	if not shoot_pos then
		return
	end

	local punchangles = weapon:GetPropVector("m_vecPunchAngle") or Vector3()

	local should_aim_at_head = ShouldAimAtHead()

	--- trust me, i tried like 3 or 4 different math combinations
	--- and i decided to just give up and paste amalgam for the fov xd

	local best_angle, best_fov, target, looking_at_target = nil, settings.fov, nil, false

	for _, entity in pairs(Players) do
		if not entity or entity:IsDormant() or not entity:IsAlive() or entity:GetTeamNumber() == m_team then
			goto continue
		end

		if entity:InCond(E_TFCOND.TFCond_Ubercharged) then
			goto continue
		elseif entity:InCond(E_TFCOND.TFCond_Cloaked) and settings.ignore.cloaked then
			goto continue
		end

		--[[
   local mins, maxs = entity:GetMins(), entity:GetMaxs()
   local center = entity:GetAbsOrigin() + ((mins + maxs) * ]]

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
		if not bones then
			goto continue
		end

		local bone_position = GetBoneOrigin(bones[best_bone_for_weapon])
		if not bone_position then
			goto continue
		end

		local trace = TraceLine(shoot_pos, bone_position, MASK_SHOT_HULL)
		if not trace then
			goto continue
		end

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

		if trace and trace.entity == entity and trace.fraction < 0.99 then
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
					if not bone_position then
						goto skip_bone
					end

					trace = TraceLine(shoot_pos, bone_position, MASK_SHOT_HULL)
					if not trace then
						goto skip_bone
					end

					if trace.entity == entity and trace.fraction < 0.99 then
						if
							not looking_at_target
							and looking_at_trace
							and looking_at_trace.entity
							and looking_at_trace.entity == entity
						then
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

	for _, entity in pairs(Dispensers) do
		local mins, maxs = entity:GetMins(), entity:GetMaxs()
		local center = entity:GetAbsOrigin() + ((mins + maxs) * 0.5)

		local trace = TraceLine(shoot_pos, center, MASK_SHOT_HULL)
		if trace and trace.entity == entity and trace.fraction < 0.99 then
			local angle = ToAngle(center - shoot_pos) - (usercmd.viewangles - punchangles)
			local fov = sqrt((angle.x ^ 2) + (angle.y ^ 2))

			if fov < best_fov then
				best_fov = fov
				best_angle = angle
				target = entity:GetIndex() --- not saving the whole entity here, too much memory used!
			end
		end
	end

	for _, entity in pairs(Teleporters) do
		local mins, maxs = entity:GetMins(), entity:GetMaxs()
		local center = entity:GetAbsOrigin() + ((mins + maxs) * 0.5)

		local trace = TraceLine(shoot_pos, center, MASK_SHOT_HULL)
		if trace and trace.entity == entity and trace.fraction < 0.99 then
			local angle = ToAngle(center - shoot_pos) - (usercmd.viewangles - punchangles)
			local fov = sqrt((angle.x ^ 2) + (angle.y ^ 2))

			if fov < best_fov then
				best_fov = fov
				best_angle = angle
				target = entity:GetIndex() --- not saving the whole entity here, too much memory used!
			end
		end
	end

	for _, entity in pairs(Sentries) do
		local mins, maxs = entity:GetMins(), entity:GetMaxs()
		local center = entity:GetAbsOrigin() + ((mins + maxs) * 0.5)

		local trace = TraceLine(shoot_pos, center, MASK_SHOT_HULL)
		if trace and trace.entity == entity and trace.fraction < 0.99 then
			local angle = ToAngle(center - shoot_pos) - (usercmd.viewangles - punchangles)
			local fov = sqrt((angle.x ^ 2) + (angle.y ^ 2))

			if fov < best_fov then
				best_fov = fov
				best_angle = angle
				target = entity:GetIndex() --- not saving the whole entity here, too much memory used!
			end
		end
	end

	local can_shoot = CanWeaponShoot() -- if autoshoot is off and player is trying to shoot, we aim for them

	if best_angle then
		if can_shoot then
			usercmd.viewangles = usercmd.viewangles
				+ (
					settings.mode == aimbot_mode.smooth
						and vecMultiply(best_angle, (settings.smooth_value * 0.01 --[[/100]]))
					or best_angle
				)
		end

		if settings.mode == aimbot_mode.plain and can_shoot then
			engine.SetViewAngles(EulerAngles(best_angle:Unpack()))
		elseif settings.mode == aimbot_mode.smooth then
			local smoothed = engine:GetViewAngles() + vecMultiply(best_angle, (settings.smooth_value * 0.01 --[[/100]]))
			engine.SetViewAngles(EulerAngles(smoothed:Unpack()))
			usercmd.viewangles = smoothed
		end

		if can_shoot then
			if settings.mode ~= aimbot_mode.smooth then
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
end

---@param stage E_ClientFrameStage
local function FrameStageNotify(stage)
	if stage == E_ClientFrameStage.FRAME_NET_UPDATE_END and localplayer and weapon then
		m_bReadyToBackstab = weapon:GetPropBool("m_bReadyToBackstab") or false
	end
end

local function Draw()
	--radius = std::tan( math::to_rad( fov * 0.5f ) * 2.f ) / g_draw.get_screen_fov( ) * ( g_draw.width( ) * 0.5f );
	--local radius = math.tan(math.rad(settings.fov))
	--/ math.tan(
	--math.rad(GB_GLOBALS.m_flCustomFOV)--[[(GB_GLOBALS.m_nAspectRatio == 0 and GB_GLOBALS.m_nPreAspectRatio or GB_GLOBALS.m_nAspectRatio)]]
	--* (width * 0.5)
	--)

	--[[
	local radius = (math.tan(math.rad(settings.fov / 2)) / math.tan(math.rad(GB_GLOBALS.m_flCustomFOV / 2)))
		* (width * 0.5)]]

	--[[
	local radius = (
		math.tan(math.rad(settings.fov / RADPI)) / math.tan((math.rad(GB_GLOBALS.m_flCustomFOV) / 2) / RADPI)
	) * (width * 0.5)
	--* (GB_GLOBALS.m_nAspectRatio == 0 and GB_GLOBALS.m_nPreAspectRatio or GB_GLOBALS.m_nAspectRatio)]]

	if localplayer and localplayer:IsAlive() then
		local aspect_ratio = (
			GB_GLOBALS.m_nAspectRatio == 0 and GB_GLOBALS.m_nPreAspectRatio or GB_GLOBALS.m_nAspectRatio
		)
		local fov = localplayer:InCond(E_TFCOND.TFCond_Zoomed) and 20 or GB_GLOBALS.m_flCustomFOV
		-- i just gave up and pasted amalgam's draw fov
		local radius = math.tan(math.rad(settings.fov)) / math.tan(math.rad(fov) / 2) * width * (4 / 6) / aspect_ratio

		--[[
  1.33 -- radius
  1.78 -- y
  1.33y = radius*1.78
  y = (radius*aspect_ratio)/1.33
  --]]

		draw.Color(255, 255, 255, 255)
		draw.OutlinedCircle(
			math.floor(width * 0.5),
			math.floor(height * 0.5),
			math.floor((radius * aspect_ratio) / 1.33),
			64
		)
	end
end

local aimbot = {}
aimbot.CreateMove = CreateMove
aimbot.FrameStageNotify = FrameStageNotify
aimbot.Draw = Draw

return aimbot

end)
__bundle_register("src.hitboxes", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
Hitboxes i'll use:
Head, center, left leg, right leg, left arm, right arm
im fucked
--]]

local CLASS_HITBOXES = {
	--[[scout]]
	[1] = {
		--[[Head =]]
		6,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[soldier]]
	[3] = {
		--[[HeadUpper =]]
		6, -- 32,
		--[[Head =]]
		32, -- 6,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[[pyro]]
	[7] = {
		--[[Head =]]
		6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		16,
		--[[RightLeg =]]
		20,
		--[[LeftArm =]]
		9,
		--[[RightArm =]]
		13,
	},

	--[[demoman]]
	[4] = {
		--[[Head =]]
		16,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		10,
		--[[RightLeg =]]
		12,
		--[[LeftArm =]]
		13,
		--[[RightArm =]]
		14,
	},

	--[[heavy]]
	[6] = {
		--[[Head =]]
		6,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[engi]]
	[9] = {
		--[[HeadUpper =]]
		8, --61,
		--[[Head =]]
		61, --8,
		--[[Body =]]
		4,
		--[[LeftLeg =]]
		10,
		--[[RightLeg =]]
		2,
		--[[LeftArm =]]
		13,
		--[[RightArm =]]
		16,
	},

	--[[medic]]
	[5] = {
		--[[HeadUpper =]]
		6, --33,
		--[[Head =]]
		33, --6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[sniper]]
	[2] = {
		--[[HeadUpper =]]
		6, --23,
		--[[Head =]]
		23, --6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[spy]]
	[8] = {
		--[[Head =]]
		6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		18,
		--[[RightLeg =]]
		19,
		--[[LeftArm =]]
		12,
		--[[RightArm =]]
		13,
	},
}

return CLASS_HITBOXES

end)
__bundle_register("src.anticheat", function(require, _LOADED, __bundle_register, __bundle_modules)
local clc_RespondCvarValue = 13
local SIGNONSTATE_TYPE = 6

---@param msg NetMessage
local function AntiCheat(msg)
	if msg:GetType() == SIGNONSTATE_TYPE and clientstate:GetClientSignonState() == E_SignonState.SIGNONSTATE_SPAWN then
		GB_GLOBALS.m_bIsStacRunning = false
	end

	if msg:GetType() == clc_RespondCvarValue and not GB_GLOBALS.m_bIsStacRunning then
		GB_GLOBALS.m_bIsStacRunning = true
		printc(255, 200, 200, 255, "STAC/SMAC was detected! Disabling some features...")
	end

	return true
end

callbacks.Register("SendNetMsg", "NETMSG garlic bread stac detector", AntiCheat)

end)
__bundle_register("src.bitbuf", function(require, _LOADED, __bundle_register, __bundle_modules)
local NEW_COMMANDS_SIZE = 4
local BACKUP_COMMANDS_SIZE = 3
local MSG_SIZE = 6
local WORD_SIZE = 16

--local net_SetConVar = 5
local clc_Move = 9

NET_SetConVar = {}
CLC_Move = {}

---@class ConVar
---@field name string # size 260
---@field value string # size 260

---@param buffer BitBuffer
---@param convars ConVar[]
function NET_SetConVar:WriteToBitBuffer(buffer, convars)
	buffer:Reset()
	--buffer:WriteInt(net_SetConVar, MSG_SIZE) we currently dont need this

	local numvars = #convars
	buffer:WriteByte(numvars)

	for i = 1, numvars do
		local var = convars[i]
		buffer:WriteString(var.name)
		buffer:WriteString(var.value)
	end

	buffer:SetCurBit(MSG_SIZE)
end

---@param buffer BitBuffer
function NET_SetConVar:ReadFromBitBuffer(buffer)
	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE) --- skip first 6 useless bits of msg:GetType()
	local numvars = buffer:ReadByte()

	---@type ConVar[]
	local convars = {}

	for i = 1, numvars do
		convars[i] = { name = buffer:ReadString(260), value = buffer:ReadString(260) }
	end

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)
	return convars
end

---@param buffer BitBuffer
---@param new_commands integer
---@param backup_commands integer
function CLC_Move:WriteToBitBuffer(buffer, new_commands, backup_commands)
	buffer:Reset()

	-- im not sure if we need to add the message type, but just in case its there
	buffer:WriteInt(clc_Move, MSG_SIZE)
	local length = buffer:GetDataBitsLength()

	buffer:WriteInt(new_commands, NEW_COMMANDS_SIZE) --- m_nNewCommands
	buffer:WriteInt(backup_commands, BACKUP_COMMANDS_SIZE) --- m_nBackupCommands
	buffer:WriteInt(length, WORD_SIZE) --- m_nLength

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE) --- skip msg type
end

---@param buffer BitBuffer
function CLC_Move:ReadFromBitBuffer(buffer)
	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)

	local new_commands, backup_commands, length
	new_commands = buffer:ReadInt(NEW_COMMANDS_SIZE)
	backup_commands = buffer:ReadInt(BACKUP_COMMANDS_SIZE)
	length = buffer:ReadInt(WORD_SIZE)

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)
	return { new_commands = new_commands, backup_commands = backup_commands, length = length }
end

end)
__bundle_register("src.globals", function(require, _LOADED, __bundle_register, __bundle_modules)
GB_GLOBALS = {
	usercmd_buttons = nil,
	m_hLocalPlayer = nil,
	m_hActiveWeapon = nil,
	m_Team = nil,

	m_vecShootPos = nil,
	m_angViewAngles = nil,

	m_bIsStacRunning = false,

	m_bIsAimbotShooting = false,
	m_nAimbotTarget = nil,

	m_bWarping = false,
	m_bRecharging = false,

	m_flFakeYaw = 0,
	m_flRealYaw = 90,
	m_flRealPitch = 0,
	m_flFakePitch = 0,
	m_bAntiAimEnabled = false,

	bIsAntiAimTick = function(tick)
		return tick % 2 == 0
	end,

	m_flCustomFOV = 90,
	m_nPreAspectRatio = 0,
	m_nAspectRatio = 1.78,

	m_bNoRecoil = true,

	toggle_fake_yaw = function()
		GB_GLOBALS.anti_aim.fake_yaw = not GB_GLOBALS.anti_aim.fake_yaw
		print(GB_GLOBALS.anti_aim.fake_yaw)
	end,

	toggle_real_yaw = function()
		GB_GLOBALS.anti_aim.real_yaw = not GB_GLOBALS.anti_aim.real_yaw
		print(GB_GLOBALS.anti_aim.real_yaw)
	end,

	toggle_real_pitch = function()
		GB_GLOBALS.anti_aim.real_pitch = not GB_GLOBALS.anti_aim.real_pitch
		print(GB_GLOBALS.anti_aim.real_pitch)
	end,

	toggle_fake_pitch = function()
		GB_GLOBALS.anti_aim.fake_pitch = not GB_GLOBALS.anti_aim.fake_pitch
		print(GB_GLOBALS.anti_aim.fake_pitch)
	end,

	anti_aim = {
		fake_yaw = false,
		real_yaw = true,
		fake_pitch = false,
		real_pitch = true,
	},

	m_bBhopEnabled = false,
}

---@param usercmd UserCmd
local function UpdateGlobals(usercmd)
	GB_GLOBALS.m_angViewAngles = engine:GetViewAngles()
	GB_GLOBALS.m_hLocalPlayer = entities:GetLocalPlayer()
	if GB_GLOBALS.m_hLocalPlayer then
		GB_GLOBALS.m_hActiveWeapon = GB_GLOBALS.m_hLocalPlayer:GetPropEntity("m_hActiveWeapon")
		GB_GLOBALS.m_vecShootPos = GB_GLOBALS.m_hLocalPlayer:GetAbsOrigin()
			+ GB_GLOBALS.m_hLocalPlayer:GetPropVector("m_vecViewOffset[0]")

		GB_GLOBALS.m_Team = GB_GLOBALS.m_hLocalPlayer:GetTeamNumber()
		GB_GLOBALS.usercmd_buttons = usercmd.buttons
	end

	--- m_bIsStacRunning is updated in anticheat.lua
	--- m_nAimbotTarget, m_bIsAimbotShooting is updated in aimbot.lua
	--- m_bWarping, m_bRecharging is updated in tickshift.lua
end

callbacks.Unregister("CreateMove", "GLOBAL CM garlic bread variables")
callbacks.Register("CreateMove", "GLOBAL CM garlic bread variables", UpdateGlobals)

end)
return __bundle_require("__root")