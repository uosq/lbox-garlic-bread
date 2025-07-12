local lag = {}

---@param uCmd UserCmd
---@param state GB_State
---@param settings GB_Settings
function lag.CreateMove(uCmd, state, settings)
	if not settings.fakelag.m_bEnabled then
		return
	end

	local pLocal = entities.GetLocalPlayer()
	if not pLocal or not pLocal:IsAlive() then
		return
	end

	local m_iGoal = settings.fakelag.m_iGoal

	--- not perfect, but works good enough
	if state.choked_cmds > 0 then
		pLocal:SetPropFloat(globals.CurTime() + 1, "m_flAnimTime")
	elseif not state.shooting then
		pLocal:SetPropFloat(globals.CurTime() - m_iGoal, "m_flAnimTime")
	end

	if not state.shooting and state.choked_cmds < m_iGoal then
		uCmd.sendpacket = false
	end

	state.stored_ticks = state.choked_cmds
end

function lag.Unload() end

return lag
