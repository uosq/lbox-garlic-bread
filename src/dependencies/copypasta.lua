local pasted = {}

--- Pasted from Lnx00's LnxLib
local function isNaN(x)
	return x ~= x
end

local M_RADPI = 180 / math.pi

-- Calculates the angle between two vectors
---@param source Vector3
---@param dest Vector3
---@return EulerAngles angles
function pasted.PositionAngles(source, dest)
	local delta = source - dest

	local pitch = math.atan(delta.z / delta:Length2D()) * M_RADPI
	local yaw = math.atan(delta.y / delta.x) * M_RADPI

	if delta.x >= 0 then
		yaw = yaw + 180
	end

	if isNaN(pitch) then
		pitch = 0
	end
	if isNaN(yaw) then
		yaw = 0
	end

	return EulerAngles(pitch, yaw, 0)
end

-- Calculates the FOV between two angles
---@param vFrom EulerAngles
---@param vTo EulerAngles
---@return number fov
function pasted.AngleFov(vFrom, vTo)
	local vSrc = vFrom:Forward()
	local vDst = vTo:Forward()

	local fov = math.deg(math.acos(vDst:Dot(vSrc) / vDst:LengthSqr()))
	if isNaN(fov) then
		fov = 0
	end

	return fov
end

return pasted
