---@class COLOR
---@field r integer
---@field g integer
---@field b integer
---@field a integer

local gb_settings = GB_SETTINGS
assert(gb_settings, "chams: GB_SETTINGS is nil!")

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

local COLORS = require("src.colors")

local chams = {}
local settings = gb_settings.chams

local render = render
local entities = entities
local string = string
local models = models

--- used for string.find
local TEAM_RED --[[, TEAM_BLU <const>]] = 2 --, 3
local SENTRY_CLASS, DISPENSER_CLASS, TELEPORTER_CLASS =
	 "CObjectSentrygun", "CObjectDispenser", "CObjectTeleporter"
local MVM_MONEY_CLASS = "CCurrencyPack"
local VIEWMODEL_ARM_CLASS = "CTFViewModel"
local VIEWMODEL_WEAPON_MODELNAME = "models/weapons/c_models"

function chams.unload()
	chams_materials = nil
	m_szMaterialMode = nil
	COLORS = nil
	chams = nil
	render = nil
	entities = nil
	string = nil
	models = nil
	TEAM_RED = nil
	MVM_MONEY_CLASS = nil
	VIEWMODEL_ARM_CLASS = nil
	SENTRY_CLASS, DISPENSER_CLASS, TELEPORTER_CLASS = nil, nil, nil
end

---@param r integer
---@param g integer
---@param b integer
---@param a integer
local function get_color(r, g, b, a)
	return r / 255, g / 255, b / 255, a / 255
end

---@type table<integer, COLOR>, table<integer, COLOR>
local entity_list_color_front, entity_list_color_back = {}, {}

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
		if (not settings.filter.localplayer and i == localindex) then goto continue end
		local class = entity:GetClass()
		local team = entity:GetTeamNumber()

		if (settings.enemy_only and team == localteam) then goto continue end
		if (settings.filter.players and entity:IsPlayer() and entity:IsAlive()) then
			if (entity:InCond(E_TFCOND.TFCond_Disguised) and settings.ignore_disguised_spy) then goto continue end

			entity_list_color_back[i] = COLORS.get_entity_color(entity)

			local moveChild = entity:GetMoveChild()
			while (moveChild) do
				entity_list_color_back[moveChild:GetIndex()] = COLORS.get_entity_color(moveChild)
				moveChild = moveChild:GetMovePeer()
			end
		else
			--- excluding ragdolls, they aren't alive >:)
			if (entity:GetHealth() >= 1) then
				if ((settings.filter.sentries and class == SENTRY_CLASS) or (settings.filter.dispensers and class == DISPENSER_CLASS)
						 or (settings.filter.teleporters and class == TELEPORTER_CLASS)) then
					entity_list_color_back[i] = COLORS.get_entity_color(entity)
					goto continue
				end

				if (settings.filter.MONEY and class == MVM_MONEY_CLASS) then
					entity_list_color_back[i] = COLORS.get_entity_color(entity)
					goto continue
				end
			end

			if (settings.filter.ragdolls and (class == "CTFRagdoll" or class == "CRagdollProp" or class == "CRagdollPropAttached")) then
				entity_list_color_back[i] = entity:GetPropInt("m_iTeam") == TEAM_RED and COLORS.RAGDOLL_RED or
					 COLORS.RAGDOLL_BLU
				goto continue
			end
		end
		::continue::
	end

	--- lol viewmodel is not in entity list
	if (settings.filter.viewmodel_arm) then
		local viewmodel = me:GetPropEntity("m_hViewModel[0]")
		if (viewmodel) then
			entity_list_color_back[viewmodel:GetIndex()] = COLORS.get_entity_color(viewmodel)
		end
	end

	--- lol ammo and healthpacks arent in entity list xd
	if (settings.filter.ammopack or settings.filter.healthpack) then
		local cbasenimating = entities.FindByClass("CBaseAnimating")
		for _, entity in pairs (cbasenimating) do
				--- medkit, ammopack
			local model = entity:GetModel()
			if (model) then
				local model_name = string.lower(models.GetModelName(model))
				if (model_name) then
					local i = entity:GetIndex()
					if (settings.filter.ammopack and string.find(model_name, "ammo")) then
						entity_list_color_back[i] = COLORS.AMMOPACK
					elseif (settings.filter.healthpack and (string.find(model_name, "health") or string.find(model_name, "medkit"))) then
						entity_list_color_back[i] = COLORS.HEALTHKIT
					end
				end
			end
		end
	end

	entity_list_color_front, entity_list_color_back = entity_list_color_back, entity_list_color_front
	collectgarbage("restart")
end

