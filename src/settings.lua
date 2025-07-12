---@type GB_Settings
local settings = {
	version = 0.9,

	aimbot = {
		key = E_ButtonCode.KEY_LSHIFT,
		enabled = true,
		autoshoot = true,
		fov = 30,
		m_flPredictionTime = 2.0,
	},

	antiaim = {
		m_flFakeyaw = 90,
		m_flRealyaw = -90,
		m_flPitch = 89,
		m_bEnabled = false,
	},

	fakelag = {
		m_iGoal = 22,
		m_bEnabled = false,
	},

	warp = {
		m_bEnabled = true,
		m_iWarpKey = E_ButtonCode.MOUSE_5,
		m_iRechargeKey = E_ButtonCode.MOUSE_4,
		m_bPassiveRecharge = false,
		m_iTogglePassiveRechargeKey = E_ButtonCode.KEY_R,
	},
}

return settings
