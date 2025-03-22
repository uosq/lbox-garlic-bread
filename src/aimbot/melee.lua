local gb = GB_GLOBALS
assert(gb, "melee.lua: gb_globals is nil!")

local melee = {}
local gb_settings = GB_SETTINGS
local helpers = require("src.aimbot.helpers")

---@param usercmd UserCmd
---@param weapon Entity
function melee:CreateMove(usercmd, weapon, m_team)
	local swing_trace = weapon:DoSwingTrace()
	if swing_trace and swing_trace.entity and swing_trace.fraction >= gb.flVisibleFraction then
		local entity = swing_trace.entity
		local entity_team = entity:GetTeamNumber()
		local index = entity:GetIndex()
		if entity_team ~= m_team and entity:IsAlive() then
			if weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_KNIFE then
				return
			end
			if gb_settings.aimbot.ignore.cloaked and entity:InCond(E_TFCOND.TFCond_Cloaked) then
				return
			end
			helpers:MakeWeaponShoot(usercmd, index)
			return
		end
	end
end

return melee