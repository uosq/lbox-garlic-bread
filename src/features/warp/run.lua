local warp = {}

local bIsWarping, bIsRecharging = false, false

---@param uCmd UserCmd
---@param state GB_State
---@param settings GB_Settings
function warp.CreateMove(uCmd, state, settings)
	bIsRecharging = input.IsButtonDown(settings.warp.m_iRechargeKey) and not state.shooting
	bIsWarping = input.IsButtonDown(settings.warp.m_iWarpKey) and state.stored_ticks > 0
end

---@param msg NetMessage
---@param state GB_State
function warp.SendNetMsg(msg, state) end

return warp
