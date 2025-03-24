local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "aimbot: gb is nil!")
assert(gb_settings, "aimbot: GB_SETTINGS is nil!")

local triggerbot = {}
local settings = gb_settings.triggerbot

local DEMOMAN_CLASS = 4
local MAX_UPGRADE_LEVEL = 3

local special_classes = {
   engineer = 9,
   spy = 8
}

local player = {
   alive = false,
   team = 0,
   metal = 0,
   index = 0,
   class = 0,
   eyeangles = {0, 0, 0},

   weapon = {
      ammo = 0,
      canshoot = false,
      is_melee = false,
      is_hitscan = false,
      index = 0,
   }
}

local ResetTable

ResetTable = function(t)
   for key, value in pairs (t) do
      if type(value) == "table" then
         ResetTable(value)
      elseif type(value) == "number" then
         t[key] = 0
      elseif type(value) == "boolean" then
         t[key] = false
      end
   end
end

local function ResetPlayer()
   ResetTable(player)
end

local function IsBuilding(entity)
   local class = entity:GetClass()
   return class == "CObjectSentrygun" or class == "CObjectDispenser" or class == "CObjectTeleporter"
end

---@param usercmd UserCmd
---@param target Entity
local function AutoWrench(usercmd, target)
   if not target then return false end
   if settings.filter.autowrench and player.class == special_classes.engineer then
      if target and IsBuilding(target) and target:GetTeamNumber() == player.team then
         if player.metal > 0 and ((target:GetHealth() >= 1 and target:GetHealth() < target:GetMaxHealth())
         or (target:GetPropInt("m_iUpgradeLevel") < MAX_UPGRADE_LEVEL)) then
            gb.nAimbotTarget = target:GetIndex()
            gb.bIsAimbotShooting = true
            usercmd.buttons = usercmd.buttons | IN_ATTACK
         end
      end
   end
end

---@param usercmd UserCmd
local function AutoBackstab(usercmd)
   if settings.filter.autobackstab and player.class == special_classes.spy and player.weapon.canbackstab then
      usercmd.buttons = usercmd.buttons | IN_ATTACK
   end
end

---TODO: find a way to optimize this
---@param usercmd UserCmd
local function AutoSticky(usercmd)
   if not (player.class == DEMOMAN_CLASS) then return end

   local stickies = entities.FindByClass("CTFGrenadePipebombProjectile")
   for _, entity in pairs (Players) do
      if entity:IsDormant() or not entity:IsAlive() or not entity:IsValid() then goto skip_player end
      if entity:GetTeamNumber() == player.team then goto skip_player end
      if entity:GetIndex() == client:GetLocalPlayerIndex() then goto skip_player end
      if settings.options.sticky_ignore_cloaked_spies and entity:InCond(E_TFCOND.TFCond_Cloaked) then goto skip_player end
      if entity:InCond(E_TFCOND.TFCond_Ubercharged) then goto skip_player end

      for _, sticky in pairs (stickies) do
         if not sticky:IsValid() then goto continue end

         --- this is probably not a good idea
         --- but m_bIsLive is as useful as just shooting myself
         --- m_vecVelocity is inacurate
         --- we have no m_flSpawnTime netvar :D
         if sticky:EstimateAbsVelocity():Length() > 0 then goto continue end

         local owner = sticky:GetPropEntity("m_hThrower")
         if not owner or owner:GetIndex() ~= player.index then goto continue end

         local pos = sticky:GetAbsOrigin()
         local entitypos = entity:GetAbsOrigin()
         local vecdistance = pos - entitypos
         local distance = math.abs(vecdistance:Length())

         if distance <= settings.options.sticky_distance then
            usercmd.buttons = usercmd.buttons | IN_ATTACK2
            return
         end

         ::continue::
      end
      ::skip_player::
   end
end

