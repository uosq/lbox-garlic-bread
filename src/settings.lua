local aimbot_mode = { plain = "plain", smooth = "smooth", silent = "silent", assistance = "assistance" }
local json = require("src.json")
filesystem.CreateDirectory("Garlic Bread/Configs")

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
		projectile = true,

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

	triggerbot = {
		enabled = true,
		key = E_ButtonCode.KEY_LSHIFT, --- no key means it will run in the background
		fov = 4.5,
		filter = {
			hitscan = false,
			autobackstab = true,
			autowrench = true,
			melee = true,
		}
	},

	esp = {
		hide_cloaked = true,
		enemy_only = true,
		visible_only = true,
	},

	antiaim = {
		enabled = false,
		fake_yaw = 0,
		real_yaw = 0
	},

	hud = {
		enabled = false,
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
		ignore_cloaked_spy = true,

		filter = {
			healthpack = true,
			ammopack = true,
			viewmodel_arm = true,
			viewmodel_weapon = true,
			players = true,
			sentries = true,
			dispensers = true,
			teleporters = true,
			money = true,
			localplayer = true,
			antiaim = true,
			backtrack = true,
			ragdolls = true,
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
			enabled = false,
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

		doubletap = {
			enabled = true,
			key = E_ButtonCode.KEY_F,
			ticks = 24,
		},
	},

	spectatorlist = {
		enabled = true,
		starty = 0.3, -- (percentage from center screen height)
	},
}

local function CMD_SaveSettings(args, num_args)
	if not args or #args ~= num_args then return end

	local filename = tostring(args[1])
	if not filename then return end

	local encoded = json.encode(GB_SETTINGS)
	io.output("Garlic Bread/Configs/"..filename)
	io:write(encoded)
	io.flush()
	io.close()
end

local function CMD_LoadSettings(args, num_args)
	if not args or #args ~= num_args then return end

	local filename = tostring(args[1])
	if not filename then return end

	local file = io.open("Garlic Bread/Configs/"..filename)
	if file then
		local content = file:read("a")
		local decoded = json.decode(content)
		GB_SETTINGS = decoded
		file:close()
	end
end

local function CMD_GetAllSettingsFiles()
	filesystem.EnumerateDirectory("Garlic Bread/Configs/*.json", function (filename, attributes)
		print(filename:gsub(".json", ""))
	end)
end

GB_GLOBALS.RegisterCommand("settings->save", "Saves your config | args: file name (string)", 1, CMD_SaveSettings)
GB_GLOBALS.RegisterCommand("settings->load", "Loads a config | args: file name (string)", 1, CMD_LoadSettings)
GB_GLOBALS.RegisterCommand("settings->getconfigs", "Prints all configs", 0, CMD_GetAllSettingsFiles)