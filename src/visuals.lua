local visuals = {}

---@param setup ViewSetup
local function CustomFOV(setup)
	if GB_GLOBALS.m_hLocalPlayer then
		local fov = GB_GLOBALS.m_hLocalPlayer:InCond(E_TFCOND.TFCond_Zoomed) and 20 or GB_GLOBALS.m_flCustomFOV
		setup.fov = fov

		if GB_GLOBALS.m_bNoRecoil and GB_GLOBALS.m_hLocalPlayer:GetPropInt("m_nForceTauntCam") == 0 then
			local punchangle = GB_GLOBALS.m_hLocalPlayer:GetPropVector("m_vecPunchAngle")
			setup.angles = EulerAngles((setup.angles - punchangle):Unpack())
		end
	end
end

visuals.CustomFOV = CustomFOV

return visuals

--callbacks.Register("RenderView", "RV galic bread custom fov", CustomFOV)
