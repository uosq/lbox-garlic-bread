local norecoil = {}
local settings = GB_SETTINGS.visuals

---@param setup ViewSetup
---@param player Entity
function norecoil:RenderView(setup, player)
	if settings.norecoil and player:GetPropInt("m_nForceTauntCam") == 0 and not player:InCond(E_TFCOND.TFCond_Taunting) then
		local punchangle = player:GetPropVector("m_vecPunchAngle")
		setup.angles = EulerAngles((setup.angles - punchangle):Unpack())
	end
end

return norecoil