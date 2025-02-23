---@diagnostic disable:cast-local-type
local antiaim = {}

local m_bPitchEnabled = false
local m_realyaw, m_fakeyaw, m_realpitch, m_fakepitch = 0, 0, 0, 0

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

local function cmd_toggle_aa()
	GB_GLOBALS.m_bAntiAimEnabled = not GB_GLOBALS.m_bAntiAimEnabled
	printc(150, 255, 150, 255, "Anti aim is now " .. (GB_GLOBALS.m_bAntiAimEnabled and "enabled" or "disabled"))
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

GB_GLOBALS.RegisterCommand("antiaim->change", "Changes antiaim's settings | args: fake or real (string), yaw or pitch (string), new_value (number)", 3, cmd_set_options)
GB_GLOBALS.RegisterCommand("antiaim->toggle", "Toggles antiaim", 0, cmd_toggle_aa)
GB_GLOBALS.RegisterCommand("antiaim->toggle_pitch", "Toggles real and fake pitch from being added to viewangles", 0, cmd_toggle_pitch)
return antiaim
