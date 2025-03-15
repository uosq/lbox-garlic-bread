local aimbot_mode = { plain = "plain", smooth = "smooth", silent = "silent", assistance = "assistance" }

GB_SETTINGS = {
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

	chams = {
		enabled = true,
		update_interval = 5, --- ticks
		enemy_only = false,
		visible_only = true,
		original_player_mat = false,
		original_viewmodel_mat = false,
		ignore_disguised_spy = true,

		filter = {
			HEALTHPACK = true,
			AMMOPACK = true,
			VIEWMODEL_ARM = true,
			VIEWMODEL_WEAPON = true,
			PLAYERS = true,
			SENTRIES = true,
			DISPENSERS = true,
			TELEPORTERS = true,
			MONEY = true,
			LOCALPLAYER = true,
			ANTIAIM = true,
			BACKTRACK = true,
			RAGDOLLS = true,
		},
	},

	fakelag = {
		enabled = false,
		indicator = {
			enabled = true,
			firstperson = false,
		},
		ticks = 21,
	},

	visuals = {
		custom_fov = 120,
		thirdperson = {
			enabled = true,
			offset = {up = 0, right = 0, forward = 0},
		}
	},

	misc = {
		bhop = true,
	},

	tickshift = {
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
	},

	spectatorlist = {
		enabled = true,
		starty = 0.3, -- (percentage from center screen height)
	},
}