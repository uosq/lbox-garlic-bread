---@class AimTable
---@field bestangle Vector3?
---@field bestfov number
---@field targetindex integer?

local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "hitscan.lua: gb_globals is nil!")

local hitscan = {}
local settings = gb_settings.aimbot

local helpers = require("src.aimbot.helpers")
local CLASS_BONES = require("src.hitboxes")

--- precomputed stuff
local rad45 = math.rad(45)
local TraceLine = engine.TraceLine
local sqrt = math.sqrt
--- 

---@param class Entity[]
---@param shoot_pos Vector3
---@param usercmd UserCmd
---@param punchangles Vector3
---@param aimtable AimTable
local function CheckClass(class, shoot_pos, usercmd, punchangles, aimtable)
   for _, entity in pairs(class) do
      local mins, maxs = entity:GetMins(), entity:GetMaxs()
      local center = entity:GetAbsOrigin() + ((mins + maxs) * 0.5)

      local trace = TraceLine(shoot_pos, center, MASK_SHOT_HULL)
      if trace and trace.entity == entity and trace.fraction >= gb.flVisibleFraction then
         local angle = gb.ToAngle(center - shoot_pos) - (usercmd.viewangles - punchangles)
         local fov = sqrt((angle.x ^ 2) + (angle.y ^ 2))

         if fov < aimtable.bestfov then
            aimtable.bestfov = fov
            aimtable.bestangle = angle
            aimtable.targetindex = entity:GetIndex() --- not saving the whole entity here, too much memory used!
         end
      end
   end
end

---@param should_aim_at_head boolean
---@param aimtable AimTable
local function CheckPlayers(usercmd, shoot_pos, m_team, punchangles, should_aim_at_head, aimtable)
   for _, entity in pairs(Players) do
		if not entity or entity:IsDormant() or not entity:IsAlive() or entity:GetTeamNumber() == m_team then
			goto continue
		end

		--- not the best way, probably using a single if statement would be better
		--- but i think its clearer what it does like this
		if entity:InCond(E_TFCOND.TFCond_Ubercharged) then
			goto continue
		elseif entity:InCond(E_TFCOND.TFCond_Cloaked) and gb_settings.aimbot.ignore.cloaked then
			goto continue
		elseif gb_settings.aimbot.ignore.bonked and entity:InCond(E_TFCOND.TFCond_Bonked) then
			goto continue
		elseif gb_settings.aimbot.ignore.deadringer and entity:InCond(E_TFCOND.TFCond_DeadRingered) then
			goto continue
		elseif gb_settings.aimbot.ignore.disguised and entity:InCond(E_TFCOND.TFCond_Disguised) then
			goto continue
		elseif gb_settings.aimbot.ignore.friends and playerlist.GetPriority(entity) == -1 then
			goto continue
		elseif gb_settings.aimbot.ignore.taunting and entity:InCond(E_TFCOND.TFCond_Taunting) then
			goto continue
		end

		local enemy_class = entity:GetPropInt("m_PlayerClass", "m_iClass")
		local best_bone_for_weapon = nil

		if should_aim_at_head == nil then
			goto continue
		elseif should_aim_at_head == true then
			best_bone_for_weapon = CLASS_BONES[enemy_class][1]
		elseif should_aim_at_head == false then
			best_bone_for_weapon = #CLASS_BONES[enemy_class] == 6 and CLASS_BONES[enemy_class][2]
				or CLASS_BONES[enemy_class][3] --- if size is 6 then we have no HeadUpper as the first value
		end

		local bones = entity:SetupBones()
		if not bones then
			goto continue
		end

		local bone_position = helpers:GetBoneOrigin(bones[best_bone_for_weapon])
		if not bone_position then
			goto continue
		end

		local trace = TraceLine(shoot_pos, bone_position, MASK_SHOT_HULL)
		if not trace then
			goto continue
		end

		local function do_aimbot_calc()
			local angle = gb.ToAngle(bone_position - shoot_pos) - (usercmd.viewangles - punchangles)
			local fov = sqrt((angle.x ^ 2) + (angle.y ^ 2))

			if fov < aimtable.bestfov then
				aimtable.bestfov = fov
				aimtable.bestangle = angle
				aimtable.targetindex = entity:GetIndex() --- not saving the whole entity here, too much memory used!
			end
		end

		if trace and trace.entity == entity and trace.fraction >= gb.flVisibleFraction then
			do_aimbot_calc()
		else
			local BONES = CLASS_BONES[enemy_class]
			for _, bone in ipairs(BONES) do
				--- already tried the best one
				if bone ~= best_bone_for_weapon then
					bone_position = helpers:GetBoneOrigin(bones[bone])
					if not bone_position then
						goto skip_bone
					end
					trace = TraceLine(shoot_pos, bone_position, MASK_SHOT_HULL)
					if not trace then
						goto skip_bone
					end
					if trace.entity == entity and trace.fraction >= gb.flVisibleFraction then
						do_aimbot_calc()
					end
				end
				::skip_bone::
			end
		end
		::continue::
	end
