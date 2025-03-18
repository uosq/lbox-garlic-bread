local custom = {}

local applied = false

local vmt =
[[
VertexLitGeneric
{
   $basetexture "dev/dev_measuregeneric01b"
   $color2 "[0.12, 0.12, 0.12]"
}
]]

local mat = materials.Create("gb_dev_texture_lolo", vmt)

local function CMD_ApplyTextures()
   applied = true
   materials.Enumerate(function (material)
      local group = material:GetTextureGroupName()
      if group == "World textures" then
         material:SetShaderParam("$basetexture", "dev/dev_measuregeneric01b")
         material:SetShaderParam("$color2", Vector3(0.12, 0.12, 0.12))
      end
   end)
end

---@param info StaticPropRenderInfo
function custom.DrawStaticProps(info)
   if not applied then return end
   --info:DrawExtraPass() --- i honestly dont know if this does anything, but its here just in case :p
   info:ForcedMaterialOverride(mat)
end

function custom.unload()
   mat = nil
   vmt = nil
   applied = nil
   custom = nil
end

GB_GLOBALS.RegisterCommand("mats->apply_custom", "Applies dev textures to materials | CANT BE REVERTED UNLESS YOU RESTART THE GAME!", 0, CMD_ApplyTextures)
return custom