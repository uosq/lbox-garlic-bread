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
   return r/255, g/255, b/255, a/255
end

local function update_entities()
   if (globals.TickCount() % settings.update_interval) > 0 then return end
	if player.alive == 0 then return end

   local new_entitylist = {}
   for _, entity in pairs (Players) do
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

   for _, entity in pairs (Sentries) do
      if not settings.filter.sentries then break end
      if entity:IsDormant() then goto continue end

      if entity:GetHealth() > 1 then
         if settings.enemy_only and entity:GetTeamNumber() == player.team then goto continue end
         new_entitylist[entity:GetIndex()] = colors.get_entity_color(entity)
      end
      ::continue::
   end

   for _, entity in pairs (Dispensers) do
      if not settings.filter.dispensers then break end
      if entity:IsDormant() then goto continue end

      if entity:GetHealth() > 1 then
         if settings.enemy_only and entity:GetTeamNumber() == player.team then goto continue end
         new_entitylist[entity:GetIndex()] = colors.get_entity_color(entity)
      end
      ::continue::
   end

   for _, entity in pairs (Teleporters) do
      if not settings.filter.teleporters then break end
      if entity:IsDormant() then goto continue end

      if entity:GetHealth() > 1 then
         if settings.enemy_only and entity:GetTeamNumber() == player.team then goto continue end
         new_entitylist[entity:GetIndex()] = colors.get_entity_color(entity)
      end
      ::continue::
   end

   for _, entity in pairs (entities.FindByClass("CTFRagdoll")) do
      if not settings.filter.ragdolls then break end
      if entity:IsDormant() then goto continue end
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
		for _, entity in pairs (cbasenimating) do
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
	for k, v in pairs (player) do
		player[k] = 0
	end
end

function chams.CreateMove()
	local plocal = entities:GetLocalPlayer()
	if not plocal or not plocal:IsAlive() then ResetPlayer() return end

	player.alive = plocal:IsAlive() and 1 or 0
	player.index = plocal:GetIndex()
	player.team = plocal:GetTeamNumber()
	player.viewmodel_index = plocal:GetPropEntity("m_hViewModel[0]"):GetIndex()

   update_entities()
end

---@param dme DrawModelContext
function chams.DrawModel(dme)
	if not settings.enabled then return end

	local material = chams_materials[materialmode]
	local entity = dme:GetEntity()

	if entity == nil and string.find(dme:GetModelName(), viewmodel_weapon_modelname) then
		local viewmodel = entities.GetByIndex(player.viewmodel_index)
		if not viewmodel or not viewmodel:ShouldDraw() then return end
		local r, g, b, a = get_color(colors.VIEWMODEL_WEAPON)
		dme:SetColorModulation(r, g, b)
		dme:SetAlphaModulation(a)
		dme:ForcedMaterialOverride(material)
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
		local r, g, b, a = get_color(colors["ORIGINAL_"..upperclass])

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
		dme:DepthRange(0, (class == entity_classes.viewmodel_arm and 0.1 or 0.2))
	end

	dme:Execute()

	DEPTHOVERRIDE(false)
	dme:DepthRange(0, 1)
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

return chams