--[[ Made by navet ]]
-- Bundled by luabundle {"version":"1.7.0"}
local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
	local loadingPlaceholder = {[{}] = true}

	local register
	local modules = {}

	local require
	local loaded = {}

	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	require = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name](require, loaded, register, modules)
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return require, loaded, register, modules
end)(require)
__bundle_register("__root", function(require, _LOADED, __bundle_register, __bundle_modules)
require("src.globals")
require("src.commands")
require("src.bitbuf")
require("src.anticheat")

local aimbot = require("src.aimbot")
local tickshift = require("src.tickshift")
local antiaim = require("src.antiaim")
local visuals = require("src.visuals")
local movement = require("src.movement")
local chams = require("src.chams")

require("src.background")

callbacks.Unregister("CreateMove", "CM garlic bread cheat aimbot")
callbacks.Register("CreateMove", "CM garlic bread cheat aimbot", aimbot.CreateMove)
callbacks.Unregister("FrameStageNotify", "FSN garlic bread cheat aimbot frame stage")
callbacks.Register("FrameStageNotify", "FSN garlic bread cheat aimbot frame stage", aimbot.FrameStageNotify)
callbacks.Unregister("Draw", "DRAW garlic bread aimbot")
callbacks.Register("Draw", "DRAW garlic bread aimbot", aimbot.Draw)

callbacks.Unregister("CreateMove", "CM garlic bread tick shifting")
callbacks.Register("CreateMove", "CM garlic bread tick shifting", tickshift.CreateMove)
callbacks.Unregister("SendNetMsg", "NETMSG garlic bread tick shifting")
callbacks.Register("SendNetMsg", "NETMSG garlic bread tick shifting", tickshift.SendNetMsg)
callbacks.Unregister("Draw", "DRAW garlic bread tick shifting")
callbacks.Register("Draw", "DRAW garlic bread tick shifting", tickshift.Draw)

callbacks.Unregister("CreateMove", "CM garlic bread anti aim")
callbacks.Register("CreateMove", "CM garlic bread anti aim", antiaim.CreateMove)
callbacks.Unregister("Draw", "DRAW garlic bread anti aim")
callbacks.Register("Draw", "DRAW garlic bread anti aim", antiaim.Draw)

callbacks.Unregister("RenderView", "RV garlic bread custom fov")
callbacks.Register("RenderView", "RV garlic bread custom fov", visuals.CustomFOV)

callbacks.Unregister("CreateMove", "CM garlic bread movement")
callbacks.Register("CreateMove", "CM garlic bread movement", movement.CreateMove)

callbacks.Unregister("CreateMove", "CM garlic bread chams")
callbacks.Register("CreateMove", "CM garlic bread chams", chams.CreateMove)

callbacks.Unregister("DrawModel", "DME garlic bread chams")
callbacks.Register("DrawModel", "DME garlic bread chams", chams.DrawModel)

callbacks.Register("Unload", "UL garlic bread unload", function()
	antiaim.unload()
	GB_GLOBALS = nil
	collectgarbage("collect")
end)

end)
__bundle_register("src.background", function(require, _LOADED, __bundle_register, __bundle_modules)
local function Background()
	if clientstate:GetNetChannel() then
		Players = entities.FindByClass("CTFPlayer")
		Sentries = entities.FindByClass("CObjectSentrygun")
		Dispensers = entities.FindByClass("CObjectDispenser")
		Teleporters = entities.FindByClass("CObjectTeleporter")
	else
		Players, Sentries, Dispensers, Teleporters = nil, nil, nil, nil
	end
end

callbacks.Register("CreateMove", "CM garlic bread background", Background)

end)
__bundle_register("src.chams", function(require, _LOADED, __bundle_register, __bundle_modules)
---@class COLOR
---@field r integer
---@field g integer
---@field b integer
---@field a integer

local chams_materials = {
	flat = materials.Create(
		"garlic bread flat chams",
	[[
  "UnlitGeneric"
  {
    $basetexture "vgui/white_additive"
  }
  ]]
	),

	textured = materials.Create(
		"garlic bread textured chams",
	[[
  "VertexLitGeneric"
  {
    $basetexture "vgui/white_additive"
  }
  ]]
	),
}

local m_szMaterialMode = "flat"

local COLORS = {
	RED = { 255, 200, 200, 51 },
	BLU = { 94, 189, 224, 51 },

	TARGET = { 128, 255, 0, 50 },
	FRIEND = { 66, 245, 170, 50 },
	BACKTRACK = { 50, 166, 168, 50 },
	ANTIAIM = { 168, 50, 50, 50 },
	PRIORITY = { 238, 255, 0, 50 },

	LOCALPLAYER = { 156, 66, 245, 50 },
	VIEWMODEL_ARM = { 24, 255, 0, 50 },

	WEAPON_PRIMARY = { 163, 64, 90, 100 },
	WEAPON_SECONDARY = { 74, 79, 125, 100 },
	WEAPON_MELEE = { 255, 255, 255, 100 },

	RED_HAT = { 21, 255, 0, 150 },
	BLU_HAT = { 255, 0, 13, 150 },

	SENTRY_RED = { 255, 0, 0, 150 },
	SENTRY_BLU = { 8, 0, 255, 150 },

	DISPENSER_RED = { 130, 0, 0, 150 },
	DISPENSER_BLU = { 3, 0, 105, 150 },

	TELEPORTER_RED = { 173, 31, 107, 150 },
	TELEPORTER_BLU = { 0, 217, 255, 150 },

	AMMOPACK = { 255, 255, 255, 150 },
	HEALTHKIT = { 255, 200, 200, 255 },

	MVM_MONEY = { 52, 235, 82, 150 },

	RAGDOLL_RED = { 255, 150, 150, 100 },
	RAGDOLL_BLU = { 150, 150, 255, 100 },

  ORIGINAL_PLAYER = {255, 255, 255, 255},
  ORIGINAL_VIEWMODEL = {255, 255, 255, 255},
}

local chams = {}

local m_bEnabled = true
local m_nUpdateInterval = 5
local m_bDrawOnEnemyOnly = false
local m_bDrawOnVisibleOnly = true
local m_bDrawOriginalPlayerMaterial = false
local m_bDrawOriginalViewmodelArmMaterial = false

local m_bDrawOn = {
  HEALTHPACK = true,
  AMMOPACK = true,
  VIEWMODEL_ARM = true,
  PLAYERS = true,
  SENTRIES = true,
  DISPENSERS = true,
  TELEPORTERS = true,
  MONEY = true,
  LOCALPLAYER = true,
  ANTIAIM = true,
  BACKTRACK = true,
  RAGDOLLS = true,
}

---@type integer?
local localplayer_index = nil

local render = render
local entities = entities
local string = string
local playerlist = playerlist
local models = models

--- used for string.find
local WEARABLES_CLASS = "Wearable"
local TEAM_RED --[[, TEAM_BLU <const>]] = 2 --, 3
local SENTRY_CLASS, DISPENSER_CLASS, TELEPORTER_CLASS =
	 "CObjectSentrygun", "CObjectDispenser", "CObjectTeleporter"
local MVM_MONEY_CLASS = "CCurrencyPack"
local VIEWMODEL_ARM_CLASS = "CTFViewModel"

---@param r integer
---@param g integer
---@param b integer
---@param a integer
local function get_color(r, g, b, a)
	return r / 255, g / 255, b / 255, a / 255
end

---@type table<integer, COLOR>, table<integer, COLOR>
local entity_list_color_front, entity_list_color_back = {}, {}

---@param entity Entity?
local function get_entity_color(entity)
	if (not entity) then return nil end

	if (entity:GetIndex() == localplayer_index) then
		return COLORS.LOCALPLAYER
	end

	if (GB_GLOBALS.m_nAimbotTarget == entity:GetIndex()) then
		return COLORS.TARGET
	end

	if (entity:IsWeapon() and entity:IsMeleeWeapon()) then
		return COLORS.WEAPON_MELEE
	elseif (entity:IsWeapon() and not entity:IsMeleeWeapon()) then
		return entity:GetLoadoutSlot() == E_LoadoutSlot.LOADOUT_POSITION_PRIMARY and COLORS.WEAPON_PRIMARY
			 or COLORS.WEAPON_SECONDARY
	end

	local team = entity:GetTeamNumber()
	do
		local class = entity:GetClass() -- not entity:GetPropInt("m_PlayerClass", "m_iClass")!!

		if (class == SENTRY_CLASS) then
			return team == TEAM_RED and COLORS.SENTRY_RED or COLORS.SENTRY_BLU
		elseif (class == DISPENSER_CLASS) then
			return team == TEAM_RED and COLORS.DISPENSER_RED or COLORS.DISPENSER_BLU
		elseif (class == TELEPORTER_CLASS) then
			return team == TEAM_RED and COLORS.TELEPORTER_RED or COLORS.TELEPORTER_BLU
		elseif (class == MVM_MONEY_CLASS) then
			return COLORS.MVM_MONEY
		elseif (class == VIEWMODEL_ARM_CLASS) then
			return COLORS.VIEWMODEL_ARM
		end

		if (class and string.find(class, WEARABLES_CLASS)) then
			return team == TEAM_RED and COLORS.RED_HAT or COLORS.BLU_HAT
		end
	end

	do
		local priority = playerlist.GetPriority(entity)
		if (priority and priority <= -1) then
			return COLORS.FRIEND
		elseif (priority and priority >= 1) then
			return COLORS.PRIORITY
		end
	end

	return COLORS[team == TEAM_RED and "RED" or "BLU"]
end


local function update_entities()
	collectgarbage("stop")

	local me = entities:GetLocalPlayer()
	if (not me) then return end

	local localteam = me:GetTeamNumber()
	if (not localteam) then return end

	local localindex = me:GetIndex()

	local max_entities = entities:GetHighestEntityIndex()
	for i = 1, max_entities do
		local entity = entities.GetByIndex(i)
		if (not entity) then goto continue end
		if (entity:IsDormant()) then goto continue end
		if (not m_bDrawOn.LOCALPLAYER and i == localindex) then goto continue end
		local class = entity:GetClass()
		local team = entity:GetTeamNumber()

		if (m_bDrawOnEnemyOnly and team == localteam) then goto continue end

		if (m_bDrawOn.PLAYERS and entity:IsPlayer() and entity:IsAlive()) then
			entity_list_color_back[i] = get_entity_color(entity)

			local moveChild = entity:GetMoveChild()
			while (moveChild) do
				entity_list_color_back[moveChild:GetIndex()] = get_entity_color(moveChild)
				moveChild = moveChild:GetMovePeer()
			end
		else
			--- excluding ragdolls, they aren't alive >:)
			if (entity:GetHealth() >= 1) then
				if ((m_bDrawOn.SENTRIES and class == SENTRY_CLASS) or (m_bDrawOn.DISPENSERS and class == DISPENSER_CLASS)
						 or (m_bDrawOn.TELEPORTERS and class == TELEPORTER_CLASS)) then
					entity_list_color_back[i] = get_entity_color(entity)
					goto continue
				end

				if (m_bDrawOn.MONEY and class == MVM_MONEY_CLASS) then
					entity_list_color_back[i] = get_entity_color(entity)
					goto continue
				end

				--- medkit, ammopack
				if ((m_bDrawOn.AMMOPACK or m_bDrawOn.HEALTHPACK) and class == "CBaseAnimating") then
					local model = entity:GetModel()
					if (not model) then goto continue end

					local model_name = string.lower(models.GetModelName(model))
					if (not model_name) then goto continue end

					if (m_bDrawOn.AMMOPACK and string.find(model_name, "ammo")) then
						entity_list_color_back[i] = COLORS.AMMOPACK
					elseif (m_bDrawOn.HEALTHPACK and (string.find(model_name, "health") or string.find(model_name, "medkit"))) then
						entity_list_color_back[i] = COLORS.HEALTHKIT
					end

					goto continue
				end
			end

			if (m_bDrawOn.RAGDOLLS and (class == "CTFRagdoll" or class == "CRagdollProp" or class == "CRagdollPropAttached")) then
				entity_list_color_back[i] = entity:GetPropInt("m_iTeam") == TEAM_RED and COLORS.RAGDOLL_RED or
					 COLORS.RAGDOLL_BLU
				goto continue
			end
		end
		::continue::
	end

	--- lol viewmodel is not in entity list
	if (m_bDrawOn.VIEWMODEL_ARM) then
		local viewmodel = me:GetPropEntity("m_hViewModel[0]")
		if (viewmodel) then
			entity_list_color_back[viewmodel:GetIndex()] = get_entity_color(viewmodel)
		end
	end

	entity_list_color_front, entity_list_color_back = entity_list_color_back, entity_list_color_front
	collectgarbage("restart")
end

---@param usercmd UserCmd
function chams.CreateMove(usercmd)
  if (m_bEnabled and (usercmd.tick_count % m_nUpdateInterval) == 0) then
    update_entities()
  end
end

---@param bool boolean
local function DEPTHOVERRIDE(bool)
  render.OverrideDepthEnable(bool, bool)
end

--- For AntiAim and Backtrack indicators
---@param context DrawModelContext
---@param material Material
---@param color COLOR
local function ChangeMaterialForIndicators(context, material, color)
	local r, g, b, a = get_color(table.unpack(color))
	context:SetAlphaModulation(a)
	context:ForcedMaterialOverride(material)
	context:SetColorModulation(r, g, b)

	DEPTHOVERRIDE(true)
	context:DepthRange(0, 0.2)
	context:Execute()
	context:DepthRange(0, 1)
	DEPTHOVERRIDE(false)
end

---@param context DrawModelContext
function chams.DrawModel(context)
  if (not m_bEnabled) then return end

	local material = chams_materials[m_szMaterialMode]
	if (not material) then return end

	local drawing_backtrack, drawing_antiaim = context:IsDrawingBackTrack(), context:IsDrawingAntiAim()
	if (drawing_antiaim or drawing_backtrack) then
		if ((drawing_antiaim and m_bDrawOn.ANTIAIM) or (drawing_backtrack and m_bDrawOn.BACKTRACK)) then
			local color = (drawing_antiaim and COLORS.ANTIAIM or COLORS.BACKTRACK)
			ChangeMaterialForIndicators(context, material, color)
		end
		return
	end

	local entity = context:GetEntity()
	if (not entity) then return end
	local index = entity:GetIndex()
	local class = entity:GetClass()
	if (not index or not class) then return end
	if (not entity_list_color_front[index]) then return end

	local color = entity_list_color_front[index]
	if (not color) then return end

	if ((m_bDrawOriginalPlayerMaterial and class == "CTFPlayer")
			 or (class == VIEWMODEL_ARM_CLASS and m_bDrawOriginalViewmodelArmMaterial)) then
		--- draw the original material
    if (class == VIEWMODEL_ARM_CLASS) then
      local r, g, b, a = get_color(table.unpack(COLORS.ORIGINAL_VIEWMODEL))
      context:SetColorModulation(r, g, b)
      context:SetAlphaModulation(a)
    elseif (class == "CTFPlayer") then
      local r, g, b, a = get_color(table.unpack(COLORS.ORIGINAL_PLAYER))
      context:SetColorModulation(r, g, b)
      context:SetAlphaModulation(a)
    end
		context:Execute()
	end

	DEPTHOVERRIDE(true)
	local r, g, b, a = get_color(table.unpack(color))
	context:SetAlphaModulation(a)
	context:ForcedMaterialOverride(material)
	context:SetColorModulation(r, g, b)

	if (not m_bDrawOnVisibleOnly) then
		context:DepthRange(0, (class == VIEWMODEL_ARM_CLASS and 0.1 or 0.2))
	end

	context:Execute()

	--- resetting stuff
	context:DepthRange(0, 1)
	-- why no leak? wtf
	--context:SetColorModulation(get_color(255, 255, 255, 255))
	--context:SetAlphaModulation(1)
	DEPTHOVERRIDE(false)
end

local function CMD_ToggleChams()
  m_bEnabled = not m_bEnabled
end

local function CMD_ChangeMaterialMode(args)
  if (not args or #args == 0 or not args[1]) then return end

  local name = tostring(args[1])
  if (not name) then return end

  m_szMaterialMode = name
end

local function CMD_ChangeColor(args, num_args)
  if (not args or #args == 0 or #args ~= num_args) then return end

  local selected_key = string.upper( table.remove(args, 1) )

  local r, g, b, a = table.unpack(args)
  if (not (r or g or b or a)) then return end

  r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a)
  COLORS[selected_key] = {r, g, b, a}
end

local function CMD_ToggleVisibleOnly()
  m_bDrawOnVisibleOnly = not m_bDrawOnVisibleOnly
  printc(150, 255, 150, 255, "Chams will draw only on " .. (m_bDrawOnVisibleOnly and "visible" or "invisible") .. " entities")
end

local function CMD_ToggleDrawOriginalPlayerMat()
  m_bDrawOriginalPlayerMaterial = not m_bDrawOriginalPlayerMaterial
  printc(150, 255, 150, 255, "Chams will " .. (m_bDrawOriginalPlayerMaterial and "draw" or "not draw") .. " the original player material")
end

local function CMD_ToggleDrawOriginalViewmodelMat()
  m_bDrawOriginalViewmodelArmMaterial = not m_bDrawOriginalViewmodelArmMaterial
  printc(150, 255, 150, 255, "Chams will " .. (m_bDrawOriginalViewmodelArmMaterial and "draw" or "not draw") .. " the original viewmodel material")
end

local function CMD_ToggleDrawOnEnemyOnly()
  m_bDrawOnEnemyOnly = not m_bDrawOnEnemyOnly
  printc(150, 255, 150, 255, "Chams will " .. (m_bDrawOnEnemyOnly and "draw" or "not draw") .. " only the enemies")
end

local function CMD_SetUpdateInterval(args, num_args)
  if (not args or #args ~= num_args) then return end
  local new_value = tonumber(args[1])
  if (new_value <= 0) then printc(255, 0, 0, 255, "The new value must be at least 1!") return end

  m_nUpdateInterval = new_value

  if (new_value < 3) then
    printc(252, 186, 3, 255, "Values below 3 are not worth it, I would recommend using 3 or more", "This is just a warning, the interval was still changed")
  end
end

GB_GLOBALS.RegisterCommand("chams->toggle", "Toggles chams", 0, CMD_ToggleChams)
GB_GLOBALS.RegisterCommand("chams->material", "Changes chams material | args: material mode (flat or textured)", 1, CMD_ChangeMaterialMode)
GB_GLOBALS.RegisterCommand("chams->change_color", "Changes the selected color on chams | args: color (string), r, g, b, a (numbers) | example: chams->change_color viewmodel_arm 150 255 150 255", 5, CMD_ChangeColor)
GB_GLOBALS.RegisterCommand("chams->toggle_visible_only", "Makes chams only draw on visible entities", 0, CMD_ToggleVisibleOnly)
GB_GLOBALS.RegisterCommand("chams->toggle_original_player_mat", "Toggles chams drawing the original player material", 0, CMD_ToggleDrawOriginalPlayerMat)
GB_GLOBALS.RegisterCommand("chams->toggle_enemy_only", "Toggles chams drawing on only enemies or not", 0, CMD_ToggleDrawOnEnemyOnly)
GB_GLOBALS.RegisterCommand("chams->toggle_original_viewmodel_mat", "Toggles chams drawing the original viewmodel material", 0, CMD_ToggleDrawOriginalViewmodelMat)
GB_GLOBALS.RegisterCommand("chams->set_update_interval", "Changes the entity update interval | args new value (number)", 1, CMD_SetUpdateInterval)
return chams

end)
__bundle_register("src.movement", function(require, _LOADED, __bundle_register, __bundle_modules)
local movement = {}

---@param usercmd UserCmd
local function CreateMove(usercmd)
	local localplayer = entities:GetLocalPlayer()
	if (not localplayer or not localplayer:IsAlive()) then return end
	if GB_GLOBALS and GB_GLOBALS.m_bBhopEnabled then
		local flags = localplayer:GetPropInt("m_fFlags")
		local ground = flags & FL_ONGROUND == 1
		local jump = usercmd.buttons & IN_JUMP == 1
		if ground and jump then
			usercmd.buttons = usercmd.buttons | IN_JUMP
		elseif (not ground and jump) or (not ground and not jump) then
			usercmd.buttons = usercmd.buttons & ~IN_JUMP
		end
	end
end

local function cmd_ToggleBhop()
	GB_GLOBALS.m_bBhopEnabled = not GB_GLOBALS.m_bBhopEnabled
	printc(150, 255, 150, 255, "Bhop is now " .. (GB_GLOBALS.m_bBhopEnabled and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("misc->toggle_bhop", "Toggles bunny hopping", 0, cmd_ToggleBhop)

movement.CreateMove = CreateMove
return movement

end)
__bundle_register("src.visuals", function(require, _LOADED, __bundle_register, __bundle_modules)
local visuals = {}

---@param setup ViewSetup
local function CustomFOV(setup)
	if not GB_GLOBALS then return end

	local player = entities:GetLocalPlayer()
	if (not player) then return end

	GB_GLOBALS.m_nPreAspectRatio = setup.aspectRatio
	setup.aspectRatio = GB_GLOBALS.m_nAspectRatio == 0 and setup.aspectRatio or GB_GLOBALS.m_nAspectRatio

	--[[
  90 fov = 106.26020812988
  120 = x
  106.26020812988*120 = 90x
  (120.26020812988*120)/90 = x fov
  --]]

		local fov = player:InCond(E_TFCOND.TFCond_Zoomed) and 20 or GB_GLOBALS.m_flCustomFOV
		local render_fov = (106.26020812988 * fov) / 90
		setup.fov = render_fov

		if GB_GLOBALS.m_bNoRecoil and player:GetPropInt("m_nForceTauntCam") == 0 then
			local punchangle = player:GetPropVector("m_vecPunchAngle")
			setup.angles = EulerAngles((setup.angles - punchangle):Unpack())
		end
end

visuals.CustomFOV = CustomFOV

local function cmd_ChangeFOV(args)
	if (not args or #args == 0 or not args[1]) then return end
	GB_GLOBALS.m_flCustomFOV = tonumber(args[1])
end

GB_GLOBALS.RegisterCommand("visuals->customfov", "Changes custom fov | args: new fov (number)", 1, cmd_ChangeFOV)

return visuals

end)
__bundle_register("src.antiaim", function(require, _LOADED, __bundle_register, __bundle_modules)
---@diagnostic disable:cast-local-type
local antiaim = {}

local m_bEnabled = false
local m_bPitchEnabled = false
local m_realyaw, m_fakeyaw, m_realpitch, m_fakepitch = 0, 0, 0, 0

---@param usercmd UserCmd
function antiaim.CreateMove(usercmd)
	if
		not GB_GLOBALS.m_bIsAimbotShooting
		and m_bEnabled
		and usercmd.buttons & IN_ATTACK == 0
		and not GB_GLOBALS.m_bIsStacRunning
		and not GB_GLOBALS.m_bWarping
		and not GB_GLOBALS.m_bRecharging
	then
		--- make sure we aren't overchoking
		if clientstate:GetChokedCommands() >= 21 then
			usercmd.sendpacket = true
			return
		end

		local view = engine:GetViewAngles()

		local realyaw = view.y + (m_realyaw or 0)
		local fakeyaw = view.y + (m_fakeyaw or 0)
		local realpitch = m_bPitchEnabled and m_realpitch or view.x
		local fakepitch = m_bPitchEnabled and m_fakepitch or view.x

		local is_real_yaw_tick = usercmd.tick_count % 2 == 0

		local pitch, yaw
		pitch = is_real_yaw_tick and realpitch or fakepitch
		yaw = is_real_yaw_tick and realyaw or fakeyaw

		usercmd:SetViewAngles(pitch, yaw, 0)
		usercmd.sendpacket = not is_real_yaw_tick
	end
end

function antiaim.unload()
	antiaim = nil
end

function antiaim.Draw()
	if (not m_bEnabled) then return end

	local player = entities:GetLocalPlayer()
	if (not player or not player:IsAlive()) then return end

	local origin = player:GetAbsOrigin()
	if (not origin) then return end

	local origin_screen = client.WorldToScreen(origin)
	if (not origin_screen) then return end

	local startpos = origin
	local endpos = nil

	local viewangle = engine:GetViewAngles().y

	local real_yaw, fake_yaw = m_realyaw + viewangle, m_fakeyaw + viewangle
	local real_direction, fake_direction
	real_direction = Vector3(math.cos(math.rad(real_yaw)), math.sin(math.rad(real_yaw)))
	fake_direction = Vector3(math.cos(math.rad(fake_yaw)), math.sin(math.rad(fake_yaw)))

	endpos = origin + (fake_direction * 10)

	local startpos_screen = client.WorldToScreen(startpos)
	if (not startpos_screen) then return end
	local endpos_screen = client.WorldToScreen(endpos)
	if (not endpos_screen) then return end

	--- fake yaw
	draw.Color(255, 150, 150, 255)
	draw.Line(startpos_screen[1], startpos_screen[2], endpos_screen[1], endpos_screen[2])

	--- real yaw
	draw.Color(150, 255, 150, 255)
	endpos = origin + (real_direction * 10)
	endpos_screen = client.WorldToScreen(endpos)
	if (not endpos_screen) then return end

	draw.Line(startpos_screen[1], startpos_screen[2], endpos_screen[1], endpos_screen[2])
end

local function cmd_toggle_aa()
	if (GB_GLOBALS.m_bIsStacRunning) then
		printc(255, 0, 0, 255, "STAC is active! Won't change AA")
		return
	end
	m_bEnabled = not m_bEnabled
	printc(150, 255, 150, 255, "Anti aim is now " .. (m_bEnabled and "enabled" or "disabled"))
end

local function cmd_set_options(args)
	if (not args or #args == 0) then return end
	if (not args[1] or not args[2] or not args[3]) then return end

	local fake = args[1] == "fake"
	local real = args[1] == "real"
	local wants_yaw = args[2] == "yaw"
	local wants_pitch = args[2] == "pitch"
	local new_value = tonumber(args[3])
	if (not new_value) then print("Invalid value!") return end

	--local key = "m_fl%s%s"
	--local formatted = string.format(key, fake and "Fake" or "Real", wants_yaw and "Yaw" or "Pitch")
	if (fake and wants_yaw) then
		m_fakeyaw = new_value
	elseif (fake and not wants_pitch) then
		m_fakepitch = new_value
	elseif (real and wants_yaw) then
		m_realyaw = new_value
	elseif (real and wants_pitch) then
		m_realpitch = new_value
	end
end

local function cmd_toggle_pitch()
	m_bPitchEnabled = not m_bPitchEnabled
	printc(150, 255, 150, 255, "Anti aim pitch is now " .. (m_bPitchEnabled and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("antiaim->change", "Changes antiaim's settings | args: fake or real (string), yaw or pitch (string), new value (number)", 3, cmd_set_options)
GB_GLOBALS.RegisterCommand("antiaim->toggle", "Toggles antiaim", 0, cmd_toggle_aa)
GB_GLOBALS.RegisterCommand("antiaim->toggle_pitch", "Toggles real and fake pitch from being added to viewangles", 0, cmd_toggle_pitch)
return antiaim

end)
__bundle_register("src.tickshift", function(require, _LOADED, __bundle_register, __bundle_modules)
local NEW_COMMANDS_SIZE = 4
local BACKUP_COMMANDS_SIZE = 3

local SIGNONSTATE_TYPE = 6
local CLC_MOVE_TYPE = 9

local charged_ticks = 0
local max_ticks = 0
local last_key_tick = 0
local next_passive_tick = 0

local m_enabled = true
local shooting = false
local warping, recharging = false, false

local font = draw.CreateFont("TF2 BUILD", 16, 1000)

---@type number, boolean
local m_localplayer_speed, m_bIsRED
m_bIsRED = false

local m_settings = {
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
}

local tickshift = {}

local function CanChoke()
	return clientstate:GetChokedCommands() < max_ticks
end

local function CanShift()
	return clientstate:GetChokedCommands() == 0
end

local function GetMaxServerTicks()
	local sv_maxusrcmdprocessticks = client.GetConVar("sv_maxusrcmdprocessticks")
	if sv_maxusrcmdprocessticks then
		return sv_maxusrcmdprocessticks > 0 and sv_maxusrcmdprocessticks or 9999999
	end
	return 24
end

---@param msg NetMessage
function HandleWarp(msg)
	local player = entities:GetLocalPlayer()
	if player and m_localplayer_speed <= 0 and not m_settings.warp.standing_still then
		return
	end

	if
		GB_GLOBALS.m_bIsAimbotShooting
		and GB_GLOBALS.usercmd_buttons
		and GB_GLOBALS.usercmd_buttons & IN_ATTACK ~= 0
	then
		return
	end

	if player and player:IsAlive() and charged_ticks > 0 and CanShift() then
		--local moveMsg = clc_Move()

		--- the new BitBuffer lib
		local buffer = BitBuffer()
		buffer:Reset()
		CLC_Move:WriteToBitBuffer(buffer, 2, 1)
		msg:ReadFromBitBuffer(buffer)
		buffer:Delete()

		--moveMsg:init()
		--msg:ReadFromBitBuffer(moveMsg.buffer)
		charged_ticks = charged_ticks - 1
	end
end

local function HandlePassiveRecharge()
	if not m_settings.warp.passive.enabled or charged_ticks >= max_ticks then
		return false
	end

	local player = entities:GetLocalPlayer()
	if (not player) then return false end

	if
		(globals.TickCount() >= next_passive_tick)
		or (m_settings.warp.passive.while_dead and not player:IsAlive())
	then
		charged_ticks = charged_ticks + 1
		local time = engine.RandomFloat(m_settings.warp.passive.min_time, m_settings.warp.passive.max_time)
		next_passive_tick = globals.TickCount() + (time * 66.67)
		return true
	end

	return false
end

local function HandleRecharge()
	if
		(shooting and not m_settings.warp.recharge.while_shooting)
		or (m_localplayer_speed <= 0 and not m_settings.warp.recharge.standing_still)
	then
		return false
	end

	if CanChoke() and charged_ticks < max_ticks and recharging then
		charged_ticks = charged_ticks + 1
		return true
	end

	if HandlePassiveRecharge() then
		return true
	end

	return false
end

--- Resets the variables to their default state when joining a new server
---@param msg NetMessage
local function HandleJoinServers(msg)
	if clientstate:GetClientSignonState() == E_SignonState.SIGNONSTATE_SPAWN then
		m_localplayer_speed = 0
		m_bIsRED = false
		max_ticks = GetMaxServerTicks()
		charged_ticks = 0
		last_key_tick = 0
		next_passive_tick = 0
		shooting = false
	end
end

---@param msg NetMessage
---@param reliable boolean
---@param isvoice boolean
function tickshift.SendNetMsg(msg, reliable, isvoice)
	GB_GLOBALS.m_bWarping = false
	GB_GLOBALS.m_bRecharging = false

	--- return early if user disabled with console commands
	if (not m_enabled) then return true end

	if msg:GetType() == SIGNONSTATE_TYPE then
		HandleJoinServers(msg)
	end

	if GB_GLOBALS.m_bIsStacRunning then
		return true
	end

	if engine.IsChatOpen() or engine.IsGameUIVisible() or engine.Con_IsVisible() then
		return true
	end

	if msg:GetType() == CLC_MOVE_TYPE then
		if warping and not recharging then
			GB_GLOBALS.m_bWarping = true
			HandleWarp(msg)
		elseif HandleRecharge() then
			GB_GLOBALS.m_bRecharging = true
			return false
		end
	end

	return true
end

local function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

---@param usercmd UserCmd
function tickshift.CreateMove(usercmd)
	if engine.IsChatOpen() or engine.IsGameUIVisible() or engine.Con_IsVisible()
		or GB_GLOBALS.m_bIsStacRunning or (not m_enabled) then
		return
	end

	local player = entities:GetLocalPlayer()
	if (not player) then return end

	m_localplayer_speed = player:EstimateAbsVelocity():Length() or 0
	m_bIsRED = player:GetTeamNumber() == 2
	max_ticks = GetMaxServerTicks()
	charged_ticks = clamp(charged_ticks, 0, max_ticks)

	shooting = ((usercmd.buttons & IN_ATTACK) ~= 0 or GB_GLOBALS.m_bIsAimbotShooting) and GB_GLOBALS.CanWeaponShoot()
	warping = input.IsButtonDown(m_settings.warp.send_key)
	GB_GLOBALS.m_bWarping = warping
	recharging = input.IsButtonDown(m_settings.warp.recharge_key)

	local state, tick = input.IsButtonPressed(m_settings.warp.passive.toggle_key)
	if state and last_key_tick < tick then
		m_settings.warp.passive.enabled = not m_settings.warp.passive.enabled
		last_key_tick = tick
		client.ChatPrintf("Passive recharge: " .. (m_settings.warp.passive.enabled and "ON" or "OFF"))
	end
end

function tickshift.Draw()
	if
		engine:Con_IsVisible()
		or engine:IsGameUIVisible()
		or (engine:IsTakingScreenshot() and gui.GetValue("clean screenshots") == 1)
		or (not m_enabled)
	then
		return
	end

	local screenX, screenY = draw:GetScreenSize()
	local centerX, centerY = math.floor(screenX / 2), math.floor(screenY / 2)

	local formatted_text = string.format("%i / %i", charged_ticks, max_ticks)
	draw.SetFont(font)
	local textW, textH = draw.GetTextSize(formatted_text)
	local textX, textY = math.floor(centerX - (textW / 2)), math.floor(centerY + textH + 20)

	local barWidth = 80
	local offset = 2
	local percent = charged_ticks / max_ticks
	local barX, barY = centerX - math.floor(barWidth / 2), math.floor(centerY + textH + 20)

	draw.Color(30, 30, 30, 252)
	draw.FilledRect(
		math.floor(barX - offset),
		math.floor(barY - offset),
		math.floor(barX + barWidth + offset),
		math.floor(barY + textH + offset)
	)

	local color = m_bIsRED and { 236, 57, 57, 255 } or { 12, 116, 191, 255 }
	draw.Color(table.unpack(color))

	pcall(
		draw.FilledRect,
		math.floor(barX or 0),
		math.floor(barY or 0),
		math.floor((barX or 0) + ((barWidth * (percent or 0)) or 0)),
		math.floor((barY or 0) + (textH or 0))
	)

	draw.SetFont(font)
	draw.Color(255, 255, 255, 255)
	draw.TextShadow(textX, textY, formatted_text)
end

local function cmd_ToggleTickShift()
	m_enabled = not m_enabled
	print(150, 255, 150, 255, "Tick shifting is now " .. (m_enabled and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("tickshift->toggle", "Toggles tickshifting (warp, recharge)", 0, cmd_ToggleTickShift)
return tickshift

end)
__bundle_register("src.aimbot", function(require, _LOADED, __bundle_register, __bundle_modules)
local aimbot_mode = { plain = 1, smooth = 2, silent = 3 }

local settings = {
	fov = 10,
	key = E_ButtonCode.KEY_LSHIFT,
	autoshoot = true,
	mode = aimbot_mode.silent,
	lock_aim = true,
	smooth_value = 10, --- lower value, smoother aimbot (10 = very smooth, 100 = basically plain aimbot)
	melee_rage = false,
	auto_spinup = true,

	--- should aimbot run when using one of them?
	hitscan = true,
	melee = true,
	projectile = true,

	autobackstab = true,

	--- engineer
	aim_friendly_buildings = true,

	ignore = {
		cloaked = true,
		disguised = false,
		taunting = false,
		bonked = true,
		friends = false,
		deadringer = false,
	},

	aim = {
		players = true,
		npcs = true,
		sentries = true,
		other_buildings = true,
	},
}

local m_bReadyToBackstab = false

---@type Entity?, Entity?, integer?
local localplayer, weapon, m_team = nil, nil, nil

local width, height = draw.GetScreenSize()

--- TODO: rename later to CLASS_BONES
local CLASS_HITBOXES = require("src.hitboxes")

--- only works with STUDIO models
--[[local HITBOXES = {
	Head = 6,
	Body = 3,
	--LeftHand = 9,
	LeftArm = 8,
	--RightHand = 12,
	RightArm = 11,
	--LeftFeet = 15,
	--RightFeet = 18,
	LeftLeg = 14,
	RightLeg = 17,
}]]

local VISIBLE_FRACTION = 0.4

local lastFire = 0
local nextAttack = 0
local old_weapon = nil

local HEADSHOT_WEAPONS_INDEXES = {
	--[230] = true, --- SYDNEY SLEEPER i dont think a sydney sleeper is necessary here
	[61] = true, --- AMBASSADOR
	[1006] = true, --- FESTIVE AMBASSADOR
}

GB_AIMBOT_GETSETTINGS = function()
	return settings
end

--- stuff used by melee aimbot
local ENGINEER_CLASS = 9
local MAX_UPGRADE_LEVEL = 3
local BUILDINGS = {
	CObjectSentrygun = true,
	CObjectDispenser = true,
	CObjectTeleporter = true,
}

--- stuff used by hitscan aimbot
local AcceptableEntities = {
	CObjectSentrygun = true,
	CObjectDispenser = true,
	CObjectTeleporter = true,
	CTFPlayer = true,
}

--- Cache some important functions

local TraceLine = engine.TraceLine
local sqrt = math.sqrt
local atan = math.atan
local PI = math.pi
local RADPI = 180 / PI
local vecMultiply = vector.Multiply

---

--- some people call it eye position
local function GetShootPosition()
	if localplayer then
		return localplayer:GetAbsOrigin() + localplayer:GetPropVector("m_vecViewOffset[0]")
	end
	return nil
end

--- returns true for head and false for body
local function ShouldAimAtHead()
	if localplayer and weapon then
		--[[
    if weapon_index and HEADSHOT_WEAPONS_INDEXES[weapon_index] then
      return HITBOXES.Head
    end]]

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

local function GetLastFireTime()
	return weapon and weapon:GetPropFloat("LocalActiveTFWeaponData", "m_flLastFireTime") or 0
end

local function GetNextPrimaryAttack()
	return weapon and weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack") or 0
end

--- https://www.unknowncheats.me/forum/team-fortress-2-a/273821-canshoot-function.html
local function CanWeaponShoot()
	if not weapon or weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0 then
		return false
	end
	local lastfiretime = GetLastFireTime()
	if lastFire ~= lastfiretime or weapon ~= old_weapon then
		lastFire = lastfiretime
		nextAttack = GetNextPrimaryAttack()
	end
	old_weapon = weapon
	return nextAttack <= globals.CurTime()
end

GB_GLOBALS.CanWeaponShoot = CanWeaponShoot

---@param bone Matrix3x4
local function GetBoneOrigin(bone)
	return Vector3(bone[1][4], bone[2][4], bone[3][4])
end

---@param vec Vector3
local function ToAngle(vec)
	local hyp = sqrt((vec.x * vec.x) + (vec.y * vec.y))
	return Vector3(atan(-vec.z, hyp) * RADPI, atan(vec.y, vec.x) * RADPI, 0)
end

---@param usercmd UserCmd
---@param targetIndex integer
local function MakeWeaponShoot(usercmd, targetIndex)
	usercmd.buttons = usercmd.buttons | IN_ATTACK
	GB_GLOBALS.m_nAimbotTarget = targetIndex
	GB_GLOBALS.m_bIsAimbotShooting = true
end

--- Only run this in CreateMove, after localplayer and weapon are valid!
---@param usercmd UserCmd
local function RunMelee(usercmd)
	if weapon and weapon:IsMeleeWeapon() then
		local swing_trace = weapon:DoSwingTrace()

		if swing_trace and swing_trace.entity and swing_trace.fraction <= 0.95 then
			local entity = swing_trace.entity
			local entity_team = entity:GetTeamNumber()
			local index = entity:GetIndex()
			if
				settings.aim_friendly_buildings
				and BUILDINGS[entity:GetClass()]
				and localplayer
				and localplayer:GetPropInt("m_PlayerClass", "m_iClass") == ENGINEER_CLASS
				and (
					(entity:GetHealth() >= 1 and entity:GetHealth() < entity:GetMaxHealth())
					or (entity:GetPropInt("m_iUpgradeLevel") < MAX_UPGRADE_LEVEL)
				)
			then
				MakeWeaponShoot(usercmd, index)
				return true
			end

			if entity_team ~= m_team and entity:IsAlive() then
				if weapon and weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_KNIFE and settings.autobackstab then
					if m_bReadyToBackstab then
						MakeWeaponShoot(usercmd, index)
					end

					--- dont run after this or it will try to butterknife
					GB_GLOBALS.m_nAimbotTarget = index
					GB_GLOBALS.m_bIsAimbotShooting = false
					return true
				end

				MakeWeaponShoot(usercmd, index)
				return true
			end
		end
	end
	return false
end

---@param usercmd UserCmd
local function CreateMove(usercmd)
	GB_GLOBALS.m_bIsAimbotShooting = false
	GB_GLOBALS.m_nAimbotTarget = nil

	localplayer = entities:GetLocalPlayer()
	if not localplayer or not localplayer:IsAlive() then return end
	m_team = localplayer:GetTeamNumber()

	weapon = localplayer:GetPropEntity("m_hActiveWeapon")
	if not weapon then return end

	if not input.IsButtonDown(settings.key) then return end
	if engine.IsChatOpen() or engine.Con_IsVisible() or engine.IsGameUIVisible() then return end

	--- if it returns true, it means it was a melee weapon and it did the proper math for them
	if weapon:IsMeleeWeapon() then
		RunMelee(usercmd)
		return
	end

	if (weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0) then return end

	--- try to make stac dont ban us :3
	local m_AimbotMode = GB_GLOBALS.m_bIsStacRunning and aimbot_mode.smooth or settings.mode
	local m_SmoothValue = GB_GLOBALS.m_bIsStacRunning and 10 or settings.smooth_value

	local shoot_pos = GetShootPosition()
	if not shoot_pos then
		return
	end

	local punchangles = weapon:GetPropVector("m_vecPunchAngle") or Vector3()
	local should_aim_at_head = ShouldAimAtHead()

	--- trust me, i tried like 3 or 4 different math combinations
	--- and i decided to just give up and paste amalgam for the fov xd

	local best_angle, best_fov, target, looking_at_target = nil, settings.fov, nil, false

	---@param class Entity[]
	local function CheckBuilding(class)
		for _, entity in pairs(class) do
			local mins, maxs = entity:GetMins(), entity:GetMaxs()
			local center = entity:GetAbsOrigin() + ((mins + maxs) * 0.5)

			local trace = TraceLine(shoot_pos, center, MASK_SHOT_HULL)
			if trace and trace.entity == entity and trace.fraction >= VISIBLE_FRACTION then
				local angle = ToAngle(center - shoot_pos) - (usercmd.viewangles - punchangles)
				local fov = sqrt((angle.x ^ 2) + (angle.y ^ 2))

				if fov < best_fov then
					best_fov = fov
					best_angle = angle
					target = entity:GetIndex() --- not saving the whole entity here, too much memory used!
				end
			end
		end
	end

	for _, entity in pairs(Players) do
		if not entity or entity:IsDormant() or not entity:IsAlive() or entity:GetTeamNumber() == m_team then
			goto continue
		end

		if entity:InCond(E_TFCOND.TFCond_Ubercharged) then
			goto continue
		elseif entity:InCond(E_TFCOND.TFCond_Cloaked) and settings.ignore.cloaked then
			goto continue
		end

		--[[
   local mins, maxs = entity:GetMins(), entity:GetMaxs()
   local center = entity:GetAbsOrigin() + ((mins + maxs) * ]]

		local enemy_class = entity:GetPropInt("m_PlayerClass", "m_iClass")
		local best_bone_for_weapon = nil

		if should_aim_at_head == nil then
			goto continue
		elseif should_aim_at_head == true then
			best_bone_for_weapon = CLASS_HITBOXES[enemy_class][1]
		elseif should_aim_at_head == false then
			best_bone_for_weapon = #CLASS_HITBOXES[enemy_class] == 6 and CLASS_HITBOXES[enemy_class][2]
				or CLASS_HITBOXES[enemy_class][3] --- if size is 6 then we have no HeadUpper as the first value
		end

		local bones = entity:SetupBones()
		if not bones then goto continue end

		local bone_position = GetBoneOrigin(bones[best_bone_for_weapon])
		if not bone_position then goto continue end

		local trace = TraceLine(shoot_pos, bone_position, MASK_SHOT_HULL)
		if not trace then goto continue end

		local looking_at_trace =
			TraceLine(shoot_pos, shoot_pos + engine:GetViewAngles():Forward() * 1000, MASK_SHOT_HULL)
		if not looking_at_trace then
			goto continue
		end

		local function do_aimbot_calc()
			local angle = ToAngle(bone_position - shoot_pos) - (usercmd.viewangles - punchangles)
			local fov = sqrt((angle.x ^ 2) + (angle.y ^ 2))

			if fov < best_fov then
				best_fov = fov
				best_angle = angle
				target = entity:GetIndex() --- not saving the whole entity here, too much memory used!
				return true
			end
			return false
		end

		if trace and trace.entity == entity and trace.fraction >= VISIBLE_FRACTION then
			--- for smooth aimbot, ensure we are aiming somewhat close to the target so we can shoot
			if looking_at_trace and looking_at_trace.entity and looking_at_trace.entity == entity then
				looking_at_target = true
			end

			do_aimbot_calc()
		else
			local BONES = CLASS_HITBOXES[enemy_class]
			for _, bone in ipairs(BONES) do
				--- already tried the best one
				if bone ~= best_bone_for_weapon then
					bone_position = GetBoneOrigin(bones[bone])
					if not bone_position then goto skip_bone end

					trace = TraceLine(shoot_pos, bone_position, MASK_SHOT_HULL)
					if not trace then goto skip_bone end

					if trace.entity == entity and trace.fraction >= VISIBLE_FRACTION then
						if
							not looking_at_target and looking_at_trace
							and looking_at_trace.entity and looking_at_trace.entity == entity
							and looking_at_trace.hitbox ~= 0 then
							looking_at_target = true
						end

						do_aimbot_calc()
					end
				end
				::skip_bone::
			end
		end
		::continue::
	end

	if settings.aim.sentries then
		CheckBuilding(Sentries)
	end

	if settings.aim.other_buildings then
		CheckBuilding(Dispensers)
		CheckBuilding(Teleporters)
	end

	local can_shoot = CanWeaponShoot() or settings.lock_aim -- if autoshoot is off and player is trying to shoot, we aim for them

	if best_angle then
		local smoothed = engine:GetViewAngles() + vecMultiply(best_angle, (m_SmoothValue * 0.01 --[[/100]]))
		if can_shoot then
			usercmd.viewangles = usercmd.viewangles + (m_AimbotMode == aimbot_mode.smooth and smoothed or best_angle)
		end

		if m_AimbotMode == aimbot_mode.plain and can_shoot then
			local angle = engine:GetViewAngles() + best_angle
			engine.SetViewAngles(EulerAngles(angle:Unpack()))
		elseif m_AimbotMode == aimbot_mode.smooth then
			engine.SetViewAngles(EulerAngles(smoothed:Unpack()))
			usercmd.viewangles = smoothed
		end

		if can_shoot then
			if m_AimbotMode ~= aimbot_mode.smooth then
				usercmd.buttons = usercmd.buttons | IN_ATTACK
			else
				if looking_at_target then
					usercmd.buttons = usercmd.buttons | IN_ATTACK
				end

			end
			GB_GLOBALS.m_bIsAimbotShooting = true
			GB_GLOBALS.m_nAimbotTarget = target
		end
	end

	if (settings.auto_spinup and weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_MINIGUN and usercmd.buttons & IN_ATTACK == 0) then
		usercmd.buttons = usercmd.buttons | IN_ATTACK2
	end
end

---@param stage E_ClientFrameStage
local function FrameStageNotify(stage)
	if stage == E_ClientFrameStage.FRAME_NET_UPDATE_END and localplayer and weapon then
		m_bReadyToBackstab = weapon:GetPropBool("m_bReadyToBackstab") or false
	end
end

local function Draw()
	if (engine:IsGameUIVisible() or engine:Con_IsVisible()) then return end

	if localplayer and localplayer:IsAlive() and settings.fov <= 89 then
		 -- Get base FOV considering scope state
		 local base_fov = localplayer:InCond(E_TFCOND.TFCond_Zoomed) and 20 or GB_GLOBALS.m_flCustomFOV
		 
		 -- Convert FOVs to distances at a normalized screen width
		 local screen_distance = (width / 2) / math.tan(math.rad(base_fov / 2))
		 local circle_radius = screen_distance * math.tan(math.rad(settings.fov / 2))
		 
		 -- Scale the radius to screen coordinates
		 local scaled_radius = (circle_radius / screen_distance) * (width / 2)

		 -- Draw the circle with appropriate color
		 if GB_GLOBALS.m_nAimbotTarget then
			  draw.Color(150, 255, 150, 255)
		 else
			  draw.Color(255, 255, 255, 255)
		 end

		 draw.OutlinedCircle(math.floor(width * 0.5), math.floor(height * 0.5), math.floor(scaled_radius), 64)
	end
end

local function cmd_ChangeAimbotMode(args)
	if (not args or #args == 0) then return end
	local mode = tostring(args[1])
	settings.mode = aimbot_mode[mode]
end

local function cmd_ChangeAimbotKey(args)
	if (not args or #args == 0) then return end

	local key = string.upper(tostring(args[1]))

	local selected_key = E_ButtonCode["KEY_" .. key]
	if (not selected_key) then print("Invalid key!") return end

	settings.key = selected_key
end

local function cmd_ChangeAimbotFov(args)
	if (not args or #args == 0 or not args[1]) then return end
	settings.fov = tonumber(args[1])
end

local function cmd_ChangeAimbotIgnore(args)
	if (not args or #args == 0) then return end
	if (not args[1] or not args[2]) then return end

	local option = tostring(args[1])
	local ignoring = settings.ignore[option] and "aiming for" or "ignoring"

	settings.ignore[option] = not settings.ignore[option]

	printc(150, 255, 150, 255, "Aimbot is now " .. ignoring .. " " .. option)
end

local function cmd_ToggleAimLock()
	settings.lock_aim = not settings.lock_aim
	printc(150, 255, 150, 255, "Aim lock is now " .. (settings.lock_aim and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("aimbot->change_mode", "Change aimbot mode | args: mode (plain, smooth or silent)", 1, cmd_ChangeAimbotMode)
GB_GLOBALS.RegisterCommand("aimbot->change_key", "Changes aimbot key | args: key (w, f, g, ...)", 1, cmd_ChangeAimbotKey)
GB_GLOBALS.RegisterCommand("aimbot->change_fov", "Changes aimbot fov | args: fov (number)", 1, cmd_ChangeAimbotFov)
GB_GLOBALS.RegisterCommand("aimbot->ignore->toggle", "Toggles a aimbot ignore option | args: option name (string)", 1, cmd_ChangeAimbotIgnore)
GB_GLOBALS.RegisterCommand("aimbot->aimlock_toggle", "Makes the aimbot not stop looking at the targe when shooting", 0, cmd_ToggleAimLock)

local aimbot = {}
aimbot.CreateMove = CreateMove
aimbot.FrameStageNotify = FrameStageNotify
aimbot.Draw = Draw

return aimbot

end)
__bundle_register("src.hitboxes", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
Hitboxes i'll use:
Head, center, left leg, right leg, left arm, right arm
im fucked
--]]

local CLASS_HITBOXES = {
	--[[scout]]
	[1] = {
		--[[Head =]]
		6,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[soldier]]
	[3] = {
		--[[HeadUpper =]]
		6, -- 32,
		--[[Head =]]
		32, -- 6,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[[pyro]]
	[7] = {
		--[[Head =]]
		6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		16,
		--[[RightLeg =]]
		20,
		--[[LeftArm =]]
		9,
		--[[RightArm =]]
		13,
	},

	--[[demoman]]
	[4] = {
		--[[Head =]]
		16,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		10,
		--[[RightLeg =]]
		12,
		--[[LeftArm =]]
		13,
		--[[RightArm =]]
		14,
	},

	--[[heavy]]
	[6] = {
		--[[Head =]]
		6,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[engi]]
	[9] = {
		--[[HeadUpper =]]
		8, --61,
		--[[Head =]]
		61, --8,
		--[[Body =]]
		4,
		--[[LeftLeg =]]
		10,
		--[[RightLeg =]]
		2,
		--[[LeftArm =]]
		13,
		--[[RightArm =]]
		16,
	},

	--[[medic]]
	[5] = {
		--[[HeadUpper =]]
		6, --33,
		--[[Head =]]
		33, --6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[sniper]]
	[2] = {
		--[[HeadUpper =]]
		6, --23,
		--[[Head =]]
		23, --6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[spy]]
	[8] = {
		--[[Head =]]
		6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		18,
		--[[RightLeg =]]
		19,
		--[[LeftArm =]]
		12,
		--[[RightArm =]]
		13,
	},
}

return CLASS_HITBOXES

end)
__bundle_register("src.anticheat", function(require, _LOADED, __bundle_register, __bundle_modules)
local clc_RespondCvarValue = 13
local SIGNONSTATE_TYPE = 6
local m_bEnabled = true

---@param msg NetMessage
local function AntiCheat(msg)
	if (not m_bEnabled) then return true end
	if msg:GetType() == SIGNONSTATE_TYPE and clientstate:GetClientSignonState() == E_SignonState.SIGNONSTATE_NONE then
		GB_GLOBALS.m_bIsStacRunning = false
	end

	if msg:GetType() == clc_RespondCvarValue and not GB_GLOBALS.m_bIsStacRunning then
		GB_GLOBALS.m_bIsStacRunning = true
		printc(255, 200, 200, 255, "STAC/SMAC was detected! Some features are disabled")
		client.ChatPrintf("STAC/SMAC was detected! Some features are disabled")
	end

	return true
end

callbacks.Register("SendNetMsg", "NETMSG garlic bread stac detector", AntiCheat)

local function CMD_Toggle()
	m_bEnabled = not m_bEnabled
	if (not m_bEnabled) then GB_GLOBALS.m_bIsStacRunning = false end
	printc(255, 0, 0, 255, "STAC checker is " .. (m_bEnabled and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("anticheat->toggle_stac_check", "Toggles the stac checker, so we can gamble if the server has STAC :smile:", 0,  CMD_Toggle)
end)
__bundle_register("src.bitbuf", function(require, _LOADED, __bundle_register, __bundle_modules)
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: duplicate-doc-field
local NEW_COMMANDS_SIZE = 4
local BACKUP_COMMANDS_SIZE = 3
local MSG_SIZE = 6
local WORD_SIZE = 16

--local net_SetConVar = 5
local clc_Move = 9

NET_SetConVar = {}
CLC_Move = {}

---@class ConVar
---@field name string # size 260
---@field value string # size 260

---@param buffer BitBuffer
---@param convars ConVar[]
function NET_SetConVar:WriteToBitBuffer(buffer, convars)
	buffer:Reset()
	--buffer:WriteInt(net_SetConVar, MSG_SIZE) we currently dont need this

	local numvars = #convars
	buffer:WriteByte(numvars)

	for i = 1, numvars do
		local var = convars[i]
		buffer:WriteString(var.name)
		buffer:WriteString(var.value)
	end

	buffer:SetCurBit(MSG_SIZE)
end

---@param buffer BitBuffer
function NET_SetConVar:ReadFromBitBuffer(buffer)
	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE) --- skip first 6 useless bits of msg:GetType()
	local numvars = buffer:ReadByte()

	---@type ConVar[]
	local convars = {}

	for i = 1, numvars do
		convars[i] = { name = buffer:ReadString(260), value = buffer:ReadString(260) }
	end

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)
	return convars
end

---@param buffer BitBuffer
---@param new_commands integer
---@param backup_commands integer
function CLC_Move:WriteToBitBuffer(buffer, new_commands, backup_commands)
	buffer:Reset()

	-- im not sure if we need to add the message type, but just in case its there
	buffer:WriteInt(clc_Move, MSG_SIZE)
	local length = buffer:GetDataBitsLength()

	buffer:WriteInt(new_commands, NEW_COMMANDS_SIZE) --- m_nNewCommands
	buffer:WriteInt(backup_commands, BACKUP_COMMANDS_SIZE) --- m_nBackupCommands
	buffer:WriteInt(length, WORD_SIZE) --- m_nLength

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE) --- skip msg type
end

---@param buffer BitBuffer
function CLC_Move:ReadFromBitBuffer(buffer)
	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)

	local new_commands, backup_commands, length
	new_commands = buffer:ReadInt(NEW_COMMANDS_SIZE)
	backup_commands = buffer:ReadInt(BACKUP_COMMANDS_SIZE)
	length = buffer:ReadInt(WORD_SIZE)

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)
	return { new_commands = new_commands, backup_commands = backup_commands, length = length }
end

end)
__bundle_register("src.commands", function(require, _LOADED, __bundle_register, __bundle_modules)
local m_commands = {}
local m_prefix = "gb"

--[[
	gb command args
]]

--- If no additional param other than cmdname, the command has no args
---@param cmdname string
---@param help string
---@param num_args integer
---@param func function?
local function RegisterCommand(cmdname, help, num_args, func)
	m_commands[cmdname] = {func = func, help = help, num_args = num_args}
end

---@param cmd StringCmd
local function SendStringCmd(cmd)
	local sent_command = cmd:Get()
	local words = {}
	for word in string.gmatch(sent_command, "%S+") do
		words[#words + 1] = word
	end

	if (words[1] ~= m_prefix) then return end
	--- remove prefix
	table.remove(words, 1)

	if (m_commands[words[1]]) then
		local command = m_commands[words[1]]
		table.remove(words, 1)

		local func = command.func
		assert(type(func) == "function", "SendStringCmd -> command.func is not a function! wtf")

		local num_args = command.num_args
		assert(type(num_args) == "number", "SendStringCmd -> command.num_args is not a number! wtf")

		local args = {}
		for i = 1, num_args do
			local arg = tostring(words[i])
			args[i] = arg
		end

		func(args, num_args)

	else
		printc(171, 160, 2, 255, "Invalid option! Use 'gb help' if you want to know the correct name")
	end
	cmd:Set("")
end

local function print_help()
	printc(255, 150, 150, 255, "Stac is " .. (GB_GLOBALS.m_bIsStacRunning and "detected" or "not running") .. " in this server")
	printc(255, 255, 255, 255, "The commands are:")

	for name, props in pairs (m_commands) do
		local str = "%s : %s"
		printc(200, 200, 200, 200, string.format(str, name, props.help))
	end
end

RegisterCommand("help", "prints all command's description and usage", 0, print_help)

printc(255, 255, 255, 255, "You can use 'gb help' command to print all the console commands")

GB_GLOBALS.RegisterCommand = RegisterCommand
callbacks.Register("SendStringCmd", "SSC garlic bread console commands", SendStringCmd)
end)
__bundle_register("src.globals", function(require, _LOADED, __bundle_register, __bundle_modules)
GB_GLOBALS = {
	m_bIsStacRunning = false,

	m_bIsAimbotShooting = false,
	m_nAimbotTarget = nil,

	m_bWarping = false,
	m_bRecharging = false,

	m_flCustomFOV = 90,
	m_nPreAspectRatio = 0,
	m_nAspectRatio = 1.78,

	m_bNoRecoil = true,

	m_bBhopEnabled = false,
}
end)
return __bundle_require("__root")