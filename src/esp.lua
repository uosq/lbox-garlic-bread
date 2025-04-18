local esp = {}

local font = draw.CreateFont("TF2 BUILD", 12, 1000)

local utils = require("src.esp.utils")
local colors = require("src.colors")

local settings = GB_SETTINGS.esp

local function DrawBuildings(class, localplayer, shootpos)
    for _, entity in pairs(class) do
        if not entity:IsValid() then goto continue end
        if entity:GetTeamNumber() == localplayer:GetTeamNumber() and settings.enemy_only then goto continue end
        if entity:GetHealth() <= 0 then goto continue end
        if entity:IsDormant() then goto continue end

        local maxs = entity:GetMaxs()
        local mins = entity:GetMins()
        local center = entity:GetAbsOrigin() + ((maxs + mins) >> 1)

        if settings.visible_only then
            local trace = engine.TraceLine(shootpos, center, MASK_SHOT_HULL)
            if not trace or trace.fraction <= 0.7 then goto continue end
        end

        local top, bottom
        top = client.WorldToScreen(entity:GetAbsOrigin() + Vector3(0, 0, maxs.z))
        bottom = client.WorldToScreen(entity:GetAbsOrigin() - Vector3(0, 0, 9))
        if not top or not bottom then goto continue end

        local h = bottom[2] - top[2]
        local w = math.floor(h * 0.3)

        local left, right
        left = top[1] - w
        right = top[1] + w

        local color = colors.get_entity_color(entity) or { 255, 255, 255, 255 }
        local r, g, b, a = table.unpack(color)
        a = 255
        local actualcolor = { r, g, b, a }

        draw.Color(255, 255, 255, 255)
        utils.DrawBuildingClass(font, top, entity:GetClass())

        if settings.fade then
            draw.Color(table.unpack(actualcolor or { 255, 255, 255, 255 }))
            draw.FilledRectFastFade(left + 1, top[2] + 1, right - 1, bottom[2] - 1, top[2] + 1, bottom[2] - 1, 0, 50,
                false)
        end

        draw.Color(table.unpack(actualcolor or { 255, 255, 255, 255 }))
        draw.OutlinedRect(left, top[2], right, bottom[2])

        utils.DrawVerticalHealthBar(entity:GetHealth(), entity:GetMaxHealth(), bottom, left, right)

        if settings.outline then
            draw.Color(0, 0, 0, 255)
            draw.OutlinedRect(left - 1, top[2] - 1, right + 1, bottom[2] + 1)
            draw.OutlinedRect(left + 1, top[2] + 1, right - 1, bottom[2] - 1)
        end

        ::continue::
    end
end

