local COLORS = {
    RED = { 255, 0, 0, 150 },
    BLU = { 0, 255, 255, 150 },

    TARGET = { 128, 255, 0, 50 },
    FRIEND = { 66, 245, 170, 50 },
    BACKTRACK = { 50, 166, 168, 50 },
    ANTIAIM = { 168, 50, 50, 50 },
    PRIORITY = { 238, 255, 0, 50 },
    FAKELAG = { 255, 179, 0, 50 },

    LOCALPLAYER = { 156, 66, 245, 50 },
    VIEWMODEL_ARM = { 210, 210, 255, 150 },
    VIEWMODEL_WEAPON = { 255, 255, 255, 100 },

    WEAPON_PRIMARY = { 163, 64, 90, 100 },
    WEAPON_SECONDARY = { 74, 79, 125, 100 },
    WEAPON_MELEE = { 255, 255, 255, 100 },

    RED_HAT = { 255, 0, 0, 150 },
    BLU_HAT = { 0, 0, 255, 150 },

    SENTRY_RED = { 255, 0, 0, 150 },
    SENTRY_BLU = { 8, 0, 255, 150 },

    DISPENSER_RED = { 130, 0, 0, 150 },
    DISPENSER_BLU = { 3, 0, 105, 150 },

    TELEPORTER_RED = { 173, 31, 107, 150 },
    TELEPORTER_BLU = { 0, 217, 255, 150 },

    AMMOPACK = { 255, 255, 255, 150 },
    HEALTHKIT = { 200, 255, 200, 100 },

    MVM_MONEY = { 52, 235, 82, 150 },

    RAGDOLL_RED = { 255, 150, 150, 100 },
    RAGDOLL_BLU = { 150, 150, 255, 100 },

    ORIGINAL_PLAYER = { 255, 255, 255, 255 },
    ORIGINAL_VIEWMODEL = { 255, 255, 255, 255 },

    WARP_BAR_BACKGROUND = { 30, 30, 30, 255 },
    WARP_BAR_STARTPOINT = { 255, 255, 0, 255 },
    WARP_BAR_ENDPOINT = { 153, 0, 255, 255 },
    WARP_BAR_TEXT = { 255, 255, 255, 255 },
    WARP_BAR_HIGHLIGHT = { 192, 192, 192, 255 },
}

--- used for string.find
local WEARABLES_CLASS = "Wearable"
local TEAM_RED = 2
local SENTRY_CLASS, DISPENSER_CLASS, TELEPORTER_CLASS =
    "CObjectSentrygun", "CObjectDispenser", "CObjectTeleporter"
local MVM_MONEY_CLASS = "CCurrencyPack"
local VIEWMODEL_ARM_CLASS = "CTFViewModel"

---@param entity Entity?
function COLORS.get_entity_color(entity)
    if (not entity) then return nil end

    if (entity:GetIndex() == client:GetLocalPlayerIndex()) then
        return COLORS.LOCALPLAYER
    end

    if (GB_GLOBALS.nAimbotTarget == entity:GetIndex()) then
        return COLORS.TARGET
    end

    if (entity:IsWeapon() and entity:IsMeleeWeapon()) then
        return COLORS.WEAPON_MELEE
    elseif (entity:IsWeapon() and not entity:IsMeleeWeapon()) then
        return entity:GetLoadoutSlot() == E_LoadoutSlot.LOADOUT_POSITION_PRIMARY and COLORS.WEAPON_PRIMARY
            or COLORS.WEAPON_SECONDARY
    end

    local team = entity:GetTeamNumber()
    do
        local class = entity:GetClass() -- not entity:GetPropInt("m_PlayerClass", "m_iClass")!!

        if (class == SENTRY_CLASS) then
            return team == TEAM_RED and COLORS.SENTRY_RED or COLORS.SENTRY_BLU
        elseif (class == DISPENSER_CLASS) then
            return team == TEAM_RED and COLORS.DISPENSER_RED or COLORS.DISPENSER_BLU
        elseif (class == TELEPORTER_CLASS) then
            return team == TEAM_RED and COLORS.TELEPORTER_RED or COLORS.TELEPORTER_BLU
        elseif (class == MVM_MONEY_CLASS) then
            return COLORS.MVM_MONEY
        elseif (class == VIEWMODEL_ARM_CLASS) then
            return COLORS.VIEWMODEL_ARM
        end

        if (class and string.find(class, WEARABLES_CLASS)) then
            return team == TEAM_RED and COLORS.RED_HAT or COLORS.BLU_HAT
        end
    end

    do
        local priority = playerlist.GetPriority(entity)
        if (priority and priority <= -1) then
            return COLORS.FRIEND
        elseif (priority and priority >= 1) then
            return COLORS.PRIORITY
        end
    end

    return COLORS[team == TEAM_RED and "RED" or "BLU"]
end

local function CMD_ChangeColor(args, num_args)
    if not args or #args ~= num_args then return end
    local r, g, b, a, selectedkey
    selectedkey = string.upper(tostring(args[1]))
    r = tonumber(args[2]) // 1
    g = tonumber(args[3]) // 1
    b = tonumber(args[4]) // 1
    a = tonumber(args[5]) // 1

    COLORS[selectedkey] = { r, g, b, a }
end

GB_GLOBALS.RegisterCommand("colors->change",
    "Changes the specified color (RGBA format) | args: r (integer), g (integer), b (integer), a (integer)", 5,
    CMD_ChangeColor)

return COLORS
