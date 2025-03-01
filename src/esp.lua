---@class EntityTable
---@field topleft Vector3
---@field topright Vector3
---@field bottomleft Vector3
---@field bottomright Vector3
---@field color integer[]?
---@field class integer
---@field top Vector3
---@field health integer
---@field maxhealth integer
---@field bottom Vector3
----@field entityIndex integer

local esp = {}

---@type EntityTable[]
local players = {}

local m_enabled = true
local font = draw.CreateFont("TF2 BUILD", 12, 1000)
local update_interval = 2 --- every 2 ticks its updated

local mrad = math.rad
local mcos = math.cos
local msin = math.sin
local dline = draw.Line

local utils = require("src.esputils")
local colors = require("src.colors")

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

---@param usercmd UserCmd
function esp.CreateMove(usercmd)
   if not m_enabled then return end
   if engine:IsGameUIVisible() or engine:Con_IsVisible() then return end
   if (usercmd.tick_count % update_interval) ~= 0 then return end

   local localplayer = entities:GetLocalPlayer()
   if not localplayer then return end

   local viewangles = engine:GetViewAngles()
   local rightrad = mrad(viewangles.y + 90)
   local leftrad = mrad(viewangles.y - 90)

   local localindex = localplayer:GetIndex()

   ---@type EntityTable[]
   local entitytable = {}

   for _, player in pairs (Players) do
      if player and player:IsValid() and player:IsAlive() and not player:IsDormant() and (localindex ~= player:GetIndex() or GB_GLOBALS.bThirdperson) then
         local origin, mins, maxs = player:GetAbsOrigin(), player:GetMins(), player:GetMaxs()
         local center = origin + ((maxs + mins) * 0.5)
         local rightVector = Vector3(mcos(rightrad), msin(rightrad), 0)
         local leftVector = Vector3(mcos(leftrad), msin(leftrad), 0)

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

         entitytable[#entitytable+1] =
         {
            topleft = topleft,
            topright = topright,
            bottomright = bottomright,
            bottomleft = bottomleft,
            top = top,
            color = color,
            class = class,
            health = health,
            maxhealth = maxhealth,
            bottom = bottom,
         }
      end
   end
   players = entitytable
end

function esp.Draw()
   if not m_enabled then return end
   if engine:IsGameUIVisible() or engine:Con_IsVisible() then return end
   for _, player in ipairs (players) do
      local r, g, b, _ = table.unpack(player.color or {255, 255, 255})
      local a = 255
      draw.Color(r, g, b, a)
      DrawBox(player.topleft, player.topright, player.bottomleft, player.bottomright)
      DrawClass(player.top, player.class)
      DrawHealth(player.bottom, player.health, player.maxhealth)
   end
end

function esp.unload()
   esp = nil
   players = nil
   m_enabled = nil
   font = nil
   update_interval = nil
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

local function CMD_SetUpdateInterval(args, num_args)
   if not args or #args ~= num_args then return end
   if not args[1] then return end
   local new_value = tonumber(args[1])
   update_interval = new_value > 0 and new_value or 2
   printc(150, 150, 255, 255, "Update interval was changed!")
end

GB_GLOBALS.RegisterCommand("esp->toggle", "Toggles esp", 0, CMD_ToggleESP)
GB_GLOBALS.RegisterCommand("esp->update_interval", "Changes the ESP's update interval | args: new value (string, default is 2)", 1, CMD_SetUpdateInterval)
return esp