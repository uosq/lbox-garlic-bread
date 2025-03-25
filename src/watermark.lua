--- lol

local watermark = {}
local font = draw.CreateFont("TF2 BUILD", 24, 1000)
local smallfont -- = draw.CreateFont("TF2 BUILD", 12, 1000)
local settings = GB_SETTINGS.watermark

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
local padding = 2

w = math.floor(w) + padding
h = math.floor(h) + padding

--[[ source: https://github.com/EmmanuelOga/columns/blob/master/utils/color.lua#L113
 * Converts an HSV color value to RGB. Conversion formula
 * adapted from http://en.wikipedia.org/wiki/HSV_color_space.
 * Assumes h, s, and v are contained in the set [0, 1] and
 * returns r, g, and b in the set [0, 255].
 *
 * @param   Number  h       The hue
 * @param   Number  s       The saturation
 * @param   Number  v       The value
 * @return  Array           The RGB representation
]]
local function hsvToRgb(h, s, v, a)
   local r, g, b

   local i = math.floor(h * 6);
   local f = h * 6 - i;
   local p = v * (1 - s);
   local q = v * (1 - f * s);
   local t = v * (1 - (1 - f) * s);

   i = i % 6

   if i == 0 then
      r, g, b = v, t, p
   elseif i == 1 then
      r, g, b = q, v, p
   elseif i == 2 then
      r, g, b = p, v, t
   elseif i == 3 then
      r, g, b = p, q, v
   elseif i == 4 then
      r, g, b = t, p, v
   elseif i == 5 then
      r, g, b = v, p, q
   end

   return r * 255, g * 255, b * 255, a * 255
end

function watermark.Draw()
   if not settings.enabled then return end
   if engine:IsGameUIVisible() or engine:Con_IsVisible() then return end
   if engine:IsTakingScreenshot() then return end

   --- outline
   local hue = GB_GLOBALS.bIsStacRunning and 0 or 0.5
   draw.SetFont(font)

   do
      local r, g, b, a = hsvToRgb(hue, 0, 0.5, 1)
      r, g, b, a = math.floor(r), math.floor(g), math.floor(b), math.floor(a)
      draw.Color(r, g, b, a)
      draw.Text(x + padding, y + padding, text)
   end

   do
      local r, g, b, a = hsvToRgb(hue, 0, 1, 1)
      r, g, b, a = math.floor(r), math.floor(g), math.floor(b), math.floor(a)
      draw.Color(r, g, b, a)
      draw.Text(x, y, text)
   end

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
   w, h = nil, nil
   x, y = nil, nil
   padding = nil
   watermark = nil
end

return watermark
