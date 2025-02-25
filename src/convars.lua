local function CMD_ChangeSwayScale(args, num_args)
   if (not args or #args ~= num_args) then return end
   local new_scale = tostring(args[1])
   if (not new_scale) then return end --- convert to a number and then check if its nil in case the user input something that isnt a number
   client.SetConVar("cl_wpn_sway_scale", new_scale)
end

local function CMD_ChangeSwayInterp(args, num_args)
   if (not args or #args ~= num_args) then return end
   local new_interp = tostring(args[1])
   if (not new_interp) then return end
   client.SetConVar("cl_wpn_sway_interp", new_interp)
end

GB_GLOBALS.RegisterCommand("convars->sway->scale", "Changes weapon sway scale", 1, CMD_ChangeSwayScale)
GB_GLOBALS.RegisterCommand("convars->sway->interp", "Changes weapon sway interp", 1, CMD_ChangeSwayInterp)