require("src.globals")
require("src.settings")
require("src.commands")
require("src.bitbuf")

--- make them run before tickshift so we dont return before it
require("src.anticheat")

local gui = require("src.gui")
local hud = require("src.hud")
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
	esp.Draw()
	aimbot.Draw()
	tickshift.Draw()
	antiaim.Draw()
	spectators.Draw()
	hud.Draw()
end)

---@param setup ViewSetup
callbacks.Register("RenderView", "RV garlic bread", function(setup)
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
	fakelag.DrawModel(context)
	chams.DrawModel(context)
end)

---@param event GameEvent
callbacks.Register("FireGameEvent", "GE garlic bread", function(event)
	binds.FireGameEvent(event)
end)

---@param usercmd UserCmd
callbacks.Register("CreateMove", "CM garlic bread", function(usercmd)
	fakelag.CreateMove(usercmd)
	triggerbot.CreateMove(usercmd)
	aimbot.CreateMove(usercmd)
	esp.CreateMove(usercmd)
	tickshift.CreateMove(usercmd)
	antiaim.CreateMove(usercmd)
	movement.CreateMove(usercmd)
	chams.CreateMove(usercmd)
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
	hud.unload()
	spoof.unload()
	GB_GLOBALS = nil
	collectgarbage("collect")
end)
