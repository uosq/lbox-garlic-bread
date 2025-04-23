local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "tickshift: GB_GLOBALS is nil!")
assert(gb_settings, "tickshift: GB_SETTINGS is nil!")

local SIGNONSTATE_TYPE = 6
local CLC_MOVE_TYPE = 9

local charged_ticks = 0

local max_ticks = 0
local last_key_tick = 0
local next_passive_tick = 0

local m_enabled = true
local warping, recharging = false, false
local doubletaping = false
local old_clinterp = 0.03

local font = draw.CreateFont("TF2 BUILD", 16, 1000)

---@type number
local m_localplayer_speed

local colors = require("src.colors")

local tickshift = {}

local function CanChoke()
    return clientstate:GetChokedCommands() < max_ticks
end

local function CanShift()
    return clientstate:GetChokedCommands() == 0
end

local function GetMaxServerTicks()
    local sv_maxusrcmdprocessticks = client.GetConVar("sv_maxusrcmdprocessticks")
    if sv_maxusrcmdprocessticks then
        return sv_maxusrcmdprocessticks > 0 and sv_maxusrcmdprocessticks or 9999999
    end
    return 24
end

---@param buffer BitBuffer
function HandleWarp(buffer)
    local player = entities:GetLocalPlayer()
    if player and m_localplayer_speed <= 0 and not gb_settings.tickshift.warp.standing_still then
        return
    end

    if player and player:IsAlive() and charged_ticks > 0 and CanShift() then
        buffer:SetCurBit(0)

        buffer:WriteInt(2, 4) --- newcmd
        buffer:WriteInt(1, 3) --- backupcmd

        buffer:SetCurBit(0)

        --- make the warp only work once (if its <= 0 it wont try to warp again)
        charged_ticks = charged_ticks - 1
    end
end

---@param buffer BitBuffer
local function HandleDoubleTap(buffer, newcmds, backupcmds)
    local player = entities:GetLocalPlayer()

    if not player or not player:IsAlive() then return end
    if charged_ticks <= 1 then return end

    buffer:SetCurBit(0)

    buffer:WriteInt(newcmds + backupcmds, 4) --- new command
    buffer:WriteInt(0, 3)                    --- backup commands

    buffer:SetCurBit(0)
    charged_ticks = charged_ticks - backupcmds

    recharging = false
end

local function HandlePassiveRecharge()
    if not gb_settings.tickshift.warp.passive.enabled or charged_ticks >= max_ticks then
        return false
    end

    local player = entities:GetLocalPlayer()
    if (not player) then return false end

    if
        (globals.TickCount() >= next_passive_tick)
        or (gb_settings.tickshift.warp.passive.while_dead and not player:IsAlive())
    then
        charged_ticks = charged_ticks + 1
        local time = engine.RandomFloat(gb_settings.tickshift.warp.passive.min_time,
            gb_settings.tickshift.warp.passive.max_time)
        next_passive_tick = globals.TickCount() + (time * 66.67)
        return true
    end

    return false
end

local function clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

local function HandleRecharge()
    if CanChoke() and charged_ticks < max_ticks and recharging then
        charged_ticks = charged_ticks + 1
        return true
    end

    if HandlePassiveRecharge() then
        return true
    end

    return false
end

--- Resets the variables to their default state when joining a new server
local function HandleJoinServers()
    if clientstate:GetClientSignonState() == E_SignonState.SIGNONSTATE_SPAWN then
        m_localplayer_speed = 0
        max_ticks = GetMaxServerTicks()
        charged_ticks = 0
        last_key_tick = 0
        next_passive_tick = 0
    end
end

---@param msg NetMessage
---@param returnval {ret: boolean, backupcmds: integer, newcmds: integer}
function tickshift.SendNetMsg(msg, buffer, returnval)
    --- return early if user disabled with console commands
    if not m_enabled then return true end

    if msg:GetType() == SIGNONSTATE_TYPE then
        HandleJoinServers()
    end

    --if gb.bIsStacRunning or gb.bFakeLagEnabled then return true end

    if engine.IsChatOpen() or engine.IsGameUIVisible() or engine.Con_IsVisible() then
        return true
    end

    if msg:GetType() == CLC_MOVE_TYPE then
        buffer:SetCurBit(0)

        buffer:WriteInt(returnval.newcmds, 4)
        buffer:WriteInt(returnval.backupcmds, 3)

        if doubletaping then
            HandleDoubleTap(buffer, returnval.newcmds, returnval.backupcmds)
        elseif warping and not recharging then
            HandleWarp(buffer)
        elseif HandleRecharge() then
            gb.bRecharging = true
            recharging = true
            returnval.ret = false
        end

        buffer:SetCurBit(0)
        msg:ReadFromBitBuffer(buffer)
        buffer:Delete()
    end
