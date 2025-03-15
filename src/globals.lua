GB_GLOBALS = {
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

	aimbot_modes = {plain = "plain", smooth = "smooth", silent = "silent", assistance = "assistance"},

	flVisibleFraction = 0.4,
}

local lastFire = 0
local nextAttack = 0
local old_weapon = nil

local function GetLastFireTime(weapon)
	return weapon:GetPropFloat("LocalActiveTFWeaponData", "m_flLastFireTime")
end

local function GetNextPrimaryAttack(weapon)
	return weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")
end

--- https://www.unknowncheats.me/forum/team-fortress-2-a/273821-canshoot-function.html
function GB_GLOBALS.CanWeaponShoot()
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
end