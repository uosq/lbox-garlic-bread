local materials = {
	flat = materials.Create(
		"garlic bread flat chams",
		[[
  "UnlitGeneric"
  {
    $basetexture "vgui/white_additive"
  }
  ]]
	),

	textured = materials.Create(
		"garlic bread textured chams",
		[[
  "VertexLitGeneric"
  {
    $basetexture "vgui/white_additive"
  }
  ]]
	),
}

--- E_TeamNumber is inverted
local TEAMS = { RED = 2, BLU = 3 }

local chams = {}

---@param context DrawModelContext
function chams.DrawModel(context) end

return chams
