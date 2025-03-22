GB_GLOBALS = {
	bIsStacRunning = false,

	bIsAimbotShooting = false,
	nAimbotTarget = nil,

	bWarping = false,
	bRecharging = false,

	nPreAspectRatio = 0,

	bSpectated = false,
	bFakeLagEnabled = false,

	aimbot_modes = {plain = "plain", smooth = "smooth", silent = "silent", assistance = "assistance"},

	flVisibleFraction = 0.4,

	bIsPreRelease = true,
}

local sqrt, atan = math.sqrt, math.atan
local RADPI = 180/math.pi

--[[local lastFire = 0
local nextAttack = 0
local old_weapon = nil]]

local function GetNextAttack(player)
	return player:GetPropFloat("bcc_localdata", "m_flNextAttack")
end

--[[local function GetLastFireTime(weapon)
	return weapon:GetPropFloat("LocalActiveTFWeaponData", "m_flLastFireTime")
end]]

local function GetNextPrimaryAttack(weapon)
	return weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")
end

--- https://www.unknowncheats.me/forum/team-fortress-2-a/273821-canshoot-function.html
--[[function GB_GLOBALS.CanWeaponShoot()
	local player = entities:GetLocalPlayer()
	if not player then return false end

	local weapon = player:GetPropEntity("m_hActiveWeapon")
	if not weapon or not weapon:IsValid() then return false end
	if weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0 then return false end

	local lastfiretime = GetLastFireTime(weapon)
	if lastFire ~= lastfiretime or weapon ~= old_weapon then
		lastFire = lastfiretime
		nextAttack = GetNextPrimaryAttack(weapon)
	end
	old_weapon = weapon
	return nextAttack <= globals.CurTime()
end]]

--- not sure if we should use this or the above
function GB_GLOBALS.CanWeaponShoot()
	local player = entities:GetLocalPlayer()
	if not player then return false end
	if player:InCond(E_TFCOND.TFCond_Taunting) then return false end

	local weapon = player:GetPropEntity("m_hActiveWeapon")
	if not weapon or not weapon:IsValid() then return false end
	if weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0 then return false end

	--- not a good solution but if it works it works
	if weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_PISTOL_SCOUT
	or weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_PISTOL then return true end

	--- globals.CurTime() is a little bit behind this one
	--- making us not able to shoot consistently and breaking the pistols
	local curtime = player:GetPropInt("m_nTickBase") * globals.TickInterval()
	return curtime >= GetNextPrimaryAttack(weapon) and curtime >= GetNextAttack(player)
end

---@param vec Vector3
function GB_GLOBALS.ToAngle(vec)
	local hyp = sqrt((vec.x * vec.x) + (vec.y * vec.y))
	return Vector3(atan(-vec.z, hyp) * RADPI, atan(vec.y, vec.x) * RADPI, 0)
end