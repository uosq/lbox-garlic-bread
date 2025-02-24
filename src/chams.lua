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
GB_GLOBALS.RegisterCommand("chams->change_color", "Changes the selected color on chams | args: color (string), r, g, b, a (numbers) | example: chams->change_color viewmodeel_arm 150 255 150 255", 5, CMD_ChangeColor)
GB_GLOBALS.RegisterCommand("chams->toggle_visible_only", "Makes chams only draw on visible entities", 0, CMD_ToggleVisibleOnly)
GB_GLOBALS.RegisterCommand("chams->toggle_original_player_mat", "Toggles chams drawing the original player material", 0, CMD_ToggleDrawOriginalPlayerMat)
GB_GLOBALS.RegisterCommand("chams->toggle_enemy_only", "Toggles chams drawing on only enemies or not", 0, CMD_ToggleDrawOnEnemyOnly)
GB_GLOBALS.RegisterCommand("chams->toggle_original_viewmodel_mat", "Toggles chams drawing the original viewmodel material", 0, CMD_ToggleDrawOriginalViewmodelMat)
GB_GLOBALS.RegisterCommand("chams->set_update_interval", "Changes the entity update interval | args new value (number)", 1, CMD_SetUpdateInterval)
return chams
