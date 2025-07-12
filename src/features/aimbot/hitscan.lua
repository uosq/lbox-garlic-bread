local hitscan = {}

local PREFERRED_BONES = {4, 1, 10, 7}

---@param entity Entity
---@return table<integer, Vector3>
local function GetBones(entity)
	local model = entity:GetModel()
	local studioHdr = models.GetStudioModel(model)

	local myHitBoxSet = entity:GetPropInt("m_nHitboxSet")
	local hitboxSet = studioHdr:GetHitboxSet(myHitBoxSet)
	local hitboxes = hitboxSet:GetHitboxes()

	--boneMatrices is an array of 3x4 float matrices
	local boneMatrices = entity:SetupBones()

    local bones = {}

	for i = 1, #hitboxes do
		local hitbox = hitboxes[i]
		local bone = hitbox:GetBone()

		local boneMatrix = boneMatrices[bone]

		if boneMatrix == nil then
			goto continue
		end

		local bonePos = Vector3(boneMatrix[1][4], boneMatrix[2][4], boneMatrix[3][4])

        bones[i] = bonePos
		::continue::
	end

    return bones
end

---@param ent Entity
local function shouldHitEntity(ent)
	return false
end

---@param players table<integer, Entity>
---@param plocal Entity
---@param utils GB_Utils
---@param settings GB_Settings
---@param ent_utils GB_EntUtils
---@return PlayerInfo
local function GetClosestPlayerToFov(plocal, settings, utils, ent_utils, players)
	local info = {
		angle = nil,
		fov = settings.aimbot.fov,
		index = nil,
		center = nil,
	}

	local viewangle = engine:GetViewAngles()
	local shootpos = ent_utils.GetShootPosition(plocal)

	for _, player in pairs(players) do
		if not player:IsDormant() and player:IsAlive() and player:GetTeamNumber() ~= plocal:GetTeamNumber() then
            local bones = GetBones(player)
			for _, preferred_bone in ipairs (PREFERRED_BONES) do
                local bonePos = bones[preferred_bone]
                local trace = engine.TraceLine(shootpos, bonePos, MASK_SHOT_HULL, shouldHitEntity)

                if trace and trace.fraction >= 0.6 then
                    local angle = utils.math.PositionAngles(shootpos, bonePos)
                    local fov = utils.math.AngleFov(angle, viewangle)

                    if fov < info.fov then
                        info.fov, info.angle, info.index = fov, angle, player:GetIndex()
                        break --- found a suitable bone, no need to check the other ones
                    end
                end
            end
		end
	end

	return info
end

---@param settings GB_Settings
---@param utils GB_Utils
---@param cmd UserCmd
---@param plocal Entity
---@param wep_utils GB_WepUtils
---@param players table<integer, Entity>
---@return boolean, integer?
function hitscan.Run(settings, utils, wep_utils, ent_utils, plocal, cmd, players)
	if not settings.aimbot.enabled then
		return false, nil
	end

	if not input.IsButtonDown(settings.aimbot.key) then
		return false, nil
	end

	local target = GetClosestPlayerToFov(plocal, settings, utils, ent_utils, players)

	if not target or not target.angle or not target.fov or not target.index then
		return false, nil
	end

	if wep_utils.CanShoot() then
		local can_attack = (cmd.buttons & IN_ATTACK) ~= 0

		if not can_attack and settings.aimbot.autoshoot then
			can_attack = true
		end

		if can_attack then
			cmd.buttons = cmd.buttons | IN_ATTACK
			cmd:SetViewAngles(target.angle:Unpack())
			plocal:SetVAngles(Vector3(target.angle:Unpack())) -- does nothing, but in case they fix it in the future, its here already
			cmd.sendpacket = true
		end
	end

	return true, target.index
end

return hitscan