local sim = {}

local env = physics.CreateEnvironment()
local MAX_SIM_TIME = 2.0

env:SetAirDensity(2.0)
env:SetGravity(Vector3(0, 0, -800))
env:SetSimulationTimestep(globals.TickInterval())

---@param pWeapon Entity
local function GetProjectileModel(pWeapon)
	local temp = {
		[E_WeaponBaseID.TF_WEAPON_ROCKETLAUNCHER] = [[models/weapons/w_models/w_rocket.mdl]],
		[E_WeaponBaseID.TF_WEAPON_GRENADELAUNCHER] = [[models/weapons/w_models/w_grenade_grenadelauncher.mdl]],
		[E_WeaponBaseID.TF_WEAPON_STICKBOMB] = [[models/weapons/w_models/w_stickybomb.mdl]],
	}

	return temp[pWeapon:GetWeaponID()] or temp[E_WeaponBaseID.TF_WEAPON_ROCKETLAUNCHER]
end

---@param val number
---@param min number
---@param max number
local function clamp(val, min, max)
	return math.max(min, math.min(val, max))
end

--- wtf is this? whyy the fuck is it like this
local function RemapValClamped(val, A, B, C, D)
	if A == B then
		return val >= B and D or C
	end

	local cVal = (val - A) / (B - A)
	cVal = clamp(cVal, 0, 1)

	return C + (D - C) * cVal
end

local function GetProjectileInfo(weapon)
	-- Projectile info by definition index
	local projInfo = {
		[414] = { 1540, 0 }, -- Liberty Launcher
		[308] = { 1513.3, 0.4 }, -- Loch n' Load
		[595] = { 3000, 0.2 }, -- Manmelter
	}

	-- Projectile info by weapon ID
	local projInfoID = {
		[E_WeaponBaseID.TF_WEAPON_ROCKETLAUNCHER] = { 1100, 0 }, -- Rocket Launcher
		[E_WeaponBaseID.TF_WEAPON_DIRECTHIT] = { 1980, 0 }, -- Direct Hit
		[E_WeaponBaseID.TF_WEAPON_GRENADELAUNCHER] = { 1216.6, 0.5 }, -- Grenade Launcher
		[E_WeaponBaseID.TF_WEAPON_PIPEBOMBLAUNCHER] = { 1100, 0 }, -- Rocket Launcher
		[E_WeaponBaseID.TF_WEAPON_SYRINGEGUN_MEDIC] = { 1000, 0.2 }, -- Syringe Gun
		[E_WeaponBaseID.TF_WEAPON_FLAMETHROWER] = { 1000, 0.2, 0.33 }, -- Flame Thrower
		[E_WeaponBaseID.TF_WEAPON_FLAREGUN] = { 2000, 0.3 }, -- Flare Gun
		[E_WeaponBaseID.TF_WEAPON_CLEAVER] = { 3000, 0.2 }, -- Flying Guillotine
		[E_WeaponBaseID.TF_WEAPON_CROSSBOW] = { 2400, 0.2 }, -- Crusader's Crossbow
		[E_WeaponBaseID.TF_WEAPON_SHOTGUN_BUILDING_RESCUE] = { 2400, 0.2 }, -- Rescue Ranger
		[E_WeaponBaseID.TF_WEAPON_CANNON] = { 1453.9, 0.4 }, -- Loose Cannon
		[E_WeaponBaseID.TF_WEAPON_RAYGUN] = { 1100, 0 }, -- Bison
	}
	local id = weapon:GetWeaponID()
	local defIndex = weapon:GetPropInt("m_iItemDefinitionIndex")

	-- Special cases
	if id == E_WeaponBaseID.TF_WEAPON_COMPOUND_BOW then
		local charge = globals.CurTime() - weapon:GetChargeBeginTime()
		return {
			RemapValClamped(charge, 0.0, 1.0, 1800, 2600),
			RemapValClamped(charge, 0.0, 1.0, 0.5, 0.1),
		}
	elseif id == E_WeaponBaseID.TF_WEAPON_PIPEBOMBLAUNCHER then
		local charge = globals.CurTime() - weapon:GetChargeBeginTime()
		return {
			RemapValClamped(charge, 0.0, 4.0, 900, 2400),
			RemapValClamped(charge, 0.0, 4.0, 0.5, 0.0),
		}
	end

	return projInfo[defIndex] or projInfoID[id] or { 1100, 0.2 }
end

local function CreateProjectile(pWeapon)
	local projModel = GetProjectileModel(pWeapon)
	local solid, collisionModel = physics.ParseModelByName(projModel)
	local projectile = env:CreatePolyObject(collisionModel, solid:GetSurfacePropName(), solid:GetObjectParameters())
	projectile:Wake()
	return projectile
end

---@param pLocal Entity The localplayer
---@param pWeapon Entity The localplayer's weapon
---@param vecForward Vector3 The initial angle of the projectile
---@return {pos: Vector3, time_secs: number, target_index?: integer, error?: number}[]
function sim.Run(pLocal, pWeapon, vecForward)
	local positions = {}

	local projectile = CreateProjectile(pWeapon)
	local projinfo = GetProjectileInfo(pWeapon)

	local viewangles = engine.GetViewAngles()
	local viewoffset = pLocal:GetPropVector("m_vecViewOffset[0]")
	local startPos = pLocal:GetAbsOrigin() + viewoffset

	local speed = projinfo[1]
	local velocity = viewangles:Forward() * speed

	projectile:SetPosition(startPos, vecForward, true)
	projectile:SetVelocity(velocity, Vector3())

	local tickInterval = globals.TickInterval()
	local running = true

	while running and env:GetSimulationTime() < MAX_SIM_TIME do
		local currentPos = projectile:GetPosition()

		local trace = engine.TraceLine(startPos, currentPos, MASK_SHOT_HULL, function(ent, contentsMask)
			return ent:GetIndex() ~= pLocal:GetIndex()
		end)

		local record = {
			pos = currentPos,
			time_secs = env:GetSimulationTime(),
		}

		table.insert(positions, record)

		if trace and trace.fraction < 1 then
			break -- projectile hit a wall or something idk
		end

		startPos = currentPos
		env:Simulate(tickInterval)
	end

	env:DestroyObject(projectile)
	env:ResetSimulationClock()

	return positions
end

function sim.Unload()
	for _, obj in pairs(env:GetActiveObjects()) do
		env:DestroyObject(obj)
	end

	physics.DestroyEnvironment(env)
end

return sim
