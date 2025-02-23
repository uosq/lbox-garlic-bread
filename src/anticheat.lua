local clc_RespondCvarValue = 13
local SIGNONSTATE_TYPE = 6

---@param msg NetMessage
local function AntiCheat(msg)
	if msg:GetType() == SIGNONSTATE_TYPE and clientstate:GetClientSignonState() == E_SignonState.SIGNONSTATE_NONE then
		GB_GLOBALS.m_bIsStacRunning = false
	end

	if msg:GetType() == clc_RespondCvarValue and not GB_GLOBALS.m_bIsStacRunning then
		GB_GLOBALS.m_bIsStacRunning = true
		printc(255, 200, 200, 255, "STAC/SMAC was detected! Some features are disabled")
		client.ChatPrintf("STAC/SMAC was detected! Some features are disabled")
	end

	return true
end

callbacks.Register("SendNetMsg", "NETMSG garlic bread stac detector", AntiCheat)