---@param usercmd UserCmd
function chams.CreateMove(usercmd)
  if (settings.enabled and (usercmd.tick_count % settings.update_interval) == 0) then
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
  if (not settings.enabled) then return end

	local material = chams_materials[m_szMaterialMode]
	if (not material) then return end

	local drawing_backtrack, drawing_antiaim = context:IsDrawingBackTrack(), context:IsDrawingAntiAim()
	if (drawing_antiaim or drawing_backtrack) then
		if ((drawing_antiaim and settings.filter.antiaim) or (drawing_backtrack and settings.filter.backtrack)) then
			local color = (drawing_antiaim and COLORS.ANTIAIM or COLORS.BACKTRACK)
			ChangeMaterialForIndicators(context, material, color)
		end
		return
	end

	local entity = context:GetEntity()

	if entity == nil and string.find(context:GetModelName(), VIEWMODEL_WEAPON_MODELNAME) then
		local pLocal = entities:GetLocalPlayer()
		if not pLocal then return end

		local hViewModel = pLocal:GetPropEntity("m_hViewModel[0]")
		if not hViewModel or not hViewModel:ShouldDraw() then return end

		local r, g, b, a = get_color(table.unpack(COLORS.VIEWMODEL_WEAPON))
		context:SetColorModulation(r, g, b)
		context:SetAlphaModulation(a)
		context:ForcedMaterialOverride(material)
	end

	if not entity then return end

	local index = entity:GetIndex()
	local class = entity:GetClass()
	if (not index or not class) then return end
	if (not entity_list_color_front[index]) then return end

	local color = entity_list_color_front[index]
	if (not color) then return end

	if ((settings.original_player_mat and class == "CTFPlayer")
			 or (class == VIEWMODEL_ARM_CLASS and settings.original_viewmodel_mat)) then
		--- draw the original material
    if (class == VIEWMODEL_ARM_CLASS) then
      local r, g, b, a = get_color(table.unpack(COLORS.ORIGINAL_VIEWMODEL))
      context:SetColorModulation(r, g, b)
      context:SetAlphaModulation(a)
    elseif (class == "CTFPlayer") then

		if entity:InCond(E_TFCOND.TFCond_Cloaked) and settings.ignore_cloaked_spy then
			return
		end

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

	if (not settings.visible_only) then
		context:DepthRange(0, (class == VIEWMODEL_ARM_CLASS and 0.1 or 0.2))
	end

	context:Execute()

	--- resetting stuff
	-- why no leak? wtf
	--context:SetColorModulation(get_color(255, 255, 255, 255))
	--context:SetAlphaModulation(1)
	DEPTHOVERRIDE(false)
	context:DepthRange(0, 1)
end

local function CMD_ToggleChams()
  settings.enabled = not settings.enabled
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
  settings.visible_only = not settings.visible_only
  printc(150, 255, 150, 255, "Chams will draw on " .. (settings.visible_only and "visible" or "invisible") .. " entities")
end

local function CMD_ToggleDrawOriginalPlayerMat()
	settings.original_player_mat = not settings.original_player_mat
  printc(150, 255, 150, 255, "Chams will " .. (settings.original_player_mat and "draw" or "not draw") .. " the original player material")
end

local function CMD_ToggleDrawOriginalViewmodelMat()
  settings.original_viewmodel_mat = not settings.original_viewmodel_mat
  printc(150, 255, 150, 255, "Chams will " .. (settings.original_viewmodel_mat and "draw" or "not draw") .. " the original viewmodel material")
end

local function CMD_ToggleDrawOnEnemyOnly()
  settings.enemy_only = not settings.enemy_only
  printc(150, 255, 150, 255, "Chams will " .. (settings.enemy_only and "draw only" or "not only draw") .. " the enemies")
end

local function CMD_SetUpdateInterval(args, num_args)
  if (not args or #args ~= num_args) then return end
  local new_value = tonumber(args[1])
  if (new_value <= 0) then printc(255, 0, 0, 255, "The new value must be at least 1!") return end

  settings.update_interval = new_value

  if (new_value < 3) then
    printc(252, 186, 3, 255, "Values below 3 are not worth it, I would recommend using 3 or more", "This is just a warning, the interval was still changed")
  end
end

local function CMD_TryToFixMaterials()
	chams_materials = {
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
end

GB_GLOBALS.RegisterCommand("chams->toggle", "Toggles chams", 0, CMD_ToggleChams)
GB_GLOBALS.RegisterCommand("chams->material", "Changes chams material | args: material mode (flat or textured)", 1, CMD_ChangeMaterialMode)
GB_GLOBALS.RegisterCommand("chams->change_color", "Changes the selected color on chams | args: color (string), r, g, b, a (numbers) | example: chams->change_color viewmodel_arm 150 255 150 255", 5, CMD_ChangeColor)
GB_GLOBALS.RegisterCommand("chams->toggle->visible_only", "Makes chams only draw on visible entities", 0, CMD_ToggleVisibleOnly)
GB_GLOBALS.RegisterCommand("chams->toggle->original_player_mat", "Toggles chams drawing the original player material", 0, CMD_ToggleDrawOriginalPlayerMat)
GB_GLOBALS.RegisterCommand("chams->toggle->enemy_only", "Toggles chams drawing on only enemies or not", 0, CMD_ToggleDrawOnEnemyOnly)
GB_GLOBALS.RegisterCommand("chams->toggle->original_viewmodel_mat", "Toggles chams drawing the original viewmodel material", 0, CMD_ToggleDrawOriginalViewmodelMat)
GB_GLOBALS.RegisterCommand("chams->update_interval", "Changes the entity update interval | args new value (number)", 1, CMD_SetUpdateInterval)
GB_GLOBALS.RegisterCommand("chams->fix_materials", "Tries to fix materials by creating them again", 0, CMD_TryToFixMaterials)
return chams
