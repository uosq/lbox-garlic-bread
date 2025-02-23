local NEW_COMMANDS_SIZE = 4
local BACKUP_COMMANDS_SIZE = 3

local SIGNONSTATE_TYPE = 6
local CLC_MOVE_TYPE = 9

local charged_ticks = 0
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
	local player = entities:GetLocalPlayer()
	if player and m_localplayer_speed <= 0 and not m_settings.warp.standing_still then
		return
	end

	if
		GB_GLOBALS.m_bIsAimbotShooting
		and GB_GLOBALS.usercmd_buttons
		and GB_GLOBALS.usercmd_buttons & IN_ATTACK ~= 0
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

		--moveMsg:init()
		--msg:ReadFromBitBuffer(moveMsg.buffer)
		charged_ticks = charged_ticks - 1
	end
end

local function HandlePassiveRecharge()
	if not m_settings.warp.passive.enabled or charged_ticks >= max_ticks then
		return false
	end

	local player = entities:GetLocalPlayer()
	if (not player) then return false end

	if
		(globals.TickCount() >= next_passive_tick)
		or (m_settings.warp.passive.while_dead and not player:IsAlive())
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

	if CanChoke() and charged_ticks < max_ticks and recharging then
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
	GB_GLOBALS.m_bWarping = false
	GB_GLOBALS.m_bRecharging = false

	--- return early if user disabled with console commands
	if (not m_enabled) then return true end

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
		if warping and not recharging then
			GB_GLOBALS.m_bWarping = true
			HandleWarp(msg)
		elseif HandleRecharge() then
			GB_GLOBALS.m_bRecharging = true
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
	if engine.IsChatOpen() or engine.IsGameUIVisible() or engine.Con_IsVisible()
		or GB_GLOBALS.m_bIsStacRunning or (not m_enabled) then
		return
	end

	local player = entities:GetLocalPlayer()
	if (not player) then return end

	m_localplayer_speed = player:EstimateAbsVelocity():Length() or 0
	m_bIsRED = player:GetTeamNumber() == 2
	max_ticks = GetMaxServerTicks()
	charged_ticks = clamp(charged_ticks, 0, max_ticks)

	shooting = ((usercmd.buttons & IN_ATTACK) ~= 0 or GB_GLOBALS.m_bIsAimbotShooting) and GB_GLOBALS.CanWeaponShoot()
	warping = input.IsButtonDown(m_settings.warp.send_key)
	GB_GLOBALS.m_bWarping = warping
	recharging = input.IsButtonDown(m_settings.warp.recharge_key)

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
		or (not m_enabled)
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

local function cmd_ToggleTickShift()
	m_enabled = not m_enabled
	print(150, 255, 150, 255, "Tick shifting is now " .. (m_enabled and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("tickshift->toggle", "Toggles tickshifting (warp, recharge)", 0, cmd_ToggleTickShift)
return tickshift
