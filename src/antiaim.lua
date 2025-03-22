local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "antiaim: GB_GLOBALS is nil!")
assert(gb_settings, "antiaim: GB_SETTINGS is nil!")

---@diagnostic disable:cast-local-type
local antiaim = {}

local m_font = draw.CreateFont("TF2 BUILD", 12, 1000)

---@param usercmd UserCmd
function antiaim.CreateMove(usercmd)
	if gb_settings.antiaim.enabled and not gb.bIsStacRunning
	and not gb.bWarping and not gb.bRecharging
	and not (usercmd.buttons & IN_ATTACK ~= 0 and gb.CanWeaponShoot()) then
		--- make sure we aren't overchoking
		if clientstate:GetChokedCommands() >= 21 then
			usercmd.sendpacket = true
			return
		end

		local view = engine:GetViewAngles()

		local realyaw = view.y + (gb_settings.antiaim.real_yaw or 0)
		local fakeyaw = view.y + (gb_settings.antiaim.fake_yaw or 0)

		local is_real_yaw_tick = usercmd.tick_count % 2 == 0
		local yaw = is_real_yaw_tick and fakeyaw or realyaw

		usercmd.viewangles = Vector3(view.x, yaw, 0)
		usercmd.sendpacket = is_real_yaw_tick
	end
end

function antiaim.unload()
	antiaim = nil
	m_font = nil
end

function antiaim.Draw()
	if not gb_settings.antiaim.enabled then
		return
	end

	local player = entities:GetLocalPlayer()
	if not player or not player:IsAlive() then
		return
	end

	local origin = player:GetAbsOrigin()
	if not origin then
		return
	end

	local origin_screen = client.WorldToScreen(origin)
	if not origin_screen then
		return
	end

	local startpos = origin
	local endpos = nil
	local line_size = 25

	local viewangle = engine:GetViewAngles().y

	local real_yaw, fake_yaw = gb_settings.antiaim.real_yaw + viewangle, gb_settings.antiaim.fake_yaw + viewangle
	local real_direction, fake_direction
	real_direction = Vector3(math.cos(math.rad(real_yaw)), math.sin(math.rad(real_yaw)))
	fake_direction = Vector3(math.cos(math.rad(fake_yaw)), math.sin(math.rad(fake_yaw)))

	endpos = origin + (fake_direction * line_size)

	local startpos_screen = client.WorldToScreen(startpos)
	if not startpos_screen then
		return
	end
	local endpos_screen = client.WorldToScreen(endpos)
	if not endpos_screen then
		return
	end

	--- fake yaw
	draw.Color(255, 150, 150, 255)
	draw.Line(startpos_screen[1], startpos_screen[2], endpos_screen[1], endpos_screen[2])
	draw.SetFont(m_font)
	draw.Color(255, 255, 255, 255)
	draw.TextShadow(endpos_screen[1], endpos_screen[2], "fake yaw")

	--- real yaw
	draw.Color(150, 255, 150, 255)
	endpos = origin + (real_direction * line_size)
	endpos_screen = client.WorldToScreen(endpos)
	if not endpos_screen then
		return
	end

	draw.Line(startpos_screen[1], startpos_screen[2], endpos_screen[1], endpos_screen[2])
	draw.Color(255, 255, 255, 255)
	draw.SetFont(m_font)
	draw.TextShadow(endpos_screen[1], endpos_screen[2], "real yaw")
end

--- SetVAngles doesn't work
function antiaim.FrameStageNotify(stage)
	if stage == E_ClientFrameStage.FRAME_NET_UPDATE_START and gb_settings.antiaim.enabled then
		local localplayer = entities:GetLocalPlayer()
		if not localplayer then
			return
		end
		local viewangles = engine:GetViewAngles()
		local angle = Vector3(viewangles.x, viewangles.y + gb_settings.antiaim.fake_yaw, 0)
		localplayer:SetVAngles(angle)
	end
end

local function cmd_toggle_aa()
	if gb.bIsStacRunning then
		printc(255, 0, 0, 255, "STAC is active! Won't change AA")
		return
	end
	gb_settings.antiaim.enabled = not gb_settings.antiaim.enabled
	printc(150, 255, 150, 255, "Anti aim is now " .. (gb_settings.antiaim.enabled and "enabled" or "disabled"))
end

local function cmd_set_options(args)
	if not args or #args == 0 then
		return
	end
	if not args[1] or not args[2] then
		return
	end

	local fake = args[1] == "fake"
	local real = args[1] == "real"
	local new_value = tonumber(args[2])
	if not new_value then
		print("Invalid value!")
		return
	end

	--local key = "m_fl%s%s"
	--local formatted = string.format(key, fake and "Fake" or "Real", wants_yaw and "Yaw" or "Pitch")
	if fake then
		gb_settings.antiaim.fake_yaw = new_value
	elseif real then
		gb_settings.antiaim.real_yaw = new_value
	end
end

gb.RegisterCommand(
	"antiaim->change",
	"Changes antiaim's yaw | args: fake or real (string), new value (number)",
	2,
	cmd_set_options
)
gb.RegisterCommand("antiaim->toggle", "Toggles antiaim", 0, cmd_toggle_aa)
return antiaim
