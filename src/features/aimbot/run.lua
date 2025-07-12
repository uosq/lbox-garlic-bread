---@module "def"

local aim = {}

local hitscan = require("src.features.aimbot.hitscan")
local proj = require("src.features.aimbot.projectile")

local font = draw.CreateFont("TF2 BUILD", 16, 600)

local time = {
	runbackground = 0,
	ballistic_arc = 0,
	playerSimBackground = 0,
	closest_player_fov = 0,
	proj_iterations = 0,
}

---@param settings GB_Settings
---@param utils GB_Utils
---@param cmd UserCmd
---@param plocal Entity
---@param wep_utils GB_WepUtils
---@return boolean, integer?
function aim.CreateMove(settings, utils, wep_utils, ent_utils, plocal, cmd)
	if not settings.aimbot.enabled then
		return false, nil
	end

	local pweapon = plocal:GetPropEntity("m_hActiveWeapon")
	if not pweapon then
		return false, nil
	end

	local start = os.clock()

	local players = entities.FindByClass("CTFPlayer")
	proj.RunBackground(plocal, pweapon, players, settings, ent_utils, utils, time)

	local finish = os.clock()

	time.runbackground = finish - start

	if not input.IsButtonDown(settings.aimbot.key) then
		return false, nil
	end

	if engine.IsChatOpen() or engine.IsGameUIVisible() then
		return false, nil
	end

	if pweapon:GetWeaponProjectileType() == E_ProjectileType.TF_PROJECTILE_BULLET then
		return hitscan.Run(settings, utils, wep_utils, ent_utils, plocal, cmd, players)
	elseif not pweapon:IsMeleeWeapon() then
		return proj.Run(utils, wep_utils, plocal, pweapon, cmd)
	end

	return false, nil
end

function aim.Draw()
	proj.Draw()

	draw.SetFont(font)
	draw.Color(255, 255, 255, 255)
	draw.Text(10, 10, string.format("proj Background: %s seconds", time.runbackground))
	draw.Text(10, 30, string.format("ballistic arc: %s seconds", time.ballistic_arc))
	draw.Text(10, 50, string.format("player sim background: %s seconds", time.playerSimBackground))
	draw.Text(10, 70, string.format("cloest player fov: %s seconds", time.closest_player_fov))
	draw.Text(10, 90, string.format("projectile iterations: %s seconds", time.proj_iterations))
end

return aim
