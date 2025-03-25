local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "fakelag: GB_GLOBALS is nil!")
assert(gb_settings, "fakelag: GB_SETTINGS is nil!")

local settings = gb_settings.fakelag

local fakelag = {}
local colors = require("src.colors")

local m_nChokedTicks = 0
local m_bWarping = false

local m_vecIndicatorPos = nil
local m_angIndicatorAngles = nil

---@type Entity?
local m_hIndicator = nil
local m_sModelName = "models/player/heavy.mdl"

local states = {
	choking = 1,
	recharging = 2,
}

local mat = materials.Create("garlic bread fakelag chams",
[[
"UnlitGeneric"
{
	$basetexture "vgui/white_additive"
}
]])

local m_nCurrentState = states.choking

local function GetChoked()
	return clientstate:GetChokedCommands()
end

local function DeleteIndicator()
	if m_hIndicator then
		m_hIndicator:Release()
		m_hIndicator = nil
	end
end

---@param usercmd UserCmd
function fakelag.CreateMove(usercmd)
	gb.bFakeLagEnabled = settings.enabled
	if not settings.enabled then
		DeleteIndicator()
		return
	end

	if m_nCurrentState == states.choking and not gb.bIsStacRunning then
		if GetChoked() < settings.ticks then
			usercmd.sendpacket = usercmd.buttons & IN_ATTACK ~= 0 and gb.CanWeaponShoot()
		else
			m_nCurrentState = states.recharging
		end
	elseif m_nCurrentState == states.recharging then
		if GetChoked() > 0 then
			m_bWarping = true
		else
			m_bWarping = false
			m_nCurrentState = states.choking
		end
	end

	if settings.indicator.enabled and (gb_settings.visuals.thirdperson.enabled or settings.indicator.firstperson) then
		local localplayer = entities:GetLocalPlayer()
		if not localplayer then return end

		if not m_hIndicator then
			m_hIndicator = entities.CreateEntityByName("grenade")
			if m_hIndicator then
				m_hIndicator:SetModel(m_sModelName) --- hoovy my beloved
			end
		end

		if GetChoked() == 0 then
			m_vecIndicatorPos = localplayer:GetAbsOrigin()
			m_angIndicatorAngles = localplayer:GetAbsAngles()
		end

		if not m_hIndicator then return end
		if m_vecIndicatorPos and m_angIndicatorAngles then
			m_hIndicator:SetAbsOrigin(m_vecIndicatorPos)
			m_hIndicator:SetAbsAngles(Vector3(m_angIndicatorAngles:Unpack()))
		end
	else
		DeleteIndicator()
	end
end

--- i honestly dont know if this is needed, but just in case, we warp when not choking to be able to choke more
---@param msg NetMessage
---@param returnval {ret: boolean, backupcmds: integer, newcmds: integer}
function fakelag.SendNetMsg(msg, buffer, returnval)
	if not settings.enabled then return true end
	if msg:GetType() == 9 and m_bWarping and GetChoked() > 0 and not gb.bIsAimbotShooting then

		buffer:SetCurBit(0)
		buffer:WriteInt(returnval.newcmds + returnval.backupcmds, 4)
		buffer:WriteInt(0, 3)
		buffer:SetCurBit(0)

		m_nChokedTicks = m_nChokedTicks - 1
	end
	returnval.ret = true
end

---@param context DrawModelContext
---@param entity Entity?
---@param modelname string
function fakelag.DrawModel(context, entity, modelname)
	if not settings.enabled or not settings.indicator.enabled then return end

	if entity == nil and m_hIndicator and m_hIndicator:ShouldDraw() and modelname == m_sModelName then
		local color = colors.FAKELAG
		local r, g, b, a = table.unpack(color)
		context:SetAlphaModulation(a/255)
		context:SetColorModulation(r/255, g/255, b/255)
		context:ForcedMaterialOverride(mat)
		render.OverrideDepthEnable(true, true)
		context:DepthRange(0, 0.2)
		context:Execute()
		render.OverrideDepthEnable(false, false)
		context:DepthRange(0, 1)
	end
end

local function CMD_ToggleFakeLag()
	settings.enabled = not settings.enabled
	printc(150, 150, 255, 255, "Fake lag is now " .. (settings.enabled and "enabled" or "disabled"))
end

local function CMD_ToggleFakeLagFirstPerson()
	settings.indicator.firstperson = not settings.indicator.firstperson
	printc(150, 150, 255, 255, "Fake lag indicator in 1st person is now " .. (settings.indicator.firstperson and "enabled" or "disabled"))
end

local function CMD_ToggleFakeLagIndicator()
	settings.indicator.enabled = not settings.indicator.enabled
	printc(150, 150, 255, 255, "Fake lag indicator is now " .. (settings.indicator.enabled and "enabled" or "disabled"))
end

local function CMD_SetChokeTicks(args, num_args)
	if not args or #args ~= num_args then return end
	if not args[1] then return end
	local new_value = tonumber(args[1])
	if not new_value or new_value < 0 then return end

	settings.ticks = new_value
	printc(150, 150, 255, 255, "Changed max choked ticks")
end

function fakelag.unload()
	DeleteIndicator()
	m_nChokedTicks = nil
	m_bWarping = nil
	m_hIndicator = nil
	m_vecIndicatorPos = nil
	m_angIndicatorAngles = nil
	states = nil
	m_nCurrentState = nil
	mat = nil
	m_sModelName = nil
	settings.indicator.firstperson = nil
	fakelag = nil
end

gb.RegisterCommand("fakelag->toggle", "Toggles fakelag", 0, CMD_ToggleFakeLag)
gb.RegisterCommand("fakelag->set->ticks", "Sets the amount of ticks to choke | args: new value (number)", 1, CMD_SetChokeTicks)
gb.RegisterCommand("fakelag->toggle->indicator", "Toggles the fakelag indicator", 0, CMD_ToggleFakeLagIndicator)
gb.RegisterCommand("fakelag->toggle->indicator_1st_person", "Toggles the fakelag indicator to appear in first person", 0, CMD_ToggleFakeLagFirstPerson)

return fakelag
