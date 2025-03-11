local visuals = {}
local thirdperson_enabled = false
local thirdperson_options = {right = 0, up = 0, forward = 0}

local function calc_fov(fov, aspect_ratio)
	local halfanglerad = fov * (0.5 * math.pi / 180)
	local t = math.tan(halfanglerad) * (aspect_ratio / (4/3))
	local ret = (180 / math.pi) * math.atan(t)
	return ret * 2
end

---@param setup ViewSetup
local function RenderView(setup)
	if not GB_GLOBALS then return end

	local player = entities:GetLocalPlayer()
	if (not player) then return end

	GB_GLOBALS.nPreAspectRatio = setup.aspectRatio
	setup.aspectRatio = GB_GLOBALS.nAspectRatio == 0 and setup.aspectRatio or GB_GLOBALS.nAspectRatio

	local fov = player:InCond(E_TFCOND.TFCond_Zoomed) and 20 or GB_GLOBALS.flCustomFOV
	if fov then
		setup.fov = calc_fov(fov, setup.aspectRatio)
	end

	if GB_GLOBALS.bNoRecoil and player:GetPropInt("m_nForceTauntCam") == 0 then
		local punchangle = player:GetPropVector("m_vecPunchAngle")
		setup.angles = EulerAngles((setup.angles - punchangle):Unpack())
	end

	do
		if thirdperson_enabled then
			local viewangles = engine:GetViewAngles()
			local forward, right, up = viewangles:Forward(), viewangles:Right(), viewangles:Up()
			setup.origin = setup.origin + (right * thirdperson_options.right)
			setup.origin = setup.origin + (forward * thirdperson_options.forward)
			setup.origin = setup.origin + (up * thirdperson_options.up)
		end
	end
end

local function FrameStageNotify(stage)
	local player = entities:GetLocalPlayer()
	if (not player) then return end
	if (stage == E_ClientFrameStage.FRAME_NET_UPDATE_START) then
		player:SetPropBool(thirdperson_enabled, "m_nForceTauntCam")
		GB_GLOBALS.bThirdperson = thirdperson_enabled
	end
end

local function cmd_ChangeFOV(args)
	if (not args or #args == 0 or not args[1]) then return end
	GB_GLOBALS.flCustomFOV = tonumber(args[1])
end

local function cmd_ToggleThirdPerson()
	thirdperson_enabled = not thirdperson_enabled
	printc(150, 255, 150, 255, "Thirdperson is now " .. (thirdperson_enabled and "enabled" or "disabled"))
end

local function cmd_SetThirdPersonOption(args, num_args)
	if not args or #args ~= num_args then return end
	print(args[1], args[2])
	local option = tostring(args[1])
	local value = tonumber(args[2])
	thirdperson_options[option] = value
end

local function cmd_SetAspectRatio(args, num_args)
	if not args or #args ~= num_args then return end
	local newvalue = tonumber(args[1])
	if newvalue then
		GB_GLOBALS.nAspectRatio = newvalue
		printc(150, 150, 255, 255, "Changed aspect ratio")
	end
end

function visuals.unload()
	visuals = nil
	thirdperson_enabled = nil
	thirdperson_options = nil
end

GB_GLOBALS.RegisterCommand("visuals->fov->set", "Changes fov | args: new fov (number)", 1, cmd_ChangeFOV)
GB_GLOBALS.RegisterCommand("visuals->thirdperson->toggle", "Toggles third person", 0, cmd_ToggleThirdPerson)
GB_GLOBALS.RegisterCommand("visuals->thirdperson->set", "Sets the thirdperson option | args: option name (up, right, forward), new value (number)", 2, cmd_SetThirdPersonOption)
GB_GLOBALS.RegisterCommand("visuals->aspectratio->set", "Changes the aspect ratio | args: new value (number)", 1, cmd_SetAspectRatio)

visuals.RenderView = RenderView
visuals.FrameStageNotify = FrameStageNotify
return visuals
