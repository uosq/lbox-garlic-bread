local aimbot_mode = { plain = "plain", smooth = "smooth", silent = "silent", assistance = "assistance" }

GB_GLOBALS = {
	aimbot = {
		enabled = true,
		fov = 10,
		key = E_ButtonCode.KEY_LSHIFT,
		autoshoot = true,
		mode = aimbot_mode.silent,
		lock_aim = false,
		smooth_value = 10, --- lower value, smoother aimbot (10 = very smooth, 100 = basically plain aimbot)
		auto_spinup = true,
		aimfov = false,
		epicstacbypass = true,

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
			spectators = true,
		},

		aim = {
			players = true,
			npcs = true,
			sentries = true,
			other_buildings = true,
		},
	},

	antiaim = {
		enabled = false,
		fake_yaw = 0,
		real_yaw = 0
	},

	hud = {
		enabled = true,
		crosshair_size = 8,
		crosshair_color = {255, 255, 255, 255},
	},

	bIsStacRunning = false,

	bIsAimbotShooting = false,
	nAimbotTarget = nil,

	bWarping = false,
	bRecharging = false,

	flCustomFOV = 90,
	nPreAspectRatio = 0,
	nAspectRatio = 1.78,

	bNoRecoil = true,
	bBhopEnabled = false,
	bSpectated = false,
	bThirdperson = false,
	bFakeLagEnabled = false,
}