end

--- thanks Glitch!
---@param usercmd UserCmd
---@param player Entity
local function AntiWarp(player, usercmd)
    local vel = player:EstimateAbsVelocity()
    local flags = player:GetPropInt("m_fFlags")
    if (flags & FL_ONGROUND) == 0 or vel:Length2D() <= 15 or (usercmd.buttons & IN_JUMP) ~= 0 then return end

    local yaw = engine:GetViewAngles().y
    local dir = vel:Angles()
    dir.y = yaw - dir.y
    local forward = dir:Forward() * -vel:Length2D()
    usercmd.forwardmove, usercmd.sidemove = forward.x, forward.y
end

---@param usercmd UserCmd
function tickshift.CreateMove(usercmd, player)
    if engine.IsChatOpen() or engine.IsGameUIVisible() or engine.Con_IsVisible()
        or gb.bIsStacRunning or not m_enabled --[[or gb.bFakeLagEnabled]] then
        return
    end

    m_localplayer_speed = player:EstimateAbsVelocity():Length() or 0
    max_ticks = GetMaxServerTicks()
    charged_ticks = clamp(charged_ticks, 0, max_ticks)

    warping = input.IsButtonDown(gb_settings.tickshift.warp.send_key) and charged_ticks > 0
    gb.bWarping = warping
    recharging = input.IsButtonDown(gb_settings.tickshift.warp.recharge_key) and charged_ticks < max_ticks
    gb.bRecharging = recharging

    doubletaping = gb_settings.tickshift.doubletap.enabled
        and input.IsButtonDown(gb_settings.tickshift.doubletap.key)
        and (usercmd.buttons & IN_ATTACK ~= 0)
        and charged_ticks > 0

    gb.bDoubleTapping = doubletaping

    if recharging then
        usercmd.tick_count = 0
        usercmd.command_number = 0
        usercmd.buttons = 0
    end

    local state, tick = input.IsButtonPressed(gb_settings.tickshift.warp.passive.toggle_key)
    if state and last_key_tick < tick then
        gb_settings.tickshift.warp.passive.enabled = not gb_settings.tickshift.warp.passive.enabled
        last_key_tick = tick
        client.ChatPrintf("Passive recharge: " .. (gb_settings.tickshift.warp.passive.enabled and "ON" or "OFF"))
    end

    if doubletaping then
        AntiWarp(player, usercmd)
    end

    local netchan = clientstate.GetNetChannel()
    if netchan then
        --- the cause of the jittering when recharging is the clientsided interp
        --- this should fix it, but it does exactly 0 shit
        _, old_clinterp = client.GetConVar("cl_interp")
        netchan:SetInterpolationAmount(recharging and 0 or old_clinterp)
    end
end

