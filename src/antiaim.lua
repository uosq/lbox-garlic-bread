---@diagnostic disable:cast-local-type
local antiaim = {}

---@param usercmd UserCmd
function antiaim.CreateMove(usercmd)
	if
		not GB_GLOBALS.m_bIsAimbotShooting
		and GB_GLOBALS.m_bAntiAimEnabled
		and usercmd.buttons & IN_ATTACK == 0
		and not GB_GLOBALS.m_bIsStacRunning
		and not GB_GLOBALS.m_bWarping
		and not GB_GLOBALS.m_bRecharging
	then
		--- make sure we aren't overchoking
		if clientstate:GetChokedCommands() >= 21 then
			usercmd.sendpacket = true
			return
		end

		local view = engine:GetViewAngles()
		local m_realyaw = view.y + (GB_GLOBALS.anti_aim.real_yaw and GB_GLOBALS.m_flRealYaw or 0)
		local m_fakeyaw = view.y + (GB_GLOBALS.anti_aim.fake_yaw and GB_GLOBALS.m_flFakeYaw or 0)
		if usercmd.tick_count % 2 == 0 then
			usercmd:SetViewAngles(GB_GLOBALS.anti_aim.real_pitch and GB_GLOBALS.m_flRealPitch or view.x, m_realyaw, 0)
			usercmd.sendpacket = false
		else
			--view = view + Vector3(m_settings.pitch.fake, m_fakeyaw, 0)
			usercmd:SetViewAngles(GB_GLOBALS.anti_aim.fake_pitch and GB_GLOBALS.m_flFakePitch or view.x, m_fakeyaw, 0)
		end
	end
end

function antiaim.unload()
	antiaim = nil
end

return antiaim
