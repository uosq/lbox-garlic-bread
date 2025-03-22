local customfov = {}
local settings = GB_SETTINGS.visuals

local function calc_fov(fov, aspect_ratio)
	local halfanglerad = fov * (0.5 * math.pi / 180)
	local t = math.tan(halfanglerad) * (aspect_ratio / (4/3))
	local ret = (180 / math.pi) * math.atan(t)
	return ret * 2
end

---@param setup ViewSetup
---@param player Entity
function customfov:RenderView(setup, player)
	local fov = player:InCond(E_TFCOND.TFCond_Zoomed) and 20 or settings.custom_fov
	if fov then
		setup.fov = calc_fov(fov, setup.aspectRatio)
	end
end

return customfov