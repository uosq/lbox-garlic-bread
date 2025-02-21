local movement = {}

---@param usercmd UserCmd
local function CreateMove(usercmd)
	if GB_GLOBALS then
		local localplayer = entities:GetLocalPlayer()
		if not localplayer or not localplayer:IsAlive() then
			return
		end

		if GB_GLOBALS.m_bBhopEnabled then
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
end

movement.CreateMove = CreateMove

return movement
