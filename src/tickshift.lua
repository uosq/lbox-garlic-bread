local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "tickshift: GB_GLOBALS is nil!")
assert(gb_settings, "tickshift: GB_SETTINGS is nil!")

local settings = gb_settings.tickshift

local SIGNONSTATE_TYPE = 6
local CLC_MOVE_TYPE = 9

local charged_ticks = 0
local dt_ticks = 0

local max_ticks = 0
local last_key_tick = 0
local next_passive_tick = 0

local m_enabled = true
local shooting = false
local warping, recharging = false, false

local font = draw.CreateFont("TF2 BUILD", 16, 1000)

---@type number, boolean
local m_localplayer_speed, m_bIsRED
m_bIsRED = false

local colors = require("src.colors")

local tickshift = {}
local old_tickbase = nil

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
	local player = entities:GetLocalPlayer()
	if player and m_localplayer_speed <= 0 and not gb_settings.tickshift.warp.standing_still then
		return
	end

	if
		gb.bIsAimbotShooting
		and gb.usercmd_buttons
		and gb.usercmd_buttons & IN_ATTACK ~= 0
	then
		return
	end

	if player and player:IsAlive() and charged_ticks > 0 and CanShift() then
		--local moveMsg = clc_Move()

		--- the new BitBuffer lib
		local buffer = BitBuffer()
		buffer:Reset()
		CLC_Move:WriteToBitBuffer(buffer, 2, 1)
		msg:ReadFromBitBuffer(buffer)
		buffer:Delete()

		charged_ticks = charged_ticks - 1
	end
end

local function HandlePassiveRecharge()
	if not gb_settings.tickshift.warp.passive.enabled or charged_ticks >= max_ticks then
		return false
	end

	local player = entities:GetLocalPlayer()
	if (not player) then return false end

	if
		(globals.TickCount() >= next_passive_tick)
		or (gb_settings.tickshift.warp.passive.while_dead and not player:IsAlive())
	then
		charged_ticks = charged_ticks + 1
		local time = engine.RandomFloat(gb_settings.tickshift.warp.passive.min_time, gb_settings.tickshift.warp.passive.max_time)
		next_passive_tick = globals.TickCount() + (time * 66.67)
		return true
	end

	return false
end

local function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

local function HandleRecharge()
	if
		(shooting and not gb_settings.tickshift.warp.recharge.while_shooting)
		or (m_localplayer_speed <= 0 and not gb_settings.tickshift.warp.recharge.standing_still)
	then
		return false
	end

	if CanChoke() and charged_ticks < max_ticks and recharging then
		charged_ticks = charged_ticks + 1
		return true
	end

	if HandlePassiveRecharge() then
		return true
	end

	return false
end

local function FixTickBase()
	local player = entities:GetLocalPlayer()
	if player and old_tickbase then
		player:SetPropInt(old_tickbase - charged_ticks, "m_nTickBase")
		--- im not sure if this is good enough to fix tickbase
		--- but spy's revolver seems to be missing less
	end
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
---@param returnval {ret: boolean}
function tickshift.SendNetMsg(msg, returnval)
	gb.bWarping = false
	gb.bRecharging = false

	--- return early if user disabled with console commands
	if not m_enabled then return true end

	if msg:GetType() == SIGNONSTATE_TYPE then
		HandleJoinServers(msg)
	end

	if gb.bIsStacRunning or gb.bFakeLagEnabled then return true end

	if engine.IsChatOpen() or engine.IsGameUIVisible() or engine.Con_IsVisible() then
		return true
	end

	if msg:GetType() == CLC_MOVE_TYPE then
		if warping and not recharging then
			gb.bWarping = true
			HandleWarp(msg)
			FixTickBase()
		elseif HandleRecharge() then
			gb.bRecharging = true
			FixTickBase()
			returnval.ret = false
		end
	end
end

--- thanks Glitch!
---@param usercmd UserCmd
---@param player Entity
local function AntiWarp(player, usercmd)
	local vel = player:EstimateAbsVelocity()
	local flags = player:GetPropInt("m_fFlags")
	if (flags & FL_ONGROUND) == 0 or vel:Length2D() <= 15 or (usercmd.buttons & IN_JUMP) ~= 0 then return end

	local yaw = engine:GetViewAngles().y
	local dir = vel:Angles()
	dir.y = yaw - dir.y
	local forward = dir:Forward() * -vel:Length2D()
	usercmd.forwardmove, usercmd.sidemove = forward.x, forward.y
end

