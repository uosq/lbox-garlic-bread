local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "visuals: GB_GLOBALS is nil!")
assert(gb_settings, "visuals: GB_SETTINGS is nil!")

local visuals = {}

local function calc_fov(fov, aspect_ratio)
	local halfanglerad = fov * (0.5 * math.pi / 180)
	local t = math.tan(halfanglerad) * (aspect_ratio / (4/3))
	local ret = (180 / math.pi) * math.atan(t)
	return ret * 2
end

---@param setup ViewSetup
local function RenderView(setup)
	local player = entities:GetLocalPlayer()
	if (not player) or not player:IsAlive() then return end

	gb.nPreAspectRatio = setup.aspectRatio
	setup.aspectRatio = gb.nAspectRatio == 0 and setup.aspectRatio or gb.nAspectRatio

	local fov = player:InCond(E_TFCOND.TFCond_Zoomed) and 20 or gb.flCustomFOV
	if fov then
		setup.fov = calc_fov(fov, setup.aspectRatio)
	end

	if gb.bNoRecoil and player:GetPropInt("m_nForceTauntCam") == 0 then
		local punchangle = player:GetPropVector("m_vecPunchAngle")
		setup.angles = EulerAngles((setup.angles - punchangle):Unpack())
	end

	if gb_settings.visuals.thirdperson.enabled then
		local viewangles = engine:GetViewAngles()
		local forward, right, up = viewangles:Forward(), viewangles:Right(), viewangles:Up()
		setup.origin = setup.origin + (right * gb_settings.visuals.thirdperson.offset.right)
		setup.origin = setup.origin + (forward * gb_settings.visuals.thirdperson.offset.forward)
		setup.origin = setup.origin + (up * gb_settings.visuals.thirdperson.offset.up)
	end
end

local function FrameStageNotify(stage)
	local player = entities:GetLocalPlayer()
	if (not player) then return end
	if (stage == E_ClientFrameStage.FRAME_NET_UPDATE_START) then
		player:SetPropBool(gb_settings.visuals.thirdperson.enabled, "m_nForceTauntCam")
		gb.bThirdperson = gb_settings.visuals.thirdperson.enabled
	end
end

local function cmd_ChangeFOV(args)
	if (not args or #args == 0 or not args[1]) then return end
	gb.flCustomFOV = tonumber(args[1])
end

local function cmd_ToggleThirdPerson()
	gb_settings.visuals.thirdperson.enabled = not gb_settings.visuals.thirdperson.enabled
	printc(150, 255, 150, 255, "Thirdperson is now " .. (gb_settings.visuals.thirdperson.enabled and "enabled" or "disabled"))
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
		gb.nAspectRatio = newvalue
		printc(150, 150, 255, 255, "Changed aspect ratio")
	end
end

function visuals.unload()
	visuals = nil
end

gb.RegisterCommand("visuals->fov->set", "Changes fov | args: new fov (number)", 1, cmd_ChangeFOV)
gb.RegisterCommand("visuals->thirdperson->toggle", "Toggles third person", 0, cmd_ToggleThirdPerson)
gb.RegisterCommand("visuals->thirdperson->set", "Sets the thirdperson option | args: option name (up, right, forward), new value (number)", 2, cmd_SetThirdPersonOption)
gb.RegisterCommand("visuals->aspectratio->set", "Changes the aspect ratio | args: new value (number)", 1, cmd_SetAspectRatio)

visuals.RenderView = RenderView
visuals.FrameStageNotify = FrameStageNotify
return visuals
