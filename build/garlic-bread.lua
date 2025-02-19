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
require("src.anticheat")

local aimbot = require("src.aimbot")
local tickshift = require("src.tickshift")
local antiaim = require("src.antiaim")
local visuals = require("src.visuals")

require("src.background")
require("src.commands")

aimbot:SetDebug(false)

callbacks.Unregister("CreateMove", "CM garlic bread cheat aimbot")
callbacks.Register("CreateMove", "CM garlic bread cheat aimbot", aimbot.CreateMove)
callbacks.Unregister("FrameStageNotify", "FSN garlic bread cheat aimbot frame stage")
callbacks.Register("FrameStageNotify", "FSN garlic bread cheat aimbot frame stage", aimbot.FrameStage)

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
__bundle_register("src.visuals", function(require, _LOADED, __bundle_register, __bundle_modules)
local visuals = {}

---@param setup ViewSetup
local function CustomFOV(setup)
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

--callbacks.Register("RenderView", "RV galic bread custom fov", CustomFOV)

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
		local moveMsg <close> = clc_Move()
		moveMsg:init()
		msg:ReadFromBitBuffer(moveMsg.buffer)
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
---@diagnostic disable:cast-local-type
--- doesnt use GB_GLOBALS for performance reasons

---@type Entity?, boolean, Vector3?, EulerAngles?, EulerAngles?, Entity?, Vector3?, Vector3?, Entity?, number?
local m_localplayer, m_debug, m_target_pos, m_viewangles, m_target_angle, m_target, m_localplayer_pos, m_shootpos, m_weapon, m_closest_fov

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
	local model = entity:GetModel()
	local studioHdr = models.GetStudioModel(model)

	local myHitBoxSet = entity:GetPropInt("m_nHitboxSet")
	local hitboxSet = studioHdr:GetHitboxSet(myHitBoxSet)
	local hitboxes = hitboxSet:GetHitboxes()

	--boneMatrices is an array of 3x4 float matrices
	local boneMatrices = entity:SetupBones()
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
		local model = entity:GetModel()
		local studioHdr = models.GetStudioModel(model)

		local myHitBoxSet = entity:GetPropInt("m_nHitboxSet")
		local hitboxSet = studioHdr:GetHitboxSet(myHitBoxSet)
		local hitboxes = hitboxSet:GetHitboxes()
		local boneMatrices = entity:SetupBones()

		for _, hitbox in pairs(m_hitboxes) do
			--local pos = GetHitboxPos(entity, hitbox)
			local pos = GetHitboxPosCache(hitbox, hitboxes, boneMatrices)
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
__bundle_register("src.globals", function(require, _LOADED, __bundle_register, __bundle_modules)
GB_GLOBALS = {
	usercmd_buttons = nil,
	m_hLocalPlayer = nil,
	m_hActiveWeapon = nil,

	m_vecShootPos = nil,
	m_angViewAngles = nil,

	m_bIsStacRunning = false,

	m_bIsAimbotShooting = false,
	m_hAimbotTarget = nil,

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
}

---@param usercmd UserCmd
local function UpdateGlobals(usercmd)
	GB_GLOBALS.m_angViewAngles = engine:GetViewAngles()
	GB_GLOBALS.m_hLocalPlayer = entities:GetLocalPlayer()
	if GB_GLOBALS.m_hLocalPlayer then
		GB_GLOBALS.m_hActiveWeapon = GB_GLOBALS.m_hLocalPlayer:GetPropEntity("m_hActiveWeapon")
		GB_GLOBALS.m_vecShootPos = GB_GLOBALS.m_hLocalPlayer:GetAbsOrigin()
			+ GB_GLOBALS.m_hLocalPlayer:GetPropVector("m_vecViewOffset[0]")

		GB_GLOBALS.usercmd_buttons = usercmd.buttons
	end

	--- m_bIsStacRunning is updated in anticheat.lua
	--- m_hAimbotTarget, m_bIsAimbotShooting is updated in aimbot.lua
	--- m_bWarping, m_bRecharging is updated in tickshift.lua
end

callbacks.Unregister("CreateMove", "GLOBAL CM garlic bread variables")
callbacks.Register("CreateMove", "GLOBAL CM garlic bread variables", UpdateGlobals)

end)
return __bundle_require("__root")