---@class COLOR
---@field r integer
---@field g integer
---@field b integer
---@field a integer

local settings = GB_SETTINGS.chams
assert(GB_SETTINGS and settings, "chams: GB_SETTINGS is nil!")

---@type COLOR[]
local entitylist = {}
local chams = {}
local materialmode = "flat"
local player = {
	team = 0,
	index = 0,
	viewmodel_index = 0
}

local chams_materials =
{
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

local colors = require("src.colors")
local viewmodel_weapon_modelname = "models/weapons/c_models"
local entity_classes = {
	sentry = "CObjectSentrygun",
	teleporter = "CObjectTeleporter",
	dispenser = "CObjectDispenser",
	mvm_money = "CCurrencyPack",
	viewmodel_arm = "CTFViewModel",
}

local function get_color(t)
	local r, g, b, a = table.unpack(t)
	return r / 255, g / 255, b / 255, a / 255
end

local function update_entities()
	if (globals.TickCount() % settings.update_interval) > 0 then return end
	if player.alive == 0 then return end

	local new_entitylist = {}
	for _, entity in pairs(Players) do
		if not settings.filter.players then break end

		local index = entity:GetIndex()
		if entity:IsDormant() then goto continue end
		if not entity:IsAlive() then goto continue end
		if not settings.filter.localplayer and index == player.index then goto continue end
		if settings.enemy_only and player.team == entity:GetTeamNumber() then goto continue end
		if entity:InCond(E_TFCOND.TFCond_Cloaked) and settings.ignore_cloaked_spy then goto continue end
		if entity:InCond(E_TFCOND.TFCond_Disguised) and settings.ignore_disguised_spy then goto continue end

		new_entitylist[index] = colors.get_entity_color(entity)

		local child = entity:GetMoveChild()
		while child do
			new_entitylist[child:GetIndex()] = colors.get_entity_color(child)
			child = child:GetMovePeer()
		end
		::continue::
	end

	for _, entity in pairs(Sentries) do
		if not settings.filter.sentries then break end
		if entity:IsDormant() then goto continue end
		if settings.enemy_only and player.team == entity:GetTeamNumber() then goto continue end
		if entity:GetHealth() <= 0 then goto continue end

		new_entitylist[entity:GetIndex()] = colors.get_entity_color(entity)
		::continue::
	end

	for _, entity in pairs(Dispensers) do
		if not settings.filter.dispensers then break end
		if entity:IsDormant() then goto continue end
		if entity:GetHealth() <= 0 then goto continue end
		if settings.enemy_only and entity:GetTeamNumber() == player.team then goto continue end

		new_entitylist[entity:GetIndex()] = colors.get_entity_color(entity)
		::continue::
	end

	for _, entity in pairs(Teleporters) do
		if not settings.filter.teleporters then break end
		if entity:IsDormant() then goto continue end
		if settings.enemy_only and entity:GetTeamNumber() == player.team then goto continue end
		if entity:GetHealth() <= 0 then goto continue end

		new_entitylist[entity:GetIndex()] = colors.get_entity_color(entity)
		::continue::
	end

	for _, entity in pairs(entities.FindByClass("CTFRagdoll")) do
		if not settings.filter.ragdolls then break end
		if entity:IsDormant() then goto continue end
		if entity:GetHealth() <= 0 then goto continue end
		if settings.enemy_only and entity:GetTeamNumber() == player.team then goto continue end

		new_entitylist[entity:GetIndex()] = colors.get_entity_color(entity)
		::continue::
	end

	if (settings.filter.viewmodel_arm) then
		local viewmodel = entities:GetLocalPlayer():GetPropEntity("m_hViewModel[0]")
		if (viewmodel) then
			new_entitylist[viewmodel:GetIndex()] = colors.get_entity_color(viewmodel)
		end
	end

	if (settings.filter.ammopack or settings.filter.healthpack) then
		local cbasenimating = entities.FindByClass("CBaseAnimating")
		for _, entity in pairs(cbasenimating) do
			--- medkit, ammopack
			local model = entity:GetModel()
			if model then
				local model_name = string.lower(models.GetModelName(model))
				if model_name then
					local i = entity:GetIndex()
					if settings.filter.ammopack and string.find(model_name, "ammo") then
						new_entitylist[i] = colors.AMMOPACK
					elseif settings.filter.healthpack and (string.find(model_name, "health") or string.find(model_name, "medkit")) then
						new_entitylist[i] = colors.HEALTHKIT
					end
				end
			end
		end
	end

	entitylist = new_entitylist
end

---@param bool boolean
local function DEPTHOVERRIDE(bool)
	render.OverrideDepthEnable(bool, bool)
end

local function ResetPlayer()
	for k, v in pairs(player) do
		player[k] = 0
	end
end

function chams.CreateMove()
	local plocal = entities:GetLocalPlayer()
	if not plocal or not plocal:IsAlive() then
		ResetPlayer()
		return
	end

	player.alive = plocal:IsAlive() and 1 or 0
	player.index = plocal:GetIndex()
	player.team = plocal:GetTeamNumber()
	player.viewmodel_index = plocal:GetPropEntity("m_hViewModel[0]"):GetIndex()

	update_entities()
end

---@param dme DrawModelContext
---@param entity Entity?
---@param modelname string
function chams.DrawModel(dme, entity, modelname)
	if not settings.enabled then return end
	if player.alive == 0 then return end

	local material = chams_materials[materialmode]

	--- viewmodel weapon
	if entity == nil and string.find(modelname, viewmodel_weapon_modelname) then
		local r, g, b, a = get_color(colors.VIEWMODEL_WEAPON)
		dme:SetColorModulation(r, g, b)
		dme:SetAlphaModulation(a)
		dme:ForcedMaterialOverride(material)

		DEPTHOVERRIDE(true)
		dme:DepthRange(0, 0.1)
		dme:Execute()
		dme:DepthRange(0, 1)
		DEPTHOVERRIDE(false)
		return
	elseif entity and entity:GetClass() == "CTFViewModel" then
		local r, g, b, a = get_color(colors.VIEWMODEL_ARM)
		dme:SetColorModulation(r, g, b)
		dme:SetAlphaModulation(a)
		dme:ForcedMaterialOverride(material)

		DEPTHOVERRIDE(true)
		dme:DepthRange(0, 0.1)
		dme:Execute()
		dme:DepthRange(0, 1)
		DEPTHOVERRIDE(false)
		return
	end

	if not entity then return end

	local index, class = entity:GetIndex(), entity:GetClass()

	if (class == "CTFPlayer" and settings.original_player_mat)
		 or (class == entity_classes.viewmodel_arm and settings.original_viewmodel_mat)
	then
		dme:Execute()

		local removedtext = string.gsub(class, "CTF", "")
		local upperclass = string.upper(removedtext)
		local r, g, b, a = get_color(colors["ORIGINAL_" .. upperclass])

		dme:SetColorModulation(r, g, b)
		dme:SetAlphaModulation(a)
	end

	local color = entitylist[index]
	if not color then return end

	DEPTHOVERRIDE(true)
	local r, g, b, a = get_color(color)

	dme:SetAlphaModulation(a)
	dme:SetColorModulation(r, g, b)
	dme:ForcedMaterialOverride(material)

	if not settings.visible_only then
		dme:DepthRange(0, 0.2)
	end

	dme:Execute()
	dme:DepthRange(0, 1)
	DEPTHOVERRIDE(false)
end

function chams.unload()
	entitylist = nil
	chams = nil
	materialmode = nil
	player = nil
	chams_materials = nil
	colors = nil
	viewmodel_weapon_modelname = nil
	entity_classes = nil
end

local function CMD_ToggleChams()
	settings.enabled = not settings.enabled
end

local function CMD_ChangeMaterialMode(args)
	if (not args or #args == 0 or not args[1]) then return end

	local name = tostring(args[1])
	if (not name) then return end

	materialmode = name
end

local function CMD_ChangeColor(args, num_args)
	if (not args or #args == 0 or #args ~= num_args) then return end

	local selected_key = string.upper(table.remove(args, 1))

	local r, g, b, a = table.unpack(args)
	if (not (r or g or b or a)) then return end

	r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a)
	colors[selected_key] = { r, g, b, a }
end

local function CMD_ToggleVisibleOnly()
	settings.visible_only = not settings.visible_only
	printc(150, 255, 150, 255,
		"Chams will draw on " .. (settings.visible_only and "visible" or "invisible") .. " entities")
end

local function CMD_ToggleDrawOriginalPlayerMat()
	settings.original_player_mat = not settings.original_player_mat
	printc(150, 255, 150, 255,
		"Chams will " .. (settings.original_player_mat and "draw" or "not draw") .. " the original player material")
end

local function CMD_ToggleDrawOriginalViewmodelMat()
	settings.original_viewmodel_mat = not settings.original_viewmodel_mat
	printc(150, 255, 150, 255,
		"Chams will " .. (settings.original_viewmodel_mat and "draw" or "not draw") .. " the original viewmodel material")
end

local function CMD_ToggleDrawOnEnemyOnly()
	settings.enemy_only = not settings.enemy_only
	printc(150, 255, 150, 255, "Chams will " .. (settings.enemy_only and "draw only" or "not only draw") .. " the enemies")
end

local function CMD_SetUpdateInterval(args, num_args)
	if (not args or #args ~= num_args) then return end
	local new_value = tonumber(args[1])
	if (new_value <= 0) then
		printc(255, 0, 0, 255, "The new value must be at least 1!")
		return
	end

	settings.update_interval = new_value

	if (new_value < 3) then
		printc(252, 186, 3, 255, "Values below 3 are not worth it, I would recommend using 3 or more",
			"This is just a warning, the interval was still changed")
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
