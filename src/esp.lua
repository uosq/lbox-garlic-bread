local esp = {}

local m_enabled = true
local font = draw.CreateFont("TF2 BUILD", 12, 1000)

local mrad = math.rad
local mcos = math.cos
local msin = math.sin
local dline = draw.Line

local utils = require("src.esputils")
local colors = require("src.colors")

local settings = GB_SETTINGS.esp

local classes = {
   [1] = "scout",
   [3] = "soldier",
   [7] = "pyro",
   [4] = "demo",
   [6] = "heavy",
   [9] = "engineer",
   [5] = "medic",
   [2] = "sniper",
   [8] = "spy",
}

---@param topleft Vector3
---@param topright Vector3
---@param bottomleft Vector3
---@param bottomright Vector3
local function DrawBox(topleft, topright, bottomleft, bottomright)
   local top1, top2 = utils.GetScreenPosition(topleft), utils.GetScreenPosition(topright)
	local bottom1, bottom2 = utils.GetScreenPosition(bottomleft), utils.GetScreenPosition(bottomright)
	if top1 and top2 then
		dline(top1.x, top1.y, top2.x, top2.y)
	end
	if top1 and bottom1 then
		dline(top1.x, top1.y, bottom1.x, bottom1.y)
	end
	if top2 and bottom2 then
		dline(top2.x, top2.y, bottom2.x, bottom2.y)
	end
	if bottom1 and bottom2 then
		dline(bottom1.x, bottom1.y, bottom2.x, bottom2.y)
	end
end

---@param top Vector3
local function DrawClass(top, class)
   local pos = utils.GetScreenPosition(top)
   if pos then
      draw.SetFont(font)
      local str = tostring(classes[class])
      local textw, texth = draw.GetTextSize(str)
      draw.TextShadow(math.floor(pos.x - textw/2), math.floor(pos.y - texth), str)
   end
end

local function GetHealthColor(currenthealth, maxhealth)
    local healthpercentage = currenthealth / maxhealth
    healthpercentage = math.max(0, math.min(1, healthpercentage))
    local red = 1 - healthpercentage
    local green = healthpercentage
    red = math.max(0, math.min(1, red))
    green = math.max(0, math.min(1, green))
    return math.floor(255 * red), math.floor(255 * green), 0
end

---@param bottom Vector3
---@param health integer
local function DrawHealth(bottom, health, maxhealth)
   local pos = utils.GetScreenPosition(bottom)
   if pos then
      draw.SetFont(font)
      local str = tostring(health)
      local textw, _ = draw.GetTextSize(str)
      local r, g, b, a = GetHealthColor(health, maxhealth)
      a = 255
      draw.Color(math.floor(r), math.floor(g), math.floor(b), a)
      draw.TextShadow(math.floor(pos.x - textw/2), math.floor(pos.y), str)
   end
end

function esp.Draw()
   if not m_enabled then return end
   if engine:IsGameUIVisible() or engine:Con_IsVisible() then return end

   local localplayer = entities:GetLocalPlayer()
   if not localplayer then return end

   local team = localplayer:GetTeamNumber()
   local eyeangles = localplayer:GetAbsOrigin() + localplayer:GetPropVector("m_vecViewOffset[0]")
   local viewangles = engine:GetViewAngles()
   local rightrad = mrad(viewangles.y + 90)
   local leftrad = mrad(viewangles.y - 90)

   local localindex = localplayer:GetIndex()
   local rightVector = Vector3(mcos(rightrad), msin(rightrad), 0)
   local leftVector = Vector3(mcos(leftrad), msin(leftrad), 0)

   for _, player in pairs (Players) do
      if player and player:IsValid() and player:IsAlive() and not player:IsDormant()
      and (localindex ~= player:GetIndex() or GB_GLOBALS.bThirdperson) then

         --- i dont like goto but nothing i can do here :/
         if settings.enemy_only and player:GetTeamNumber() == team then goto continue end
         if player:InCond(E_TFCOND.TFCond_Cloaked) and settings.hide_cloaked then goto continue end

         local origin, mins, maxs = player:GetAbsOrigin(), player:GetMins(), player:GetMaxs()
         local center = origin + ((maxs + mins) * 0.5)

         if settings.visible_only then
            local trace = engine.TraceLine(eyeangles, center, MASK_SHOT_HULL)
            if not trace or trace.entity ~= player or trace.fraction < GB_GLOBALS.flVisibleFraction then
               goto continue
            end
         end

			local topleft = utils.GetEntityTopLeft(center, mins, maxs, leftVector)
			local topright = utils.GetEntityTopRight(origin, mins, maxs, rightVector)
			local bottomright = utils.GetEntityBottomRight(origin, mins, rightVector)
			local bottomleft = utils.GetEntityBottomLeft(origin, mins, leftVector)
         local top = utils.GetEntityTop(origin, mins, maxs)
         local color = colors.get_entity_color(player)
         local class = player:GetPropInt("m_PlayerClass", "m_iClass")
         local health = player:GetHealth()
         local maxhealth = player:GetMaxHealth()
         local bottom = player:GetAbsOrigin()

         local r, g, b, _ = table.unpack(color or {255, 255, 255})
         local a = 255
         draw.Color(r, g, b, a)
         DrawBox(topleft, topright, bottomleft, bottomright)
         DrawClass(top, class)
         DrawHealth(bottom, health, maxhealth)
         ::continue::
      end
   end
end

function esp.unload()
   esp = nil
   m_enabled = nil
   font = nil
   mrad = nil
   mcos = nil
   msin = nil
   dline = nil
   utils = nil
   colors = nil
   classes = nil
end

local function CMD_ToggleESP()
   m_enabled = not m_enabled
   printc(150, 150, 255, 255, "ESP is now " .. (m_enabled and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("esp->toggle", "Toggles esp", 0, CMD_ToggleESP)
return esp