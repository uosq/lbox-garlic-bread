local utils = {}
local mabs = math.abs

function utils.GetEntityTopLeft(center, mins, maxs, rightVector, offset)
    offset = offset or 0
    local left = center - (rightVector * mabs(mins.x))
    local adjusted = left + (rightVector * offset)
    return adjusted + Vector3(0, 0, maxs.z / 2)
end

---@param vec Vector3
---@return Vector3?
function utils.GetScreenPosition(vec)
    local screenPosition = client.WorldToScreen(vec)
    if not screenPosition then
        return nil
    end
    return Vector3(screenPosition[1], screenPosition[2])
end

function utils.GetEntityTopRight(origin, Mins, Maxs, leftVector, offset)
    offset = offset or 0
    local center = origin + ((Mins + Maxs) * 0.5)
    local right = center - (leftVector * mabs(Mins.x))
    local adjusted = right + (-leftVector * offset)
    return adjusted + Vector3(0, 0, Maxs.z / 2)
end

function utils.GetEntityBottomLeft(origin, Mins, rightVector, offset)
    offset = offset or 0
    local left = origin - (rightVector * mabs(Mins.x))
    local adjusted = left + (rightVector * offset)
    return adjusted + Vector3(0, 0, Mins.z / 2)
end

function utils.GetEntityBottomRight(origin, Mins, rightVector, offset)
    offset = offset or 0
    local right = origin - (rightVector * mabs(Mins.x))
    local adjusted = right + (rightVector * offset)
    return adjusted + Vector3(0, 0, Mins.z / 2)
end

function utils.GetEntityTop(origin, Mins, Maxs)
	local center = origin + ((Mins + Maxs) * 0.5)
	return center + Vector3(0, 0, Maxs.z / 2)
end

return utils