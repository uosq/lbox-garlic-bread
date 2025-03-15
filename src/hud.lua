local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "hud: GB_GLOBALS is nil!")
assert(gb_settings, "hud: GB_SETTINGS is nil!")

local colors = require("src.colors")
local hud = {}
local font = draw.CreateFont("TF2 BUILD", 36, 1000)
local small_font = draw.CreateFont("TF2 BUILD", 28, 1000)

local screenw, screenh = draw.GetScreenSize()
local centerx, centery = math.floor(screenw * 0.5), math.floor(screenh * 0.5)

local screen_padding = 96

local health_framex, health_framey, health_framew, health_frameh
health_framew, health_frameh = 250, 100
health_framex, health_framey = screen_padding, math.floor(screenh * 0.85)

local ammo_framex, ammo_framey, ammo_framew, ammo_frameh
ammo_framew, ammo_frameh = 250, 100
ammo_framex, ammo_framey = screenw - ammo_framew - screen_padding, math.floor(screenh * 0.85)

local PostPropUpdate = E_ClientFrameStage.FRAME_NET_UPDATE_END
local red_team = 2

local localplayer = {
   m_health = 0,
   m_maxhealth = 0,
   m_clip1 = 0,
   m_clip2 = 0,
   m_metal = 0,
   m_team = 0,
   m_alive = false,
}

function hud.Draw()
   if not localplayer or not localplayer.m_alive then return end
   if engine:Con_IsVisible() or engine:IsGameUIVisible() then return end

   if not gb_settings.hud.enabled then
      local cl_drawhud = client.GetConVar("cl_drawhud")
      if cl_drawhud == 0 then
         client.SetConVar("cl_drawhud", "1")
      end
      return
   end

   --- disable tf2's hud (we dont need it :p)
   do
      local cl_drawhud = client.GetConVar("cl_drawhud")
      local cl_classmenuopen = client.GetConVar("_cl_classmenuopen")

      --- when changing classes we'll need to see the hud :(
      --- fix: implement class changer
      if cl_classmenuopen == 1 then
         client.SetConVar("cl_drawhud", "1")
      end

      if cl_drawhud == 1 and cl_classmenuopen == 0 then
         SpoofConVar("cl_drawhud", "1")
         client.SetConVar("cl_drawhud", "0")
      end
   end

   do --- health

      do --- health background health_frame
         draw.Color(40, 40, 40, 200)
         draw.FilledRect(health_framex, health_framey, health_framex + health_framew, health_framey + health_frameh)

         draw.Color(table.unpack(localplayer.m_team == red_team and colors.WARP_BAR_RED or colors.WARP_BAR_BLU))
         draw.FilledRectFade(health_framex, health_framey + (health_frameh * 0.96), health_framex + health_framew, health_framey + health_frameh, 255, 50, true)
      end

      local unformattedtext = "HP: %s / %s"
      local text = string.format(unformattedtext, localplayer.m_health, localplayer.m_maxhealth)

      draw.SetFont(font)
      local textw, texth = draw.GetTextSize(text)

      draw.SetFont(font)
      draw.Color(255, 255, 255, 255)
      draw.TextShadow(math.floor(health_framex + (health_framew * 0.5) - (textw*0.5)), math.floor(health_framey + (health_frameh * 0.5) - (texth * 0.5)), text)
   end

   do --- ammo
      do --- ammo background frame
         draw.Color(40, 40, 40, 200)
         draw.FilledRect(ammo_framex, ammo_framey, ammo_framex + ammo_framew, ammo_framey + ammo_frameh)
      end

      local text_gap = 5

      draw.SetFont(small_font)
      local clip2str = tostring(localplayer.m_clip2)
      local clip2w, clip2h = draw.GetTextSize(clip2str)

      local clip1str = tostring(localplayer.m_clip1)
      draw.SetFont(font)
      local clip1w, clip1h = draw.GetTextSize(clip1str)

      local clip1x = math.floor(ammo_framex + (ammo_framew * 0.5) - (clip1w*0.5) - (clip2w*0.5))
      local clip1y = ammo_framey + math.floor(ammo_frameh * 0.5  - (clip1h * 0.5))
      local clip2x, clip2y = math.floor(clip1x + clip1w + text_gap), clip1y

      --- clip 1
      draw.SetFont(font)
      draw.Color(255, 255, 255, 255)
      draw.TextShadow( clip1x, clip1y, clip1str )

      --- clip 2
      draw.SetFont(small_font)
      draw.Color(255, 255, 255, 255)
      draw.TextShadow( clip2x, clip2y, clip2str)
   end

   do --- crosshair
      local size = gb_settings.hud.crosshair_size
      local color = gb_settings.hud.crosshair_color
      local x1, y1, x2, y2

      --- horizontal line
      do --- left line
         x1 = centerx - size
         x2 = centerx
         y1, y2 = centery, centery
         draw.Color(table.unpack(color))
         draw.Line(x1, y1, x2, y2)
      end

      do --- right line
         x1, x2 = centerx, centerx + size
         draw.Color(table.unpack(color))
         draw.Line(x1, y1, x2, y2)
      end

      --- vertical line
      do --- top
         x1, x2 = centerx, centerx
         y1, y2 = centery - size, centery
         draw.Color(table.unpack(color))
         draw.Line(x1, y1, x2, y2)
      end

      do --- bottom
         y1, y2 = centery, centery + size
         draw.Color(table.unpack(color))
         draw.Line(x1, y1, x2, y2)
      end
   end
end

function hud.FrameStageNotify(stage)
   if stage == PostPropUpdate then
      local plocal = entities:GetLocalPlayer()
      if not plocal then localplayer.m_alive = false return end

      local pweapon = plocal:GetPropEntity("m_hActiveWeapon")
      if not pweapon then return end

      local is_primary = pweapon:GetLoadoutSlot() == E_LoadoutSlot.LOADOUT_POSITION_PRIMARY

      local ammo = plocal:GetPropDataTableInt("m_iAmmo")
      localplayer.m_health = plocal:GetHealth()
      localplayer.m_maxhealth = plocal:GetMaxHealth()
      localplayer.m_clip1 = pweapon:GetPropInt("LocalWeaponData", "m_iClip1")
      localplayer.m_clip2 = is_primary and ammo[2] or ammo[3]
      localplayer.m_metal = ammo[4]
      localplayer.m_alive = plocal:IsAlive()
      localplayer.m_team = plocal:GetTeamNumber()
   end
end

function hud.unload()
   UnSpoofConVar("cl_drawhud")
   client.SetConVar("cl_drawhud", "1")
   localplayer = nil
   font = nil
   hud = nil
end

local function CMD_ToggleHUD()
   gb_settings.hud.enabled = not gb_settings.hud.enabled
   printc(150, 150, 255, 255, "The experimental hud is now " .. (gb_settings.hud.enabled and "enabled" or "disabled"))
end

gb.RegisterCommand("hud->toggle", "Toggles garlic bread's hud", 0, CMD_ToggleHUD)

return hud