local function DrawPlayers(shootpos, index, team)
    for _, entity in pairs(Players) do
        if not entity:IsAlive() then goto continue end
        if entity:IsDormant() then goto continue end
        if entity:GetTeamNumber() == team and settings.enemy_only and entity:GetIndex() ~= index then goto continue end
        if entity:GetIndex() == index and not GB_SETTINGS.visuals.thirdperson.enabled then goto continue end
        if entity:InCond(E_TFCOND.TFCond_Cloaked) and settings.hide_cloaked then goto continue end

        local maxs = entity:GetMaxs()
        if settings.visible_only then
            --- we dont need mins if we dont want to see invisible dudes
            local mins = entity:GetMins()
            local center = entity:GetAbsOrigin() + ((maxs + mins) >> 1)
            local trace = engine.TraceLine(shootpos, center, MASK_SHOT_HULL)
            if not trace or trace.fraction <= 0.7 then goto continue end
        end

        local headpos = entity:GetAbsOrigin() + Vector3(0, 0, maxs.z)

        local top, bottom
        top = client.WorldToScreen(headpos)
        bottom = client.WorldToScreen(entity:GetAbsOrigin() - Vector3(0, 0, 9))
        if not top or not bottom then goto continue end

        local h = bottom[2] - top[2]
        local w = math.floor(h * 0.3)

        local left, right
        left = top[1] - w
        right = top[1] + w

        local color = colors.get_entity_color(entity) or { 255, 255, 255, 255 }
        local r, g, b, a = table.unpack(color)
        a = 255
        local actualcolor = { r, g, b, a }

        if settings.fade then
            draw.Color(table.unpack(actualcolor or { 255, 255, 255, 255 }))
            draw.FilledRectFastFade(left + 1, top[2] + 1, right - 1, bottom[2] - 1, top[2] + 1, bottom[2] - 1, 0, 50,
                false)
        end

        draw.Color(table.unpack(actualcolor))
        draw.OutlinedRect(left, top[2], right, bottom[2])

        utils.DrawHealthBar(entity:GetHealth(), entity:GetMaxHealth(), top, bottom, left, h)

        if entity:GetHealth() > entity:GetMaxHealth() then
            --- overheal
            utils.DrawOverhealBar(entity:GetHealth(), entity:GetMaxHealth(), entity:GetMaxBuffedHealth(), top, bottom,
                left, h)
        end

        if settings.outline then
            draw.Color(0, 0, 0, 255)
            draw.OutlinedRect(left - 1, top[2] - 1, right + 1, bottom[2] + 1)
            draw.OutlinedRect(left + 1, top[2] + 1, right - 1, bottom[2] - 1)
        end

        draw.Color(255, 255, 255, 255)
        utils.DrawClass(font, top, entity:GetPropInt("m_PlayerClass", "m_iClass"))

        ::continue::
    end
end

function esp.Draw()
    if not settings.enabled then return end
    if engine:IsGameUIVisible() or engine:Con_IsVisible() then return end
    if not Players or #Players == 0 then return end

    local localplayer = entities:GetLocalPlayer()
    if not localplayer then return end

    local team = localplayer:GetTeamNumber()
    local index = localplayer:GetIndex()
    local shootpos = localplayer:GetAbsOrigin() + localplayer:GetPropVector("m_vecViewOffset[0]")

    if settings.filter.players then
        DrawPlayers(shootpos, index, team)
    end

    if settings.filter.sentries and Sentries then
        DrawBuildings(Sentries, localplayer, shootpos)
    end

    if settings.filter.other_buildings and (Dispensers or Teleporters) then
        if Dispensers then
            DrawBuildings(Dispensers, localplayer, shootpos)
        end

        if Teleporters then
            DrawBuildings(Teleporters, localplayer, shootpos)
        end
    end
end

function esp.unload()
    esp = nil
    colors = nil
end

local function CMD_ToggleESP()
    settings.enabled = not settings.enabled
    printc(150, 150, 255, 255, "ESP is now " .. (settings.enabled and "enabled" or "disabled"))
end

local function CMD_ToggleVisibleOnly()
    settings.visible_only = not settings.visible_only
    printc(150, 150, 255, 255, "ESP visible only is " .. (settings.visible_only and "enabled" or "disabled"))
end

local function CMD_ToggleEnemyOnly()
    settings.enemy_only = not settings.enemy_only
    printc(150, 150, 255, 255, "ESP enemy only is " .. (settings.enemy_only and "enabled" or "disabled"))
end

local function CMD_ToggleHideCloaked()
    settings.hide_cloaked = not settings.hide_cloaked
    printc(150, 150, 255, 255, "ESP cloaked spy is " .. (settings.hide_cloaked and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("esp->toggle", "Toggles esp", 0, CMD_ToggleESP)
GB_GLOBALS.RegisterCommand("esp->toggle->enemy", "Makes esp only run on enemies or everyoe", 0, CMD_ToggleEnemyOnly)
GB_GLOBALS.RegisterCommand("esp->toggle->cloaked", "Makes esp not run on cloaked spies or not", 0, CMD_ToggleHideCloaked)
GB_GLOBALS.RegisterCommand("esp->toggle->visible", "Makes esp only run on visible players or everyone", 0,
    CMD_ToggleVisibleOnly)
return esp
