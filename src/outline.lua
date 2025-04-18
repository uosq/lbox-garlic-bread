local m_gb = GB_GLOBALS
assert(m_gb, "outline: GB_GLOBALS is nil!")

local m_settings = GB_SETTINGS.outline
assert(m_settings, "outline: GB_SETTINGS.outline is nil!")

local m_colors = require("src.colors")
assert(m_colors, "outline: src.colors is nil!")

local get_entity_color = m_colors.get_entity_color
local unpack = table.unpack

local divided = 1 / 255

local outline = {}

local vmt =
[[
UnlitGeneric
{
    $basetexture "vgui/white_additive"
    $wireframe 1
    $envmap "skybox/sky_dustbowl_01"
    $additive 1
}
]]

local m_vmtflat =
[[
UnlitGeneric
{
    $basetexture "vgui/white_additive"
}
]]

---@type Material?
local m_material = nil

---@type Material?
local m_flatmat = nil

local STENCILOPERATION_KEEP = E_StencilOperation.STENCILOPERATION_KEEP
local STENCILCOMPARISONFUNCTION_ALWAYS = E_StencilComparisonFunction.STENCILCOMPARISONFUNCTION_ALWAYS
local STENCILCOMPARISONFUNCTION_EQUAL = E_StencilComparisonFunction.STENCILCOMPARISONFUNCTION_EQUAL
local STENCILOPERATION_REPLACE = E_StencilOperation.STENCILOPERATION_REPLACE

---@param entity Entity
---@return boolean
local function ShouldRun(entity)
    if entity:IsDormant() then return false end

    local plocal = entities.GetLocalPlayer()
    if not plocal then return false end

    if m_settings.localplayer and entity:GetIndex() == plocal:GetIndex() then
        return true
    end

    if entity:GetTeamNumber() == plocal:GetTeamNumber() and m_settings.enemy_only then
        return false
    end

    if m_settings.players and entity:IsPlayer() then
        return true
    else
        if m_settings.weapons and (entity:IsShootingWeapon() or entity:IsMeleeWeapon()) then
            return true
        end

        if m_settings.hats then
            local class = entity:GetClass()
            if string.find(class, "Wearable") then
                return true
            end
            class = nil
        end
    end

    --- free plocal as we dont need it anymore
    plocal = nil
    return false
end

---@param dme DrawModelContext
---@param entity Entity?
function outline.DrawModel(dme, entity)
    if not m_settings.enabled then return end
    if not entity then return end
    if not ShouldRun(entity) then return end

    local color = get_entity_color(entity)
    if not color then return end

    --- just in case its nil for some reason
    if m_material == nil then
        m_material = materials.Create("cooloutline", vmt)
    end

    if m_flatmat == nil then
        m_flatmat = materials.Create("coolflatmateriallolo", m_vmtflat)
    end

    local r, g, b = unpack(color)

    render.SetStencilEnable(true)
    render.OverrideDepthEnable(true, true)

    --- player stencil
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
    render.SetStencilPassOperation(STENCILOPERATION_REPLACE);
    render.SetStencilFailOperation(STENCILOPERATION_KEEP);
    render.SetStencilZFailOperation(STENCILOPERATION_REPLACE);
    render.SetStencilTestMask(0x0)
    render.SetStencilWriteMask(0xFF)
    render.SetStencilReferenceValue(1)

    --- draw invisible player (this is important trust me)
    dme:ForcedMaterialOverride(m_flatmat)
    dme:SetAlphaModulation(0)
    dme:Execute()

    --- outline stencil
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
    render.SetStencilPassOperation(STENCILOPERATION_KEEP)
    render.SetStencilFailOperation(STENCILOPERATION_KEEP)
    render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
    render.SetStencilTestMask(0xFF)
    render.SetStencilWriteMask(0x0)
    render.SetStencilReferenceValue(0)

    --- draw the actual outline
    dme:DepthRange(0, m_settings.visible_only and 1 or 0.2)
    dme:ForcedMaterialOverride(m_material)
    dme:SetColorModulation(r * divided, g * divided, b * divided)
    dme:SetAlphaModulation(1)
    dme:Execute()

    render.OverrideDepthEnable(false, false)
    render.SetStencilEnable(false)

    --- now we draw the original model
    dme:ForcedMaterialOverride(m_flatmat)
    --dme:SetColorModulation(1, 1, 1)
    dme:SetAlphaModulation(0.1)
    dme:DepthRange(0, 1)
end

function outline.unload()
    outline = {}

    m_flatmat = nil
    divided = nil
    vmt = nil
    m_vmtflat = nil
    get_entity_color = nil
    unpack = nil
end

--- outline->toggle hide_cloaked
local function CMD_ChangeOption(args, num_args)
    if not args or #args ~= num_args then return end
    local selected_option = tostring(args[1])
    m_settings[selected_option] = not m_settings[selected_option]
    printc(150, 255, 150, 255, string.format("Toggled option %s", selected_option))
end

local function CMD_GetOptions(args, num_args)
    if not args or #args ~= num_args then return end
    for i, v in pairs(m_settings) do
        printc(255, 255, 0, 255, string.format("%s | %s", i, v))
    end
end

GB_GLOBALS.RegisterCommand("outline->toggle", "Toggles a outline option", 1, CMD_ChangeOption)
GB_GLOBALS.RegisterCommand("outline->options", "Prints all options", 0, CMD_GetOptions)
return outline
