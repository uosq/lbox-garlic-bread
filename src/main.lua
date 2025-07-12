---@type GB_Math
local coolmath = require("src.dependencies.copypasta")
assert(coolmath, "Coolmath file is nil! WTF?")

---@type GB_Settings
local settings = require("src.settings")
assert(settings, "Settings file is nil! WTF!!!!!")

local aimbot = require("src.features.aimbot.run")
assert(aimbot, "Aimbot file is nil! WTF")

local antiaim = require("src.features.antiaim.run")
assert(antiaim, "Antiaim file is nil! WTF")

local fakelag = require("src.features.fakelag.run")
assert(fakelag, "Fakelag file is nil! WTF")

---@type GB_WepUtils
local wep_utils = require("src.features.utils.weapon_utils")
assert(wep_utils, "Weapon utils is nil! WTF")

---@type GB_EntUtils
local ent_utils = require("src.features.utils.entity")
assert(ent_utils, "Entity utils is nil! WTF")

local utils = {}
utils.math = coolmath

local font = draw.CreateFont("TF2 BUILD", 16, 600)

---@type GB_State
local state = {
	shooting = false,
	aimbot_running = false,
	aimbot_target = nil,
	stored_ticks = 0,
	choked_cmds = 0,
}

---@param uCmd UserCmd
local function CreateMove(uCmd)
	local plocal = entities.GetLocalPlayer()
	if not plocal then
		return
	end

	state.shooting = (uCmd.buttons & IN_ATTACK) ~= 0 and wep_utils.CanShoot()
	state.choked_cmds = clientstate:GetChokedCommands()

	fakelag.CreateMove(uCmd, state, settings)
	antiaim.CreateMove(uCmd, settings, state)

	state.aimbot_running, state.aimbot_target = aimbot.CreateMove(settings, utils, wep_utils, ent_utils, plocal, uCmd)
end

local function Draw()
	aimbot.Draw()

	local screen_w, screen_h = draw.GetScreenSize()

	draw.SetFont(font)
	draw.Color(255, 255, 255, 255)
	draw.Text(10, screen_h - 16, string.format("stored_ticks: %i", state.stored_ticks))
end

local function Unload()
	callbacks.Unregister("CreateMove", "Garlic Bread CM")
	callbacks.Unregister("Draw", "Garlic Bread Draw")

	fakelag.Unload()

	coolmath = nil
	settings = nil
	aimbot = nil
	wep_utils = nil
	ent_utils = nil
	utils = nil
	state = nil

	font = nil
end

callbacks.Unregister("CreateMove", "Garlic Bread CM")
callbacks.Unregister("Draw", "Garlic Bread Draw")

callbacks.Register("CreateMove", "Garlic Bread CM", CreateMove)
callbacks.Register("Draw", "Garlic Bread Draw", Draw)

callbacks.Register("Unload", Unload)
