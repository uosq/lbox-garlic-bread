require("src.globals")
require("src.commands")
require("src.bitbuf")

--- make them run before tickshift so we dont return before it
require("src.anticheat")
require("src.convars")

local spoof = require("src.spoof_convars")
local aimbot = require("src.aimbot")
local tickshift = require("src.tickshift")
local antiaim = require("src.antiaim")
local visuals = require("src.visuals")
local movement = require("src.movement")
local chams = require("src.chams")
local binds = require("src.binds")

require("src.background")

callbacks.Unregister("CreateMove", "CM garlic bread cheat aimbot")
callbacks.Register("CreateMove", "CM garlic bread cheat aimbot", aimbot.CreateMove)
callbacks.Unregister("FrameStageNotify", "FSN garlic bread cheat aimbot frame stage")
callbacks.Register("FrameStageNotify", "FSN garlic bread cheat aimbot frame stage", aimbot.FrameStageNotify)
callbacks.Unregister("Draw", "DRAW garlic bread aimbot")
callbacks.Register("Draw", "DRAW garlic bread aimbot", aimbot.Draw)

--- this SendNetMsg overrides tickshift.SendNetMsg, gotta find a workaround or mix the two together (last option)
callbacks.Unregister("SendNetMsg", "NETMSG garlic bread spoof convars")
callbacks.Register("SendNetMsg", "NETMSG garlic bread spoof convars", spoof.SendNetMsg)

callbacks.Unregister("CreateMove", "CM garlic bread tick shifting")
callbacks.Register("CreateMove", "CM garlic bread tick shifting", tickshift.CreateMove)
callbacks.Unregister("SendNetMsg", "NETMSG garlic bread tick shifting")
callbacks.Register("SendNetMsg", "NETMSG garlic bread tick shifting", tickshift.SendNetMsg)
callbacks.Unregister("Draw", "DRAW garlic bread tick shifting")
callbacks.Register("Draw", "DRAW garlic bread tick shifting", tickshift.Draw)

callbacks.Unregister("CreateMove", "CM garlic bread anti aim")
callbacks.Register("CreateMove", "CM garlic bread anti aim", antiaim.CreateMove)
callbacks.Unregister("Draw", "DRAW garlic bread anti aim")
callbacks.Register("Draw", "DRAW garlic bread anti aim", antiaim.Draw)

callbacks.Unregister("RenderView", "RV garlic bread render view visuals")
callbacks.Register("RenderView", "RV garlic bread render view visuals", visuals.RenderView)
callbacks.Unregister("FrameStageNotify", "FSN garlic bread visuals frame stage")
callbacks.Register("FrameStageNotify", "FSN garlic bread visuals frame stage", visuals.FrameStageNotify)

callbacks.Unregister("CreateMove", "CM garlic bread movement")
callbacks.Register("CreateMove", "CM garlic bread movement", movement.CreateMove)

callbacks.Unregister("CreateMove", "CM garlic bread chams")
callbacks.Register("CreateMove", "CM garlic bread chams", chams.CreateMove)

callbacks.Unregister("DrawModel", "DME garlic bread chams")
callbacks.Register("DrawModel", "DME garlic bread chams", chams.DrawModel)

callbacks.Register("CreateMove", "CM garlic bread binds", binds.CreateMove)
callbacks.Register("FireGameEvent", "GE garlic bread binds", binds.FireGameEvent)

callbacks.Register("Unload", "UL garlic bread unload", function()
	antiaim.unload()
	GB_GLOBALS = nil
	collectgarbage("collect")
end)
