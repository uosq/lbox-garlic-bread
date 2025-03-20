--- just to be sure
filesystem.CreateDirectory("Garlic Bread")

require("src.welcome")
require("src.globals")
require("src.commands")
require("src.settings")
require("src.bitbuf")

--- make them run before tickshift so we dont return before it
require("src.anticheat")

local watermark = require("src.watermark")
local gui = require("src.gui")
local spoof = require("src.spoof_convars")
local spectators = require("src.spectatorlist")
local antiaim = require("src.antiaim")
local aimbot = require("src.aimbot")
local triggerbot = require("src.triggerbot")
local esp = require("src.esp")
local tickshift = require("src.tickshift")
local fakelag = require("src.fakelag")
local visuals = require("src.visuals")
local movement = require("src.movement")
local chams = require("src.chams")
local binds = require("src.binds")
local mats = require("src.custom materials")

require("src.convars")
require("src.background")

--- i just dont like having to deal with LSP bullshit
---@param msg NetMessage
local function SendNetMsg(msg)
	local returnval = {ret = true}
	spoof.SendNetMsg(msg, returnval)
	fakelag.SendNetMsg(msg, returnval)
	tickshift.SendNetMsg(msg, returnval)

	--- tables and objects (userdata?) are the only ones lua passes by reference and not by value!
	return returnval.ret
end
callbacks.Register("SendNetMsg", "NETMSG garlic bread", SendNetMsg)

callbacks.Register("Draw", "DRAW garlic bread", function()
	if engine:Con_IsVisible() or engine:IsGameUIVisible() then return end
	if engine:IsTakingScreenshot() then return end

	esp.Draw()
	aimbot.Draw()
	tickshift.Draw()
	antiaim.Draw()
	spectators.Draw()
	watermark.Draw()
end)

---@param setup ViewSetup
callbacks.Register("RenderView", "RV garlic bread", function(setup)
	if engine:IsTakingScreenshot() then return end
	visuals.RenderView(setup)
end)

callbacks.Register("FrameStageNotify", "FSN garlic bread", function(stage)
	hud.FrameStageNotify(stage)
	triggerbot.FrameSageNotify(stage)
	visuals.FrameStageNotify(stage)
	spectators.FrameStageNotify(stage)
end)

---@param context DrawModelContext
callbacks.Register("DrawModel", "DME garlic bread", function(context)
	if engine:IsTakingScreenshot() then return end
	fakelag.DrawModel(context)
	chams.DrawModel(context)
end)

callbacks.Register("DrawStaticProps", "DSP garlic bread", function(info)
	if engine:IsTakingScreenshot() then return end
	mats.DrawStaticProps(info)
end)

---@param event GameEvent
callbacks.Register("FireGameEvent", "GE garlic bread", function(event)
	binds.FireGameEvent(event)
end)

---@param usercmd UserCmd
callbacks.Register("CreateMove", "CM garlic bread", function(usercmd)
	if engine:IsChatOpen() then return end
	if engine:Con_IsVisible() or engine:IsGameUIVisible() then return end

	fakelag.CreateMove(usercmd)
	triggerbot.CreateMove(usercmd)
	aimbot.CreateMove(usercmd)
	tickshift.CreateMove(usercmd)
	antiaim.CreateMove(usercmd)
	movement.CreateMove(usercmd)
	chams.CreateMove()
	binds.CreateMove(usercmd)
end)

callbacks.Register("Unload", "UL garlic bread unload", function()
	callbacks.Unregister("SendNetMsg", "NETMSG garlic bread")
	callbacks.Unregister("Draw", "DRAW garlic bread")
	callbacks.Unregister("RenderView", "RV garlic bread")
	callbacks.Unregister("FrameStageNotify", "FSN garlic bread")
	callbacks.Unregister("DrawModel", "DME garlic bread")
	callbacks.Unregister("FireGameEvent", "GE garlic bread")
	callbacks.Unregister("CreateMove", "CM garlic bread")
	callbacks.Unregister("DrawStaticProps", "DSP garlic bread")

	antiaim.unload()
	spectators.unload()
	aimbot.unload()
	tickshift.unload()
	antiaim.unload()
	visuals.unload()
	movement.unload()
	chams.unload()
	binds.unload()
	esp.unload()
	fakelag.unload()
	gui.unload()
	spoof.unload()
	mats.unload()
	watermark.unload()
	GB_GLOBALS = nil
	collectgarbage("collect")
end)
