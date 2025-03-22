--- lol

local watermark = {}
local font = draw.CreateFont("TF2 BUILD", 24, 1000)
local smallfont-- = draw.CreateFont("TF2 BUILD", 12, 1000)
local settings = GB_SETTINGS.watermark

local stac_detected, no_stac
stac_detected = {255, 0, 0, 255}
no_stac = {50, 168, 82, 255}

---@type string
local text
do
   if GB_GLOBALS.bIsPreRelease then
      text = "garlic bread - pre release"
   else
      text = "garlic bread"
   end
end

draw.SetFont(font)
local w, h = draw.GetTextSize(text)
local x, y = 10, 10
local padding = 3
local outline_thickness = 2

w = math.floor(w) + padding
h = math.floor(h) + padding

function watermark.Draw()
   if not settings.enabled then return end
   if engine:IsGameUIVisible() or engine:Con_IsVisible() then return end
   if engine:IsTakingScreenshot() then return end

   --- outline
   local color = GB_GLOBALS.bIsStacRunning and stac_detected or no_stac
   draw.Color(table.unpack(color))
   draw.FilledRect(x + padding - outline_thickness, y + padding - outline_thickness,
   x + w + outline_thickness, y + h + outline_thickness)

   --- background
   draw.Color(40, 40, 40, 255)
   draw.FilledRect(x + padding, y + padding, x + w, y + h)

   draw.SetFont(font)
   draw.Color(255, 255, 255, 255)
   draw.TextShadow(x + padding, y + padding, text)

   if GB_GLOBALS.bIsStacRunning then
      if not smallfont then
         smallfont = draw.CreateFont("TF2 BUILD", 12, 1000)
      end

      draw.SetFont(smallfont)
      draw.Color(255, 0, 0, 255)
      draw.TextShadow(x, y + padding + h, "stac detected!")
   end
end

function watermark.unload()
   font = nil
   smallfont = nil
   text = nil
   stac_detected = nil
   no_stac = nil
   w, h = nil, nil
   x, y = nil, nil
   padding = nil
   outline_thickness = nil
   watermark = nil
end

return watermark