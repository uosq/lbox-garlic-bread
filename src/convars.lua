local convars = {}

local viewmodel_override = true
local viewmodel_options = {right = 0, up = 0, forward = 0}
--- x forward, y right, z up

local function CMD_ChangeSwayScale(args, num_args)
   if (not args or #args ~= num_args) then return end
   local new_scale = tostring(args[1])
   if (not new_scale) then return end --- convert to a number and then check if its nil in case the user input something that isnt a number
   client.SetConVar("cl_wpn_sway_scale", new_scale)
   SpoofConVar("cl_wpn_sway_scale", new_scale)
end

local function CMD_ChangeSwayInterp(args, num_args)
   if (not args or #args ~= num_args) then return end
   local new_interp = tostring(args[1])
   if (not new_interp) then return end
   client.SetConVar("cl_wpn_sway_interp", new_interp)
   SpoofConVar("cl_wpn_sway_interp", new_interp)
end

local function CMD_ToggleVMOverride()
   viewmodel_override = not viewmodel_override
   if not viewmodel_override then
      client.SetConVar("tf_viewmodels_offset_override", "")
   end
   printc(150, 150, 255, 255, "ViewModel override is now " .. (viewmodel_override and "enabled" or "disabled"))
end

local function CMD_ChangeVMOptions(args, num_args)
   if not args or #args ~= num_args or not viewmodel_override then return end
   local option = tostring(args[1])
   local value = tonumber(args[2])
   if option and value then
      viewmodel_options[option] = value
      local newvalue = string.format("%s %s %s", viewmodel_options.forward, viewmodel_options.right, viewmodel_options.up)
      SpoofConVar("tf_viewmodels_offset_override", "")
      client.SetConVar("tf_viewmodels_offset_override", newvalue)
   end
end

GB_GLOBALS.RegisterCommand("convars->sway->scale", "Changes weapon sway scale", 1, CMD_ChangeSwayScale)
GB_GLOBALS.RegisterCommand("convars->sway->interp", "Changes weapon sway interp", 1, CMD_ChangeSwayInterp)
GB_GLOBALS.RegisterCommand("convars->toggle->vm_override", "Toggles the viewmodel override", 0, CMD_ToggleVMOverride)
GB_GLOBALS.RegisterCommand("convars->viewmodel->set", "Changes the viewmodel offset | args: option (up, right, forward), new value (number)", 2, CMD_ChangeVMOptions)
return convars