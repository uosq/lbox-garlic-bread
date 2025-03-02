local fakelag = {}
local colors = require("src.colors")

local m_bEnabled = false
local m_nTicks = 21
local m_nChokedTicks = 0
local m_bWarping = false

local m_vecIndicatorPos = nil
local m_angIndicatorAngles = nil
local m_bIndicatorInFirstPerson = false

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
	GB_GLOBALS.bFakeLagEnabled = m_bEnabled
	if not m_bEnabled then
		DeleteIndicator()
		return
	end

	if m_nCurrentState == states.choking and not GB_GLOBALS.bIsAimbotShooting and not GB_GLOBALS.bIsStacRunning then
		if GetChoked() < m_nTicks then
			usercmd.sendpacket = usercmd.buttons & IN_ATTACK == 1
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

	if GB_GLOBALS.bThirdperson or m_bIndicatorInFirstPerson then
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
---@param returnval {ret: boolean}
function fakelag.SendNetMsg(msg, returnval)
	if not m_bEnabled then return true end
	if msg:GetType() == 9 and m_bWarping and GetChoked() > 0 and not GB_GLOBALS.bIsAimbotShooting then
		local buffer = BitBuffer()
		CLC_Move:WriteToBitBuffer(buffer, 2, 1)
		m_nChokedTicks = m_nChokedTicks - 1
		buffer:Delete()
	end
	returnval.ret = true
end

---@param context DrawModelContext
function fakelag.DrawModel(context)
	if not m_bEnabled then return end
	local entity = context:GetEntity()

	if entity == nil and m_hIndicator and m_hIndicator:ShouldDraw() and context:GetModelName() == m_sModelName then
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
	m_bEnabled = not m_bEnabled
	printc(150, 150, 255, 255, "Fake lag is now " .. (m_bEnabled and "enabled" or "disabled"))
end

local function CMD_SetChokeTicks(args, num_args)
	if not args or #args ~= num_args then return end
	if not args[1] then return end
	local new_value = tonumber(args[1])
	if not new_value or new_value < 0 then return end

	m_nTicks = new_value
	printc(150, 150, 255, 255, "Changed max choked ticks")
end

function fakelag.unload()
	DeleteIndicator()
	m_bEnabled = nil
	m_nTicks = nil
	m_nChokedTicks = nil
	m_bWarping = nil
	m_hIndicator = nil
	m_vecIndicatorPos = nil
	m_angIndicatorAngles = nil
	states = nil
	m_nCurrentState = nil
	mat = nil
	m_sModelName = nil
	m_bIndicatorInFirstPerson = nil
	fakelag = nil
end

GB_GLOBALS.RegisterCommand("fakelag->toggle", "Toggles fakelag", 0, CMD_ToggleFakeLag)
GB_GLOBALS.RegisterCommand("fakelag->set->ticks", "Sets the amount of ticks to choke | args: new value (number)", 1, CMD_SetChokeTicks)

return fakelag