---@param usercmd UserCmd
local function HitscanWeapon(usercmd)
   local viewangles = engine:GetViewAngles()
   local eyeangles = Vector3(table.unpack(player.eyeangles))
   local dest = eyeangles + (viewangles:Forward() * 8192)

   local trace = engine.TraceLine(eyeangles, dest, MASK_SHOT_HULL)
   if not trace or trace.fraction >= gb.flVisibleFraction then return false end

   local target = trace.entity
   if not target or target:GetHealth() <= 0 then return false end
   if target:GetTeamNumber() == player.team then return false end
   if target:InCond(E_TFCOND.TFCond_Cloaked) and gb_settings.aimbot.ignore.cloaked then return end

   local center = target:GetAbsOrigin() + ((target:GetMins() + target:GetMaxs()) * 0.5)

   local centerangle = gb.ToAngle(center - eyeangles) - usercmd.viewangles
   local centerfov = (math.sqrt((centerangle.x^2) + (centerangle.y^2)))
   if centerfov >= settings.fov then
      local head = center + Vector3(0, 0, target:GetMaxs().z / 2)
      local headangle, headfov
      headangle = gb.ToAngle(head - eyeangles) - usercmd.viewangles
      headfov = math.sqrt((headangle.x^2 + headangle.y^2))
      if headfov >= settings.fov then return false end
   end

   gb.nAimbotTarget = target:GetIndex()
   gb.bIsAimbotShooting = true
   usercmd.buttons = usercmd.buttons | IN_ATTACK
   return true
end

---@param usercmd UserCmd
function triggerbot.CreateMove(usercmd)
   if not settings.enabled then return end

   gb.nAimbotTarget = nil
   gb.bIsAimbotShooting = false

   if settings.key and not input.IsButtonDown(settings.key) then return end
   if not player.alive then return end
   local weapon = entities.GetByIndex(player.weapon.index)
   if not weapon then return end

   AutoSticky(usercmd)

   if player.weapon.is_hitscan and settings.filter.hitscan then
      HitscanWeapon(usercmd)
      return

   elseif player.weapon.is_melee then
      local trace = weapon:DoSwingTrace()
      if not trace then return end
      if trace.fraction < gb.flVisibleFraction or not trace.entity:IsValid() or trace.entity:GetHealth() <= 0 then return end
      local target = trace.entity

      if target:GetTeamNumber() == player.team then
         AutoWrench(usercmd, target)
      else
         AutoBackstab(usercmd)
         if not settings.filter.melee then return end
         gb.nAimbotTarget = target:GetIndex()
         gb.bIsAimbotShooting = true
         usercmd.buttons = usercmd.buttons | IN_ATTACK
      end
   end
end

function triggerbot.FrameStageNotify(stage)
   if not (stage == E_ClientFrameStage.FRAME_NET_UPDATE_END) then return end

   local localplayer = entities:GetLocalPlayer()
   if not localplayer then ResetPlayer() return end

   local weapon = localplayer:GetPropEntity("m_hActiveWeapon")
   if not weapon then ResetPlayer() return end

   player.index = localplayer:GetIndex()
   player.alive = localplayer:IsAlive()
   player.metal = localplayer:GetPropDataTableInt("m_iAmmo")[4]
   player.team = localplayer:GetTeamNumber()
   player.class = localplayer:GetPropInt("m_PlayerClass", "m_iClass")

   local eyeangles = localplayer:GetAbsOrigin() + localplayer:GetPropVector("localdata", "m_vecViewOffset[0]")
   player.eyeangles = {eyeangles:Unpack()}

   player.weapon.ammo = weapon:GetPropInt("LocalWeaponData", "m_iClip1")
   player.weapon.canshoot = gb.CanWeaponShoot()
   player.weapon.index = weapon:GetIndex()
   player.weapon.is_hitscan = weapon:GetWeaponProjectileType() == E_ProjectileType.TF_PROJECTILE_BULLET
   player.weapon.is_melee = weapon:IsMeleeWeapon()

   if weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_KNIFE then
      player.weapon.canbackstab = weapon:GetPropBool("m_bReadyToBackstab")
   end
end

return triggerbot