--- Not used (yet)

local sim = {}

local env = physics.CreateEnvironment()
local MAX_SIM_TIME = 2.0

env:SetAirDensity(2.0)
env:SetGravity(Vector3(0, 0, -800))
env:SetSimulationTimestep(globals.TickInterval())

local TICK_INTERVAL = globals.TickInterval()
local MASK_SHOT_HULL = MASK_SHOT_HULL

local PROJECTILE_MODELS = {
	[E_WeaponBaseID.TF_WEAPON_ROCKETLAUNCHER] = [[models/weapons/w_models/w_rocket.mdl]],
	[E_WeaponBaseID.TF_WEAPON_GRENADELAUNCHER] = [[models/weapons/w_models/w_grenade_grenadelauncher.mdl]],
	[E_WeaponBaseID.TF_WEAPON_STICKBOMB] = [[models/weapons/w_models/w_stickybomb.mdl]],
}

local PROJECTILE_BOXES = {
	[E_WeaponBaseID.TF_WEAPON_ROCKETLAUNCHER] = { mins = Vector3(), maxs = Vector3() },
	[E_WeaponBaseID.TF_WEAPON_GRENADELAUNCHER] = { mins = Vector3(-4.0, -4.0, -4.0), maxs = Vector3(4.0, 4.0, 4.0) },
	[E_WeaponBaseID.TF_WEAPON_STICKBOMB] = { mins = Vector3(-4.0, -4.0, -4.0), maxs = Vector3(4.0, 4.0, 4.0) },
}

-- projectile info by definition index
local PROJ_INFO_DEF = {
	[414] = { 1540, 0 }, -- Liberty Launcher
	[308] = { 1513.3, 0.4 }, -- Loch n' Load
	[595] = { 3000, 0.2 }, -- Manmelter
}

-- projectile info by weapon ID
local PROJ_INFO_ID = {
	[E_WeaponBaseID.TF_WEAPON_ROCKETLAUNCHER] = { 1100, 0 },
	[E_WeaponBaseID.TF_WEAPON_DIRECTHIT] = { 1980, 0 },
	[E_WeaponBaseID.TF_WEAPON_GRENADELAUNCHER] = { 1216.6, 0.5 },
	[E_WeaponBaseID.TF_WEAPON_PIPEBOMBLAUNCHER] = { 1100, 0 },
	[E_WeaponBaseID.TF_WEAPON_SYRINGEGUN_MEDIC] = { 1000, 0.2 },
	[E_WeaponBaseID.TF_WEAPON_FLAMETHROWER] = { 1000, 0.2, 0.33 },
	[E_WeaponBaseID.TF_WEAPON_FLAREGUN] = { 2000, 0.3 },
	[E_WeaponBaseID.TF_WEAPON_CLEAVER] = { 3000, 0.2 },
	[E_WeaponBaseID.TF_WEAPON_CROSSBOW] = { 2400, 0.2 },
	[E_WeaponBaseID.TF_WEAPON_SHOTGUN_BUILDING_RESCUE] = { 2400, 0.2 },
	[E_WeaponBaseID.TF_WEAPON_CANNON] = { 1453.9, 0.4 },
	[E_WeaponBaseID.TF_WEAPON_RAYGUN] = { 1100, 0 },
}

-- Default projectile info
local DEFAULT_PROJ_INFO = { 1100, 0.2 }

-- Cache parsed models to avoid repeated parsing
local modelCache = {}

---@param pWeapon Entity
---@param pLocal Entity
local function GetProjectileOffset(pLocal, pWeapon)
	local temp = {
		[E_WeaponBaseID.TF_WEAPON_GRENADELAUNCHER] = Vector3(16.0, 8.0, -6.0),
		[E_WeaponBaseID.TF_WEAPON_PIPEBOMBLAUNCHER] = Vector3(16.0, 8.0, -6.0),
		[E_WeaponBaseID.TF_WEAPON_COMPOUND_BOW] = Vector3(23.5, 8.0, -3.0),
		[E_WeaponBaseID.TF_WEAPON_ROCKETLAUNCHER] = Vector3(23.5, 12.0, -3.0),
	}

	return temp[pWeapon:GetWeaponID()] or pLocal:GetPropVector("m_vecViewOffset[0]")
