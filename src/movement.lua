local movement = {}
local bhop_enabled = true

function movement.unload()
	movement = nil
	bhop_enabled = nil
end

---@param usercmd UserCmd
local function CreateMove(usercmd)
	local localplayer = entities:GetLocalPlayer()
	if (not localplayer or not localplayer:IsAlive()) then return end
	local flags = localplayer:GetPropInt("m_fFlags")
	local ground = (flags & FL_ONGROUND) ~= 0
	local class = localplayer:GetPropInt("m_PlayerClass", "m_iClass")
	if not GB_GLOBALS.bIsStacRunning and bhop_enabled and class ~= 1 then
		local jump = (usercmd.buttons & IN_JUMP) ~= 0
		if ground and jump then
			usercmd.buttons = usercmd.buttons | IN_JUMP
		elseif not ground and jump then
			usercmd.buttons = usercmd.buttons & ~IN_JUMP
		end
	end
end

local function cmd_ToggleBhop()
	bhop_enabled = not bhop_enabled
	printc(150, 255, 150, 255, "Bhop is now " .. (bhop_enabled and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("misc->toggle_bhop", "Toggles bunny hopping", 0, cmd_ToggleBhop)

movement.CreateMove = CreateMove
return movement
