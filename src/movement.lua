local gb_settings = GB_SETTINGS
assert(gb_settings, "movement: GB_SETTINGS is nil!")

local maxspeed = 450

local function clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

local movement = {}

function movement.unload()
    movement = nil
end

---@param usercmd UserCmd
local function CreateMove(usercmd, player)
    usercmd.forwardmove = clamp(usercmd.forwardmove, -maxspeed, maxspeed)
    usercmd.sidemove = clamp(usercmd.sidemove, -maxspeed, maxspeed)

    local flags = player:GetPropInt("m_fFlags")
    local ground = (flags & FL_ONGROUND) ~= 0
    local class = player:GetPropInt("m_PlayerClass", "m_iClass")
    if not GB_GLOBALS.bIsStacRunning and gb_settings.misc.bhop and class ~= 1 then
        local jump = (usercmd.buttons & IN_JUMP) ~= 0
        if ground and jump then
            usercmd.buttons = usercmd.buttons | IN_JUMP
        elseif not ground and jump then
            usercmd.buttons = usercmd.buttons & ~IN_JUMP
        end
    end
end

local function cmd_ToggleBhop()
    gb_settings.misc.bhop = not gb_settings.misc.bhop
    printc(150, 255, 150, 255, "Bhop is now " .. (gb_settings.misc.bhop and "enabled" or "disabled"))
end

local function cmd_SetSpeed(args, num_args)
    if not args or #args ~= num_args then return end
    maxspeed = tonumber(args[1])
    printc(150, 255, 150, 255, "Changed max walk speed")
end

GB_GLOBALS.RegisterCommand("misc->toggle_bhop", "Toggles bunny hopping", 0, cmd_ToggleBhop)
GB_GLOBALS.RegisterCommand("misc->setspeed", "Changes your max walking speed | args: new max speed value (integer)", 1,
    cmd_SetSpeed)

movement.CreateMove = CreateMove
return movement
