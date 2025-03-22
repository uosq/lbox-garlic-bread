local thirdperson = {}
local settings = GB_SETTINGS.visuals

function thirdperson:RenderView(setup)
	if settings.thirdperson.enabled then
		local viewangles = engine:GetViewAngles()
		local forward, right, up = viewangles:Forward(), viewangles:Right(), viewangles:Up()
		setup.origin = setup.origin + (right * settings.thirdperson.offset.right)
		setup.origin = setup.origin + (forward * settings.thirdperson.offset.forward)
		setup.origin = setup.origin + (up * settings.thirdperson.offset.up)
	end
end

function thirdperson:FrameStageNotify(stage)
	local player = entities:GetLocalPlayer()
	if (not player) then return end
	if (stage == E_ClientFrameStage.FRAME_NET_UPDATE_START) then
		player:SetPropBool(settings.thirdperson.enabled, "m_nForceTauntCam")
	end
end

return thirdperson