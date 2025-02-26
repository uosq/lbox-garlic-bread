---@diagnostic disable:cast-local-type
local antiaim = {}

local m_bEnabled = false
local m_bPitchEnabled = false
local m_realyaw, m_fakeyaw, m_realpitch, m_fakepitch = 0, 0, 0, 0

---@param usercmd UserCmd
function antiaim.CreateMove(usercmd)
	if
		not GB_GLOBALS.bIsAimbotShooting
		and m_bEnabled
		and usercmd.buttons & IN_ATTACK == 0
		and not GB_GLOBALS.bIsStacRunning
		and not GB_GLOBALS.bWarping
		and not GB_GLOBALS.bRecharging
	then
		--- make sure we aren't overchoking
		if clientstate:GetChokedCommands() >= 21 then
			usercmd.sendpacket = true
			return
		end

		local view = engine:GetViewAngles()

		local realyaw = view.y + (m_realyaw or 0)
		local fakeyaw = view.y + (m_fakeyaw or 0)
		local realpitch = m_bPitchEnabled and m_realpitch or view.x
		local fakepitch = m_bPitchEnabled and m_fakepitch or view.x

		local is_real_yaw_tick = usercmd.tick_count % 2 == 0

		local pitch, yaw
		pitch = is_real_yaw_tick and realpitch or fakepitch
		yaw = is_real_yaw_tick and realyaw or fakeyaw

		usercmd:SetViewAngles(pitch, yaw, 0)
		usercmd.sendpacket = not is_real_yaw_tick
	end
end

function antiaim.unload()
	antiaim = nil
end

function antiaim.Draw()
	if (not m_bEnabled) then return end

	local player = entities:GetLocalPlayer()
	if (not player or not player:IsAlive()) then return end

	local origin = player:GetAbsOrigin()
	if (not origin) then return end

	local origin_screen = client.WorldToScreen(origin)
	if (not origin_screen) then return end

	local startpos = origin
	local endpos = nil

	local viewangle = engine:GetViewAngles().y

	local real_yaw, fake_yaw = m_realyaw + viewangle, m_fakeyaw + viewangle
	local real_direction, fake_direction
	real_direction = Vector3(math.cos(math.rad(real_yaw)), math.sin(math.rad(real_yaw)))
	fake_direction = Vector3(math.cos(math.rad(fake_yaw)), math.sin(math.rad(fake_yaw)))

	endpos = origin + (fake_direction * 10)

	local startpos_screen = client.WorldToScreen(startpos)
	if (not startpos_screen) then return end
	local endpos_screen = client.WorldToScreen(endpos)
	if (not endpos_screen) then return end

	--- fake yaw
	draw.Color(255, 150, 150, 255)
	draw.Line(startpos_screen[1], startpos_screen[2], endpos_screen[1], endpos_screen[2])

	--- real yaw
	draw.Color(150, 255, 150, 255)
	endpos = origin + (real_direction * 10)
	endpos_screen = client.WorldToScreen(endpos)
	if (not endpos_screen) then return end

	draw.Line(startpos_screen[1], startpos_screen[2], endpos_screen[1], endpos_screen[2])
end

local function cmd_toggle_aa()
	if (GB_GLOBALS.bIsStacRunning) then
		printc(255, 0, 0, 255, "STAC is active! Won't change AA")
		return
	end
	m_bEnabled = not m_bEnabled
	printc(150, 255, 150, 255, "Anti aim is now " .. (m_bEnabled and "enabled" or "disabled"))
end

local function cmd_set_options(args)
	if (not args or #args == 0) then return end
	if (not args[1] or not args[2] or not args[3]) then return end

	local fake = args[1] == "fake"
	local real = args[1] == "real"
	local wants_yaw = args[2] == "yaw"
	local wants_pitch = args[2] == "pitch"
	local new_value = tonumber(args[3])
	if (not new_value) then print("Invalid value!") return end

	--local key = "m_fl%s%s"
	--local formatted = string.format(key, fake and "Fake" or "Real", wants_yaw and "Yaw" or "Pitch")
	if (fake and wants_yaw) then
		m_fakeyaw = new_value
	elseif (fake and not wants_pitch) then
		m_fakepitch = new_value
	elseif (real and wants_yaw) then
		m_realyaw = new_value
	elseif (real and wants_pitch) then
		m_realpitch = new_value
	end
end

local function cmd_toggle_pitch()
	m_bPitchEnabled = not m_bPitchEnabled
	printc(150, 255, 150, 255, "Anti aim pitch is now " .. (m_bPitchEnabled and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("antiaim->change", "Changes antiaim's settings | args: fake or real (string), yaw or pitch (string), new value (number)", 3, cmd_set_options)
GB_GLOBALS.RegisterCommand("antiaim->toggle", "Toggles antiaim", 0, cmd_toggle_aa)
GB_GLOBALS.RegisterCommand("antiaim->toggle_pitch", "Toggles real and fake pitch from being added to viewangles", 0, cmd_toggle_pitch)
return antiaim
