require("src.globals")
require("src.bitbuf")
require("src.anticheat")

local aimbot = require("src.aimbot-rewrite")
local tickshift = require("src.tickshift")
local antiaim = require("src.antiaim")
local visuals = require("src.visuals")

require("src.background")
require("src.commands")

--aimbot:SetDebug(false)

callbacks.Unregister("CreateMove", "CM garlic bread cheat aimbot")
callbacks.Register("CreateMove", "CM garlic bread cheat aimbot", aimbot.CreateMove)
callbacks.Unregister("FrameStageNotify", "FSN garlic bread cheat aimbot frame stage")
callbacks.Register("FrameStageNotify", "FSN garlic bread cheat aimbot frame stage", aimbot.FrameStage)

callbacks.Unregister("CreateMove", "CM garlic bread tick shifting")
callbacks.Register("CreateMove", "CM garlic bread tick shifting", tickshift.CreateMove)
callbacks.Unregister("SendNetMsg", "NETMSG garlic bread tick shifting")
callbacks.Register("SendNetMsg", "NETMSG garlic bread tick shifting", tickshift.SendNetMsg)
callbacks.Unregister("Draw", "DRAW garlic bread tick shifting")
callbacks.Register("Draw", "DRAW garlic bread tick shifting", tickshift.Draw)

callbacks.Unregister("CreateMove", "CM garlic bread anti aim")
callbacks.Register("CreateMove", "CM garlic bread anti aim", antiaim.CreateMove)

callbacks.Unregister("RenderView", "RV garlic bread custom fov")
callbacks.Register("RenderView", "RV garlic bread custom fov", visuals.CustomFOV)

callbacks.Register("Unload", "UL garlic bread unload", function()
	antiaim.unload()
	GB_GLOBALS = nil
	collectgarbage("collect")
end)
