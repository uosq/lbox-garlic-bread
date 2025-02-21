local visuals = {}

---@param setup ViewSetup
local function CustomFOV(setup)
	if not GB_GLOBALS then
		return
	end

	GB_GLOBALS.m_nPreAspectRatio = setup.aspectRatio
	setup.aspectRatio = GB_GLOBALS.m_nAspectRatio == 0 and setup.aspectRatio or GB_GLOBALS.m_nAspectRatio

	--[[
  90 fov = 106.26020812988
  120 = x
  106.26020812988*120 = 90x
  (120.26020812988*120)/90 = x fov
  --]]

	if GB_GLOBALS.m_hLocalPlayer then
		local fov = GB_GLOBALS.m_hLocalPlayer:InCond(E_TFCOND.TFCond_Zoomed) and 20 or GB_GLOBALS.m_flCustomFOV
		local render_fov = (106.26020812988 * fov) / 90
		setup.fov = render_fov

		if GB_GLOBALS.m_bNoRecoil and GB_GLOBALS.m_hLocalPlayer:GetPropInt("m_nForceTauntCam") == 0 then
			local punchangle = GB_GLOBALS.m_hLocalPlayer:GetPropVector("m_vecPunchAngle")
			setup.angles = EulerAngles((setup.angles - punchangle):Unpack())
		end
	end
end

visuals.CustomFOV = CustomFOV

return visuals
