local clc_RespondCvarValue = 13
local SIGNONSTATE_TYPE = 6
local m_bEnabled = true

---@param msg NetMessage
local function AntiCheat(msg)
	if (not m_bEnabled) then return true end
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

local function CMD_Toggle()
	m_bEnabled = not m_bEnabled
	if (not m_bEnabled) then GB_GLOBALS.m_bIsStacRunning = false end
	printc(255, 0, 0, 255, "STAC checker is " .. (m_bEnabled and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("anticheat->toggle_stac_check", "Toggles the stac checker, so we can gamble if the server has STAC :smile:", 0,  CMD_Toggle)