end

---@param pWeapon Entity
local function GetProjectileModel(pWeapon)
	local weaponID = pWeapon:GetWeaponID()
	return PROJECTILE_MODELS[weaponID] or PROJECTILE_MODELS[E_WeaponBaseID.TF_WEAPON_ROCKETLAUNCHER]
end

local function GetProjectileBox(pWeapon)
	local weaponID = pWeapon:GetWeaponID()
	return PROJECTILE_BOXES[weaponID] or PROJECTILE_BOXES[E_WeaponBaseID.TF_WEAPON_ROCKETLAUNCHER]
end

-- Optimized remap function with early returns
local function RemapValClamped(val, A, B, C, D)
	if A == B then
		return val >= B and D or C
	end

	-- Early clamp check
	if val <= A then
		return C
	end
	if val >= B then
		return D
	end

	local cVal = (val - A) / (B - A)
	return C + (D - C) * cVal
end

local function GetProjectileInfo(weapon)
	local id = weapon:GetWeaponID()
	local defIndex = weapon:GetPropInt("m_iItemDefinitionIndex")

	-- Handle special cases first (most performance critical)
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

	-- Check cached tables
	return PROJ_INFO_DEF[defIndex] or PROJ_INFO_ID[id] or DEFAULT_PROJ_INFO
end

local function CreateProjectile(pWeapon)
	local projModel = GetProjectileModel(pWeapon)

	if not modelCache[projModel] then
		local solid, collisionModel = physics.ParseModelByName(projModel)
		modelCache[projModel] = {
			solid = solid,
			collisionModel = collisionModel,
			surfaceProp = solid:GetSurfacePropName(),
			objectParams = solid:GetObjectParameters(),
		}
	end

	local cached = modelCache[projModel]
	local projectile = env:CreatePolyObject(cached.collisionModel, cached.surfaceProp, cached.objectParams)
	projectile:Wake()
	return projectile
end

---@param pLocal Entity The localplayer
---@param pWeapon Entity The localplayer's weapon
---@param vecForward Vector3 The initial angle of the projectile
---@param nTime number Number of seconds we want to simulate
---@return {pos: Vector3, time_secs: number, target_index?: integer, error?: number}[]
function sim.Run(pLocal, pWeapon, vecForward, nTime)
	local positions = {}

	local projectile = CreateProjectile(pWeapon)
	local projinfo = GetProjectileInfo(pWeapon)

	local viewangles = engine.GetViewAngles()
	local viewoffset = GetProjectileOffset(pLocal, pWeapon)
	local previousPos = pLocal:GetAbsOrigin() + (viewangles:Forward() * viewoffset)
	local localPlayerIndex = pLocal:GetIndex()

	local speed = projinfo[1]
	local velocity = viewangles:Forward() * speed

	local bbox = GetProjectileBox(pWeapon)
	local mins, maxs = bbox.mins, bbox.maxs

	projectile:SetPosition(previousPos, vecForward, true)
	projectile:SetVelocity(velocity, Vector3())

	-- get max simulation time
	local maxSimTime = math.min(MAX_SIM_TIME, nTime)

	local stepCount = 0
	local currentTime = 0

	-- Create trace filter function once
	local traceFilter = function(ent, contentsMask)
		return ent:GetIndex() ~= localPlayerIndex
	end

	while currentTime < maxSimTime do
		local currentPos = projectile:GetPosition()

		local trace = engine.TraceHull(previousPos, currentPos, mins, maxs, MASK_SHOT_HULL, traceFilter)

		stepCount = stepCount + 1
		positions[stepCount] = {
			pos = currentPos,
			time_secs = currentTime,
		}

		if trace and trace.fraction < 1 then
			break -- projectile hit something
		end

		previousPos = currentPos
		env:Simulate(TICK_INTERVAL)
		currentTime = currentTime + TICK_INTERVAL
	end

	env:DestroyObject(projectile)
	env:ResetSimulationClock()

	return positions
end

function sim.Unload()
	-- clear model cache
	modelCache = {}

	-- clean up physics objects
	for _, obj in pairs(env:GetActiveObjects()) do
		env:DestroyObject(obj)
	end

	physics.DestroyEnvironment(env)
end

return sim
