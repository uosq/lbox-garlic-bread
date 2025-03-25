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

local function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

--- i just dont like having to deal with LSP bullshit
---@param msg NetMessage
local function SendNetMsg(msg)
	local returnval = {ret = true}

	local buffer = BitBuffer()
	buffer:SetCurBit(0)

	local chokedcommands = clientstate:GetChokedCommands()
	local newcmds, backupcmds
	newcmds = 1 + chokedcommands
	newcmds = clamp(newcmds, 0, 15)

	local extracmds = chokedcommands + 1 - newcmds
	backupcmds = math.max(2, extracmds)
	backupcmds = clamp(backupcmds, 0, 7)

	buffer:WriteInt(newcmds, 4)
	buffer:WriteInt(backupcmds, 3)

	returnval.newcmds = newcmds
	returnval.backupcmds = backupcmds

	spoof.SendNetMsg(msg, returnval)
	fakelag.SendNetMsg(msg, buffer, returnval)
	tickshift.SendNetMsg(msg, buffer, returnval)

	--- tables and objects (userdata?) are the only ones lua passes by reference and not by value!
	return returnval.ret
end
callbacks.Register("SendNetMsg", "NETMSG garlic bread", SendNetMsg)

callbacks.Register("Draw", "DRAW garlic bread", function()
	if engine:Con_IsVisible() or engine:IsGameUIVisible() then return end
	if engine:IsTakingScreenshot() then return end

	aimbot.Draw()
	esp.Draw()
	tickshift.Draw()
	antiaim.Draw()
	spectators.Draw()
	watermark.Draw()
	visuals.Draw()
end)

---@param setup ViewSetup
callbacks.Register("RenderView", "RV garlic bread", function(setup)
	if engine:IsTakingScreenshot() then return end
	GB_GLOBALS.nPreAspectRatio = setup.aspectRatio
	visuals.RenderView(setup)
end)

callbacks.Register("FrameStageNotify", "FSN garlic bread", function(stage)
	triggerbot.FrameStageNotify(stage)
	visuals.FrameStageNotify(stage)
	spectators.FrameStageNotify(stage)
end)

---@param context DrawModelContext
callbacks.Register("DrawModel", "DME garlic bread", function(context)
	if engine:IsTakingScreenshot() then return end

	local entity = context:GetEntity()
	local modelname = context:GetModelName()

	fakelag.DrawModel(context, entity, modelname)
	chams.DrawModel(context, entity, modelname)
end)

callbacks.Register("DrawStaticProps", "DSP garlic bread", function(info)
	if engine:IsTakingScreenshot() then return end
	mats.DrawStaticProps(info)
end)

---@param event GameEvent
callbacks.Register("FireGameEvent", "GE garlic bread", function(event)
	binds.FireGameEvent(event)
	visuals.FireGameEvent(event)
end)

---@param usercmd UserCmd
callbacks.Register("CreateMove", "CM garlic bread", function(usercmd)
	if engine:IsChatOpen() then return end
	if engine:Con_IsVisible() or engine:IsGameUIVisible() then return end

	local player = entities:GetLocalPlayer()
	if not player then return end
	if not player:IsAlive() then return end

	local weapon = player:GetPropEntity("m_hActiveWeapon")

	triggerbot.CreateMove(usercmd)
	aimbot.CreateMove(usercmd, player, weapon)
	fakelag.CreateMove(usercmd)
	tickshift.CreateMove(usercmd, player)
	antiaim.CreateMove(usercmd)
	movement.CreateMove(usercmd, player)
	binds.CreateMove(usercmd)
	chams.CreateMove()
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
