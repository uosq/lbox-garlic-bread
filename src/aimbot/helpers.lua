local helpers = {}
local gb = GB_GLOBALS

local HEADSHOT_WEAPONS_INDEXES = {
	[230] = true, --- SYDNEY SLEEPER
	[61] = true, --- AMBASSADOR
	[1006] = true, --- FESTIVE AMBASSADOR
}

---@param usercmd UserCmd
---@param targetIndex integer
function helpers:MakeWeaponShoot(usercmd, targetIndex)
	usercmd.buttons = usercmd.buttons | IN_ATTACK
	gb.nAimbotTarget = targetIndex
	gb.bIsAimbotShooting = true
end

---@param bone Matrix3x4
function helpers:GetBoneOrigin(bone)
	return Vector3(bone[1][4], bone[2][4], bone[3][4])
end

--- returns true for head and false for body
function helpers:ShouldAimAtHead(localplayer, weapon)
	if localplayer and weapon then
		local weapon_id = weapon:GetWeaponID()
		local Head, Body = true, false

		if
			weapon_id == E_WeaponBaseID.TF_WEAPON_SNIPERRIFLE
			or weapon_id == E_WeaponBaseID.TF_WEAPON_SNIPERRIFLE_DECAP
		then
			return localplayer:InCond(E_TFCOND.TFCond_Zoomed) and Head or Body
		end

		local weapon_index = weapon:GetPropInt("m_Item", "m_iItemDefinitionIndex")

		if weapon_index and HEADSHOT_WEAPONS_INDEXES[weapon_index] then
			return weapon:GetWeaponSpread() > 0 and Body or Head
		end

		return Body
	end
	return nil
end

--- some people call it eye position
---@return Vector3 
function helpers:GetShootPosition(localplayer)
	return localplayer:GetAbsOrigin() + localplayer:GetPropVector("m_vecViewOffset[0]")
end

function helpers:calc_fov(fov, aspect_ratio)
	local halfanglerad = fov * (0.5 * math.pi / 180)
	local t = math.tan(halfanglerad) * (aspect_ratio / (4 / 3))
	local ret = (180 / math.pi) * math.atan(t)
	return ret * 2
end

return helpers