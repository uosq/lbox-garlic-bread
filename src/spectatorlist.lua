local feature = {}
local m_enabled = true
local m_starty = 0.3 -- (percentage from center screen height)

---@type table<integer, {name: string, mode: boolean}>
local m_players = {}
local m_font = draw.CreateFont("TF2 BUILD", 16, 1000)
local m_unformattedstr = "%s is spectating you"

local OBS_MODE = {
	MODE_NONE= 0,	-- not spectating
	MODE_DEATHCAM = 2,	-- death cam animation
	MODE_FREEZECAM = 2,	-- that freeze frame when ded
	MODE_FIXED = 2,		-- viewing on a fixed cam pos
	MODE_IN_EYE = 2,	-- spectating in first person
	MODE_CHASE = 2,		-- spectating in third person
	MODE_POI = 2,		-- passtime point of interest, idk never played that
	MODE_ROAMING = 2,	-- they are free roaming some more
}

---@param stage E_ClientFrameStage
local function FrameStageNotify(stage)
   if not m_enabled then return end
   if not stage == E_ClientFrameStage.FRAME_NET_UPDATE_END then return end

   local localplayer = entities:GetLocalPlayer()
   if not localplayer then return end
   local localindex = localplayer:GetIndex()

   local being_spectated = false
   local players_spectating = {}

   local players = entities.FindByClass("CTFPlayer")

   for _, entity in pairs (players) do
      if entity:GetIndex() ~= localindex and not entity:IsDormant() and entity and entity:IsPlayer() and entity:IsValid() and not entity:IsAlive() then
         local mode = entity:GetPropInt("m_iObserverMode")
         local target = entity:GetPropEntity("m_hObserverTarget")

         if target and target:IsValid() and target:GetIndex() == localindex then
            being_spectated = true
            local name = entity:GetName()
            local in_firstperson = mode == OBS_MODE.MODE_IN_EYE

            players_spectating[#players_spectating+1] = {name = name, mode = in_firstperson}
         end
      end
   end

   GB_GLOBALS.bSpectated = being_spectated
   m_players = players_spectating
end

local function Draw()
   if not m_enabled then return end
   if not GB_GLOBALS.bSpectated then return end
   if not m_players then return end
   if engine:IsGameUIVisible() or engine:Con_IsVisible() then return end

   local width, height = draw.GetScreenSize()
   local centerx, centery = math.floor(width * 0.5), math.floor(height * 0.5)
   local y = math.floor(centery * m_starty)
   local gap = 2 --- pixels

   for _, player in pairs (m_players) do
      local name = player.name
      local mode = player.mode
      local str = string.format(m_unformattedstr, name)

      draw.SetFont(m_font)
      local textw, texth = draw.GetTextSize(str)
      local x = math.floor( centerx - math.floor(textw * 0.5) )
      local color = not mode and {255, 255, 255, 255} or {255, 100, 100, 255}

      draw.Color(table.unpack(color))
      draw.SetFont(m_font)
      draw.TextShadow(x, y, str)

      y = y + texth + gap
   end
end

feature.FrameStageNotify = FrameStageNotify
feature.Draw = Draw

local function CMD_ToggleSpecList()
   m_enabled = not m_enabled
   printc(150, 255, 150, 255, "Spectator list is now " .. (m_enabled and "enabled" or "disabled"))
end

local function CMD_SetStartY(args, num_args)
   if not args or not #args == num_args then return end
   local newy = tonumber(args[1])
   if newy then
      m_starty = newy
      printc(150, 150, 255, 255, "Spectator list y is changed")
   end
end

GB_GLOBALS.RegisterCommand("spectators->toggle", "Toggles the spectator list", 0, CMD_ToggleSpecList)
GB_GLOBALS.RegisterCommand("spectators->sety", "Changes the starting Y position (percentage) of your screen, args: new y (number 0 to 1)", 1, CMD_SetStartY)

feature.unload = function()
   feature = nil
   m_enabled = nil
   m_starty = nil
   m_players = nil
   m_font = nil
   m_unformattedstr = nil
   OBS_MODE = nil
end

return feature