function tickshift.Draw()
    if
        engine:Con_IsVisible()
        or engine:IsGameUIVisible()
        or (engine:IsTakingScreenshot() and gui.GetValue("clean screenshots") == 1)
        or not m_enabled or gb.bIsStacRunning --[[or gb.bFakeLagEnabled]]
    then
        return
    end

    local screenX, screenY = draw:GetScreenSize()
    local centerX, centerY = math.floor(screenX / 2), math.floor(screenY / 2)

    local formatted_text = string.format("%i / %i", charged_ticks, max_ticks)
    draw.SetFont(font)
    local textW, textH = draw.GetTextSize(formatted_text)

    local barWidth = 200
    local barHeight = 20
    local offset = 2
    local percent = charged_ticks / max_ticks
    local barX, barY = math.floor(centerX - (barWidth / 2)), math.floor(centerY + 40)
    local textX, textY = math.floor(barX + (barWidth * 0.5) - (textW / 2)),
        math.floor(barY + (barHeight * 0.5) - (textH * 0.5))

    draw.Color(table.unpack(colors.WARP_BAR_BACKGROUND))
    draw.FilledRect(
        math.floor(barX - offset),
        math.floor(barY - offset),
        math.floor(barX + barWidth + offset),
        math.floor(barY + barHeight + offset)
    )

    draw.Color(table.unpack(colors.WARP_BAR_HIGHLIGHT))
    draw.OutlinedRect(
        math.floor(barX - offset - 1),
        math.floor(barY - offset - 1),
        math.floor(barX + barWidth + offset + 1),
        math.floor(barY + barHeight + offset + 1)
    )

    pcall(function()
        --- amarelo foda
        draw.Color(table.unpack(colors.WARP_BAR_STARTPOINT))
        --draw.FilledRectFade(barX, barY, math.floor(barX + (barWidth * percent)), barY + barHeight, 255, 50, true)
        draw.FilledRectFade(barX, barY, barX + barWidth, barY + barHeight, 255, 50, true)

        --- roxo pica
        draw.Color(table.unpack(colors.WARP_BAR_ENDPOINT))
        draw.FilledRectFade(barX, barY, barX + barWidth, barY + barHeight, 50, 255, true)

        --- é a verdadeira barra que mudamos, ela vai da direita pra esquerda pra esconder o gradiente foda
        draw.Color(table.unpack(colors.WARP_BAR_BACKGROUND))
        draw.FilledRect(math.floor(barX + (barWidth * percent)), barY, barX + barWidth, barY + barHeight)
    end)

    draw.SetFont(font)
    draw.Color(table.unpack(colors.WARP_BAR_TEXT))
    draw.TextShadow(textX, textY, formatted_text)

    do --- charge bar status
        draw.SetFont(font)
        --- this is the most vile, horrendous, horrible code i have probably ever written
        --- but if it works, it works
        local color = gb_settings.fakelag.enabled and { 255, 150, 150, 255 }
            or doubletaping and { 255, 0, 0, 255 }
            or charged_ticks >= max_ticks and { 128, 255, 0, 255 }
            or warping and { 0, 225, 255, 255 }
            or recharging and { 255, 255, 0, 255 }
            or { 255, 255, 255, 255 }
        draw.Color(table.unpack(color))

        local text = gb_settings.fakelag.enabled and "FAKELAGGING"
            or doubletaping and "DOUBLETAP"
            or charged_ticks >= max_ticks and "READY"
            or warping and "WARPING"
            or recharging and "RECHARGING"
            or "IDLE"

        local textW, textH = draw.GetTextSize(text)
        local textX, textY = math.floor(barX + (barWidth * 0.5) - (textW * 0.5)), math.floor(barY - textH - 2)
        draw.TextShadow(textX, textY, text)
    end
end

local function cmd_ToggleTickShift()
    m_enabled = not m_enabled
    printc(150, 255, 150, 255, "Tick shifting is now " .. (m_enabled and "enabled" or "disabled"))
end

function tickshift.unload()
    SIGNONSTATE_TYPE = nil
    CLC_MOVE_TYPE = nil
    charged_ticks = nil
    max_ticks = nil
    last_key_tick = nil
    next_passive_tick = nil
    m_enabled = nil
    warping, recharging = nil, nil
    font = nil
    m_localplayer_speed = nil
    gb_settings.tickshift = nil
    tickshift = nil
end

local function cmd_ChangeWarpBarComponentColor(args, num_args)
    if not args or #args ~= num_args then return end

    local chosen_component = string.upper(tostring(args[1]))
    local r, g, b, a = tostring(args[2]), tostring(args[3]), tostring(args[4]), tostring(args[5])
    if not r or not g or not b or not a then return end

    colors["WARP_BAR_" .. chosen_component] = { r, g, b, a }
end

local function cmd_GetWarpBarComponents()
    printc(255, 255, 0, 255, "Components:")
    for key in pairs(colors) do
        if string.find(key, "WARP") then
            local formattedtext = string.gsub(key, "WARP_BAR_", "")
            printc(0, 255, 255, 255, string.lower(formattedtext))
        end
    end
end

gb.RegisterCommand("tickshift->toggle", "Toggles tickshifting (warp, recharge)", 0, cmd_ToggleTickShift)
gb.RegisterCommand("tickshift->warpbar->change_color", "Changes the color of the chosen component of the warp bar", 5,
    cmd_ChangeWarpBarComponentColor)
gb.RegisterCommand("tickshift->warpbar->getcomponents", "Gets the warp bar components you can change with change_color",
    0, cmd_GetWarpBarComponents)
return tickshift
