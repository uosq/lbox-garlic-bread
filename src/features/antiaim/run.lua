local aa = {}

---@param uCmd UserCmd
---@param settings GB_Settings
---@param state GB_State
function aa.CreateMove(uCmd, settings, state)
	if not settings.antiaim.m_bEnabled then
		return
	end

	--- if we are shooting this tick, do nothing and return
	if state.shooting then
		return
	end

	--- its false, it means that fake lag is on and is choking this tick
	--- send the real yaw just in case
	if uCmd.sendpacket == false then
		uCmd.viewangles = Vector3(uCmd.viewangles.x, uCmd.viewangles.y + settings.antiaim.m_flRealyaw, 0)
		return
	end

	local m_iFakeyaw, m_iRealyaw, m_iPitch, iYaw

	m_iFakeyaw = settings.antiaim.m_flFakeyaw
	m_iRealyaw = settings.antiaim.m_flRealyaw
	m_iPitch = settings.antiaim.m_flPitch

	iYaw = uCmd.viewangles.y

	--- real yaw
	if (uCmd.tick_count % 2) == 0 then
		uCmd.viewangles = Vector3(m_iPitch, iYaw + m_iRealyaw, 0)
		uCmd.sendpacket = false
	else --- fake yaw
		uCmd.viewangles = Vector3(m_iPitch, iYaw + m_iFakeyaw, 0)
	end
end

return aa
