---@module "def"

local aim = {}

local hitscan = require("src.features.aimbot.hitscan")
local proj = require("src.features.aimbot.projectile")

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

	if not input.IsButtonDown(settings.aimbot.key) then
		return false, nil
	end

	local players = entities.FindByClass("CTFPlayer")
	proj.RunBackground(plocal, pweapon, players, settings, ent_utils, utils)

	if engine.IsChatOpen() or engine.IsGameUIVisible() then
		return false, nil
	end

	if pweapon:GetWeaponProjectileType() == E_ProjectileType.TF_PROJECTILE_BULLET then
		return hitscan.Run(settings, utils, wep_utils, ent_utils, plocal, cmd, players)
	elseif not pweapon:IsMeleeWeapon() then
		return proj.Run(utils, wep_utils, ent_utils, plocal, pweapon, cmd)
	end

	return false, nil
end

function aim.Draw()
	proj.Draw()
end

return aim
