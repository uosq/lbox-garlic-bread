local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "aimbot: gb is nil!")
assert(gb_settings, "aimbot: GB_SETTINGS is nil!")

local helpers = require("src.aimbot.helpers")
local hitscan = require("src.aimbot.hitscan")
local melee = require("src.aimbot.melee")
---local projectile = require("src.aimbot.projectile") WARNING: todo :)

local aimbot = {}

function aimbot.CreateMove(usercmd)
	local player = entities:GetLocalPlayer()
	if not player or not player:IsAlive() then return end

	local weapon = player:GetPropEntity("m_hActiveWeapon")
	local weapontype = weapon:GetWeaponProjectileType()

	if weapontype == E_ProjectileType.TF_PROJECTILE_BULLET then
		hitscan:CreateMove(usercmd, player)
	elseif weapon:IsMeleeWeapon() then
		melee:CreateMove(usercmd, weapon, player:GetTeamNumber())
	elseif weapontype ~= E_ProjectileType.TF_PROJECTILE_BULLET then
		---projectile:CreateMove(...)
	end
end

function aimbot.Draw()
	if not gb_settings.aimbot.aimfov or not gb_settings.aimbot.enabled then
		return
	end

	local localplayer = entities:GetLocalPlayer()
	if not localplayer then return end

	local width, height = draw.GetScreenSize()

	if localplayer and localplayer:IsAlive() and gb_settings.aimbot.fov <= 89 then
		local viewfov = gb_settings.visuals.custom_fov
		local aspectratio = (gb_settings.visuals.aspect_ratio == 0 and gb.nPreAspectRatio or gb_settings.visuals.aspect_ratio)
		viewfov = helpers:calc_fov(viewfov, aspectratio)
		local aimfov = gb_settings.aimbot.fov * (math.tan(math.rad(viewfov / 2)) / math.tan(math.rad(45)))

		if not aimfov or not viewfov then
			return
		end

		local radius = (math.tan(math.rad(aimfov) / 2)) / (math.tan(math.rad(viewfov) / 2)) * width
		draw.Color(255, 255, 255, 255)
		draw.OutlinedCircle(math.floor(width / 2), math.floor(height / 2), math.floor(radius), 64)
	end
end

local function cmd_ChangeAimbotMode(args)
	if not args or #args == 0 then
		return
	end
	local mode = tostring(args[1])
	gb_settings.aimbot.mode = gb.aimbot_modes[mode]
end

local function cmd_ChangeAimbotKey(args)
	if not args or #args == 0 then
		return
	end

	local key = string.upper(tostring(args[1]))

	local selected_key = E_ButtonCode["KEY_" .. key]
	if not selected_key then
		print("Invalid key!")
		return
	end

	gb_settings.aimbot.key = selected_key
end

local function cmd_ChangeAimbotFov(args)
	if not args or #args == 0 or not args[1] then
		return
	end
	gb_settings.aimbot.fov = tonumber(args[1])
end

local function cmd_ChangeAimbotIgnore(args)
	if not args or #args == 0 then
		return
	end
	if not args[1] or not args[2] then
		return
	end

	local option = tostring(args[1])
	local ignoring = gb_settings.aimbot.ignore[option] and "aiming for" or "ignoring"

	gb_settings.aimbot.ignore[option] = not gb_settings.aimbot.ignore[option]

	printc(150, 255, 150, 255, "Aimbot is now " .. ignoring .. " " .. option)
end

local function cmd_ToggleAimLock()
	gb_settings.aimbot.lock_aim = not gb_settings.aimbot.lock_aim
	printc(150, 255, 150, 255, "Aim lock is now " .. (gb_settings.aimbot.lock_aim and "enabled" or "disabled"))
end

local function cmd_ToggleAimFov()
	gb_settings.aimbot.aimfov = not gb_settings.aimbot.aimfov
end

local function cmd_ChangeAimSmoothness(args, num_args)
	if not args or #args ~= num_args then
		return
	end
	local new_value = tonumber(args[1])
	if not new_value then
		printc(255, 150, 150, 255, "Invalid value!")
		return
	end
	gb_settings.aimbot.smooth_value = new_value
end

gb.RegisterCommand(
	"aimbot->change->mode",
	"Change aimbot mode | args: mode (plain, smooth or silent)",
	1,
	cmd_ChangeAimbotMode
)
gb.RegisterCommand("aimbot->change->key", "Changes aimbot key | args: key (w, f, g, ...)", 1, cmd_ChangeAimbotKey)
gb.RegisterCommand("aimbot->change->fov", "Changes aimbot fov | args: fov (number)", 1, cmd_ChangeAimbotFov)
gb.RegisterCommand(
	"aimbot->ignore->toggle",
	"Toggles a aimbot ignore option (like ignore cloaked) | args: option name (string)",
	1,
	cmd_ChangeAimbotIgnore
)
gb.RegisterCommand(
	"aimbot->toggle->aimlock",
	"Makes the aimbot not stop looking at the targe when shooting",
	0,
	cmd_ToggleAimLock
)
gb.RegisterCommand("aimbot->toggle->fovindicator", "Toggles aim fov circle", 0, cmd_ToggleAimFov)
gb.RegisterCommand(
	"aimbot->change->smoothness",
	"Changes the smoothness value | args: new value (number, 0 to 1)",
	1,
	cmd_ChangeAimSmoothness
)

local function unload()
	aimbot = nil
	helpers = nil
	hitscan = nil
	melee = nil
end

aimbot.unload = unload
return aimbot