end

---@param usercmd UserCmd
---@param plocal Entity
function hitscan:CreateMove(usercmd, plocal)
   gb.bIsAimbotShooting = false
   gb.nAimbotTarget = nil

   if (gb.bSpectated and not settings.ignore.spectators)
   or not settings.enabled then
      return
   end

   if settings.key and not input.IsButtonDown(settings.key) then
		return
	end

   local team = plocal:GetTeamNumber()
   local weapon = plocal:GetPropEntity("m_hActiveWeapon")

   if settings.auto_spinup and weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_MINIGUN then
		usercmd.buttons = usercmd.buttons | IN_ATTACK2
	end

   local canshoot = gb.CanWeaponShoot() or gb.bDoubleTapping
   local is_stac = gb.bIsStacRunning

   local aim_mode = is_stac and gb.aimbot_modes.smooth or settings.mode
   local smoothvalue = is_stac and 20 or settings.smooth_value
   local aspectratio = (gb_settings.visuals.aspect_ratio == 0
   and gb.nPreAspectRatio
   or gb_settings.visuals.aspect_ratio)

   local fov = plocal:InCond(E_TFCOND.TFCond_Zoomed) and 20 or gb_settings.visuals.custom_fov
   local viewfov = helpers:calc_fov(fov, aspectratio)
   local aimfov = settings.fov * (math.tan(math.rad(viewfov / 2)) / math.tan(rad45))
   local shootpos = helpers:GetShootPosition(plocal)
   local punchangle = weapon:GetPropVector("m_vecPunchAngle") or Vector3()
   local aim_at_head = helpers:ShouldAimAtHead(plocal, weapon) and true or false

   ---@type AimTable
   local aimtable = {bestangle = nil, bestfov = aimfov, targetindex = nil}

   CheckClass(Dispensers, shootpos, usercmd, punchangle, aimtable)
   CheckClass(Teleporters, shootpos, usercmd, punchangle, aimtable)
   CheckPlayers(usercmd, shootpos, team, punchangle, aim_at_head, aimtable)
   CheckClass(Sentries, shootpos, usercmd, punchangle, aimtable)

   if not aimtable.bestangle or not aimtable.bestfov or not aimtable.targetindex then return end

   local viewangle = usercmd.viewangles
   local smoothval = vector.Multiply(aimtable.bestangle, smoothvalue * 0.01)

   if settings.humanized_smooth then
      smoothval.x = smoothval.x * engine.RandomFloat(0.8, 6)
      smoothval.y = smoothval.y * engine.RandomFloat(0.8, 6)
   end

   local smoothed = viewangle + smoothval
   local directangle = viewangle + aimtable.bestangle
   local distance = math.sqrt(aimtable.bestangle.x^2 + aimtable.bestangle.y^2)

   if aim_mode == gb.aimbot_modes.smooth or aim_mode == gb.aimbot_modes.assistance then
      if distance <= 1 then
         helpers:MakeWeaponShoot(usercmd, aimtable.targetindex)
      end

      --- early return if its assistance mode
      if aim_mode == gb.aimbot_modes.assistance then
         if usercmd.mousedx == 0 and usercmd.mousedy == 0 then
            return
         end
      end

      engine.SetViewAngles(EulerAngles(smoothed:Unpack()))
      usercmd.viewangles = smoothed

   else --- not smooth or assistance
      if not canshoot then return end

      if settings.autoshoot then
         helpers:MakeWeaponShoot(usercmd, aimtable.targetindex)
      end

      if (usercmd.buttons & IN_ATTACK) ~= 0 then
         usercmd.viewangles = directangle

         if aim_mode == gb.aimbot_modes.plain then
            engine.SetViewAngles(EulerAngles(directangle:Unpack()))
         end
      end
   end
end

return hitscan
