local custom_aspect = {}
local gb = GB_GLOBALS
local settings = GB_SETTINGS.visuals

function custom_aspect:RenderView(setup)
	gb.nPreAspectRatio = setup.aspectRatio
	setup.aspectRatio = settings.aspect_ratio == 0 and setup.aspectRatio or settings.aspect_ratio
end

return custom_aspect