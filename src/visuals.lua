local visuals = {}
local last_pressed_button_tick = 0
local thirdperson_enabled = false

local thirdperson_options = {
	right = 0,
	up = 0,
	forward = 0
}

---@param setup ViewSetup
local function RenderView(setup)
	if not GB_GLOBALS then return end

	local player = entities:GetLocalPlayer()
	if (not player) then return end

	GB_GLOBALS.nPreAspectRatio = setup.aspectRatio
	setup.aspectRatio = GB_GLOBALS.nAspectRatio == 0 and setup.aspectRatio or GB_GLOBALS.nAspectRatio

	local fov = player:InCond(E_TFCOND.TFCond_Zoomed) and 20 or GB_GLOBALS.flCustomFOV
	if (fov) then
		setup.fov = fov
	end

	if GB_GLOBALS.bNoRecoil and player:GetPropInt("m_nForceTauntCam") == 0 then
		local punchangle = player:GetPropVector("m_vecPunchAngle")
		setup.angles = EulerAngles((setup.angles - punchangle):Unpack())
	end

	local viewangles = engine:GetViewAngles()
	local forward, right, up = viewangles:Forward(), viewangles:Right(), viewangles:Up()
	setup.origin = setup.origin + (right * thirdperson_options.right)
	setup.origin = setup.origin + (forward * thirdperson_options.forward)
	setup.origin = setup.origin + (up * thirdperson_options.up)
end

local function FrameStageNotify(stage)
	local player = entities:GetLocalPlayer()
	if (not player) then return end
	if (stage == E_ClientFrameStage.FRAME_NET_UPDATE_START) then
		player:SetPropBool(thirdperson_enabled, "m_nForceTauntCam")
	end
end

visuals.RenderView = RenderView
visuals.FrameStageNotify = FrameStageNotify

local function cmd_ChangeFOV(args)
	if (not args or #args == 0 or not args[1]) then return end
	GB_GLOBALS.flCustomFOV = tonumber(args[1])
end

local function cmd_ToggleThirdPerson()
	thirdperson_enabled = not thirdperson_enabled
	printc(150, 255, 150, 255, "Thirdperson is now " .. (thirdperson_enabled and "enabled" or "disabled"))
end

--- visuals->set_thirdperson up 200
local function cmd_SetThirdPersonOption(args, num_args)
	if not args or #args ~= num_args then return end
	local option = tostring(args[1])
	local value = tonumber(args[2])
	thirdperson_options[option] = value
end

GB_GLOBALS.RegisterCommand("visuals->fov->set", "Changes fov | args: new fov (number)", 1, cmd_ChangeFOV)
GB_GLOBALS.RegisterCommand("visuals->thirdperson->toggle", "Toggles third person", 0, cmd_ToggleThirdPerson)
GB_GLOBALS.RegisterCommand("visuals->thidperson->set", "Sets the thirdperson option | args: option name (up, right, forward), new value (number)", 2, cmd_SetThirdPersonOption)
return visuals
