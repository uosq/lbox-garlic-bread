local visuals = {}

---@param setup ViewSetup
local function CustomFOV(setup)
	if not GB_GLOBALS then return end

	local player = entities:GetLocalPlayer()
	if (not player) then return end

	GB_GLOBALS.m_nPreAspectRatio = setup.aspectRatio
	setup.aspectRatio = GB_GLOBALS.m_nAspectRatio == 0 and setup.aspectRatio or GB_GLOBALS.m_nAspectRatio

	--[[
  90 fov = 106.26020812988
  120 = x
  106.26020812988*120 = 90x
  (120.26020812988*120)/90 = x fov
  --]]

		local fov = player:InCond(E_TFCOND.TFCond_Zoomed) and 20 or GB_GLOBALS.m_flCustomFOV
		local render_fov = (106.26020812988 * fov) / 90
		setup.fov = render_fov

		if GB_GLOBALS.m_bNoRecoil and player:GetPropInt("m_nForceTauntCam") == 0 then
			local punchangle = player:GetPropVector("m_vecPunchAngle")
			setup.angles = EulerAngles((setup.angles - punchangle):Unpack())
		end
end

visuals.CustomFOV = CustomFOV

local function cmd_ChangeFOV(args)
	if (not args or #args == 0 or not args[1]) then return end
	GB_GLOBALS.m_flCustomFOV = tonumber(args[1])
end

GB_GLOBALS.RegisterCommand("visuals->customfov", "Changes custom fov | args: new fov (number)", 1, cmd_ChangeFOV)

return visuals
