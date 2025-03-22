local settings = GB_SETTINGS.visuals
local shots = {}
local hooks = {}

local max_shots = 5
local max_life = 5 * 66.67

---@param event GameEvent
function hooks:FireGameEvent(event)
   if not settings.see_hits.enabled then return end
   if not (event:GetName() == "player_hurt") then return end

   local victimID, attacker, crit
   victimID = event:GetInt("userid")
   attacker = event:GetInt("attacker")
   crit = event:GetInt("crit") == 1 and true or false

   local plocalinfo = client.GetPlayerInfo(client.GetLocalPlayerIndex())
   if not (plocalinfo.UserID == attacker) then return end

   local victim = entities.GetByUserID(victimID)
   if not victim then return end

   local pos = victim:GetAbsOrigin()
   local mins, maxs = victim:GetMins(), victim:GetMaxs()
   local center = pos + ((mins + maxs) * 0.5)

   shots[#shots+1] = {pos = center, time = globals.TickCount(), crit = crit}
end

function hooks:Draw()
   if not settings.see_hits.enabled then return end

   if #shots >= max_shots then
      table.remove(shots, 1)
   end

   for i = 1, #shots do
      local shot = shots[i]
      if not shot then goto continue end
      if (globals.TickCount() - shot.time) >= max_life then
         table.remove(shots, i)
         goto continue
      else

         local center = client.WorldToScreen(shot.pos)
         if not center then goto continue end

         local color = shot.crit and settings.see_hits.crit_color or settings.see_hits.non_crit_color

         draw.Color(table.unpack(color))
         draw.OutlinedCircle(center[1], center[2], 10, 63)
      end

      --- seriously wtf why do we have to do a jump like this?
      --- why not just do like Luau or C and have a "continue"???
      ::continue::
   end
end

return hooks