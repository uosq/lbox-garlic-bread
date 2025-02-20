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

		GB_GLOBALS.m_Team = GB_GLOBALS.m_hLocalPlayer:GetTeamNumber()
		GB_GLOBALS.usercmd_buttons = usercmd.buttons
	end

	--- m_bIsStacRunning is updated in anticheat.lua
	--- m_nAimbotTarget, m_bIsAimbotShooting is updated in aimbot.lua
	--- m_bWarping, m_bRecharging is updated in tickshift.lua
end

callbacks.Unregister("CreateMove", "GLOBAL CM garlic bread variables")
callbacks.Register("CreateMove", "GLOBAL CM garlic bread variables", UpdateGlobals)