---@param usercmd UserCmd
function tickshift.CreateMove(usercmd)
	if engine.IsChatOpen() or engine.IsGameUIVisible() or engine.Con_IsVisible()
		or gb.bIsStacRunning or not m_enabled or gb.bFakeLagEnabled then
		return
	end

	local player = entities:GetLocalPlayer()
	if (not player) then return end

	m_localplayer_speed = player:EstimateAbsVelocity():Length() or 0
	m_bIsRED = player:GetTeamNumber() == 2
	max_ticks = GetMaxServerTicks()
	charged_ticks = clamp(charged_ticks, 0, max_ticks)

	shooting = ((usercmd.buttons & IN_ATTACK) ~= 0 or gb.bIsAimbotShooting) and gb.CanWeaponShoot()

	warping = input.IsButtonDown(gb_settings.tickshift.warp.send_key)
	gb.bWarping = warping
	recharging = input.IsButtonDown(gb_settings.tickshift.warp.recharge_key) and charged_ticks < max_ticks

	local state, tick = input.IsButtonPressed(gb_settings.tickshift.warp.passive.toggle_key)
	if state and last_key_tick < tick then
		gb_settings.tickshift.warp.passive.enabled = not gb_settings.tickshift.warp.passive.enabled
		last_key_tick = tick
		client.ChatPrintf("Passive recharge: " .. (gb_settings.tickshift.warp.passive.enabled and "ON" or "OFF"))
	end

	if gb_settings.tickshift.doubletap.enabled and input.IsButtonDown(gb_settings.tickshift.doubletap.key) and usercmd.buttons & IN_ATTACK ~= 0 then
		if dt_ticks < gb_settings.tickshift.doubletap.ticks then
			AntiWarp(player, usercmd)
		end

		if dt_ticks < gb_settings.tickshift.doubletap.ticks and charged_ticks > 0 then
			dt_ticks = dt_ticks + 1
			charged_ticks = charged_ticks - 1
			usercmd.sendpacket = false
			FixTickBase()
		end

		if clientstate:GetChokedCommands() >= gb_settings.tickshift.doubletap.ticks or dt_ticks >= max_ticks then
			usercmd.sendpacket = true
			dt_ticks = 0
			charged_ticks = 0
		end
	end
end

function tickshift.Draw()
	if
		engine:Con_IsVisible()
		or engine:IsGameUIVisible()
		or (engine:IsTakingScreenshot() and gui.GetValue("clean screenshots") == 1)
		or not m_enabled or gb.bIsStacRunning or gb.bFakeLagEnabled
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

	draw.Color(table.unpack(colors.WARP_BAR_BACKGROUND))
	draw.FilledRect(
		math.floor(barX - offset),
		math.floor(barY - offset),
		math.floor(barX + barWidth + offset),
		math.floor(barY + textH + offset)
	)

	local color = m_bIsRED and colors.WARP_BAR_RED or colors.WARP_BAR_BLU
	draw.Color(table.unpack(color))

	--- i honestly dont know why this errors sometimes
	--- so this was my solution
	--- (not ideal)
	pcall(
		draw.FilledRect,
		math.floor(barX or 0),
		math.floor(barY or 0),
		math.floor((barX or 0) + ((barWidth * (percent or 0)) or 0)),
		math.floor((barY or 0) + (textH or 0))
	)

	draw.SetFont(font)
	draw.Color(table.unpack(colors.WARP_BAR_TEXT))
	draw.TextShadow(textX, textY, formatted_text)
end

function tickshift.FrameStageNotify(stage)
	if stage == E_ClientFrameStage.FRAME_NET_UPDATE_START then
		local player = entities:GetLocalPlayer()
		if not player then return end
		old_tickbase =  player:GetPropInt("m_nTickBase")
	end
end

local function cmd_ToggleTickShift()
	m_enabled = not m_enabled
	printc(150, 255, 150, 255, "Tick shifting is now " .. (m_enabled and "enabled" or "disabled"))
end

local function unload()
	SIGNONSTATE_TYPE = nil
	CLC_MOVE_TYPE = nil
	charged_ticks = nil
	max_ticks = nil
	last_key_tick = nil
	next_passive_tick = nil
	m_enabled = nil
	shooting = nil
	warping, recharging = nil, nil
	font = nil
	m_localplayer_speed, m_bIsRED = nil, nil
	m_bIsRED = nil
	gb_settings.tickshift = nil
	tickshift = nil
end

tickshift.unload = unload

gb.RegisterCommand("tickshift->toggle", "Toggles tickshifting (warp, recharge)", 0, cmd_ToggleTickShift)
return tickshift
