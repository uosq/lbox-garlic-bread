require("src.visuals.commands")

local visuals = {}
local custom_aspectratio = require("src.visuals.custom aspectratio")
local custom_fov = require("src.visuals.custom fov")
local norecoil = require("src.visuals.norecoil")
local thirdperson = require("src.visuals.thirdperson")

---@param setup ViewSetup
function visuals.RenderView(setup)
	local player = entities:GetLocalPlayer()
	if (not player) or not player:IsAlive() then return end

	GB_GLOBALS.nPreAspectRatio = setup.aspectRatio

	custom_aspectratio:RenderView(setup)
	custom_fov:RenderView(setup, player)
	norecoil:RenderView(setup, player)
	thirdperson:RenderView(setup)
end

function visuals.FrameStageNotify(stage)
	thirdperson:FrameStageNotify(stage)
end

function visuals.unload()
	visuals = nil
	custom_aspectratio = nil
	custom_fov = nil
	norecoil = nil
	thirdperson = nil
end

return visuals
