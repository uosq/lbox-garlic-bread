local gb = GB_GLOBALS
assert(gb, "visuals.commands: GB_GLOBALS is nil!")

local gb_settings = GB_SETTINGS
local settings = gb_settings.visuals

local function cmd_ChangeFOV(args)
	if (not args or #args == 0 or not args[1]) then return end
	settings.custom_fov = tonumber(args[1])
end

local function cmd_ToggleThirdPerson()
	gb_settings.visuals.thirdperson.enabled = not gb_settings.visuals.thirdperson.enabled
	printc(150, 255, 150, 255, "Thirdperson is " .. (gb_settings.visuals.thirdperson.enabled and "enabled" or "disabled"))
end

local function cmd_SetThirdPersonOption(args, num_args)
	if not args or #args ~= num_args then return end
	print(args[1], args[2])
	local option = tostring(args[1])
	local value = tonumber(args[2])
	gb_settings.visuals.thirdperson.offset[option] = value
end

local function cmd_SetAspectRatio(args, num_args)
	if not args or #args ~= num_args then return end
	local newvalue = tonumber(args[1])
	if newvalue then
		settings.aspect_ratio = newvalue
		printc(150, 150, 255, 255, "Changed aspect ratio")
	end
end

local function cmd_ToggleNoRecoil()
	settings.norecoil = not settings.norecoil
	printc(150, 150, 255, 255, "No recoil is " .. (settings.norecoil and "enabled" or "disabled"))
end

gb.RegisterCommand("visuals->fov->set", "Changes fov | args: new fov (number)", 1, cmd_ChangeFOV)
gb.RegisterCommand("visuals->thirdperson->toggle", "Toggles third person", 0, cmd_ToggleThirdPerson)
gb.RegisterCommand("visuals->thirdperson->set", "Sets the thirdperson option | args: option name (up, right, forward), new value (number)", 2, cmd_SetThirdPersonOption)
gb.RegisterCommand("visuals->aspectratio->set", "Changes the aspect ratio | args: new value (number)", 1, cmd_SetAspectRatio)
gb.RegisterCommand("visuals->norecoil->toggle", "Toggles no recoil", 0, cmd_ToggleNoRecoil)
