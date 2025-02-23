local movement = {}

---@param usercmd UserCmd
local function CreateMove(usercmd)
	local localplayer = entities:GetLocalPlayer()
	if (not localplayer or not localplayer:IsAlive()) then return end
	if GB_GLOBALS and GB_GLOBALS.m_bBhopEnabled then
		local flags = localplayer:GetPropInt("m_fFlags")
		local ground = flags & FL_ONGROUND == 1
		local jump = usercmd.buttons & IN_JUMP == 1
		if ground and jump then
			usercmd.buttons = usercmd.buttons | IN_JUMP
		elseif (not ground and jump) or (not ground and not jump) then
			usercmd.buttons = usercmd.buttons & ~IN_JUMP
		end
	end
end

movement.CreateMove = CreateMove

local function cmd_ToggleBhop()
	GB_GLOBALS.m_bBhopEnabled = not GB_GLOBALS.m_bBhopEnabled
	printc(150, 255, 150, 255, "Bhop is now " .. (GB_GLOBALS.m_bBhopEnabled and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("misc->toggle_bhop", "Toggles bunny hopping", 0, cmd_ToggleBhop)

return movement
