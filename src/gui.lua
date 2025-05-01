local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "gui: GB_GLOBALS is nil!")
assert(gb_settings, "gui: GB_SETTINGS is nil!")

---@diagnostic disable: assign-type-mismatch
--local lib = require("src.gui utils")
local gui = {}
local last_tick = 0
local font = draw.CreateFont("TF2 BUILD", 12, 1000)

local oldmx, oldmy = 0, 0
local dragging = false

local wx, wy = 10, 120

local function ispressed(state, tick)
   if state and tick > last_tick then
      return true
   end
   return false
end

local function isinside(x, y, width, height)
   local pos = input.GetMousePos()
   local mx, my = pos[1], pos[2]
   return mx >= x and my >= y and mx <= x + width and my <= y + height
end

---@param state boolean
---@param tick integer
---@param x integer
---@param y integer
---@param width integer
---@param height integer
---@param wx integer Window X
---@param wy integer Window Y
---@param text string
---@return boolean Returns true if it was clicked, and false if not
local function Button(state, tick, x, y, width, height, wx, wy, text)
   local background = {35, 35, 35, 255}
   local unformat = "Aimbot: %s"
   local border = 2

   --- make them relative to window x and y
   local x = x + wx
   local y = y + wy

   draw.Color(255, 255, 255, 255)
   draw.FilledRect(x - border, y - border, x + width + border, y + height + border)

   draw.Color(table.unpack(background))
   draw.FilledRect(x, y, x + width, y + height)

   draw.SetFont(font)
   local tw, th = draw.GetTextSize(text)
   local tx, ty = x + (width // 2) - (tw // 2), y + (height // 2) - (th // 2) --- // 2 is divide by 2 and floor

   draw.Color(255, 255, 255, 255)
   draw.TextShadow(tx, ty, text)

   if ispressed(state, tick) and isinside(x - border, y - border, width + border, height + border) then
      last_tick = tick
      return true
   end

   return false
end

function gui.Draw()
   do
      local state, tick = input.IsButtonPressed(gb_settings.gui.toggle)
      if state and tick > last_tick then
         last_tick = tick
         gb_settings.gui.visible = not gb_settings.gui.visible
         input.SetMouseInputEnabled(gb_settings.gui.visible)
      end

      if not gb_settings.gui.visible then
         return
      end
   end

   local left, ltick = input.IsButtonPressed(E_ButtonCode.MOUSE_LEFT)
   local right, rtick = input.IsButtonPressed(E_ButtonCode.MOUSE_RIGHT)

   local mousepos = input.GetMousePos()
   local mx, my = mousepos[1], mousepos[2]

   --- instead of doing window, button classes
   -- im just gonna inline everything
   -- its too much work for a programming language that doesnt support OOP out of the box

   do --- window
      local width, height = 400, 300
      local background = {40, 40, 40, 255}
      local outline = {0, 150, 150, 255}
      local title = "Garlic Bread"
      local title_size = 25
      local border = 2

      draw.Color(table.unpack(outline))
      draw.FilledRect(wx - border, wy - border, wx + width + border, wy + height + border)

      draw.Color(table.unpack(background))
      draw.FilledRect(wx, wy, wx + width, wy + height)

      --- title
      draw.Color(table.unpack(outline))
      draw.FilledRect(wx - border, wy - title_size - border, wx + width + border, wy)

      draw.SetFont(font)
      local tw, th = draw.GetTextSize(title)
      draw.Color(255, 255, 255, 255)
      draw.TextShadow(wx + (width // 2) - (tw // 2), wy - (title_size // 2) - (th // 2), title)

      if isinside(wx - border, wy - title_size - border, width + border, title_size) and input.IsButtonDown(E_ButtonCode.MOUSE_LEFT) then
         dragging = true
      end

      if input.IsButtonReleased(E_ButtonCode.MOUSE_LEFT) and dragging then
         dragging = false
      end

      if dragging then
         local dx, dy = mx - oldmx, my - oldmy --- delta from position from last Draw call and this one
         local sw, sh = draw.GetScreenSize()

         if wx + dx - border >= 0 and wx + dx + border + width <= sw then
            wx = wx + dx
         end

         if wy + dy - title_size - border >= 0 and wy + height + dy + border <= sh then
            wy = wy + dy
         end
      end
   end

   do --- aimbot toggle
      local width, height = 120, 20
      local x, y = 10, 10 --- relative to window's x & y
      local unformat = "aimbot: %s"
      local enabled = gb_settings.aimbot.enabled
      local text = string.format(unformat, enabled and "ON" or "OFF")

      --- if it was clicked, invert the value
      if Button(left, ltick, x, y, width, height, wx, wy, text) then
         gb_settings.aimbot.enabled = not enabled
      end
   end

   do --- aimbot fov indicator
      local width, height = 120, 20
      local x, y = 10, 40
      local unformat = "indicator: %s"
      local enabled = gb_settings.aimbot.fov_indicator
      local text = string.format(unformat, enabled and "ON" or "OFF")

      if Button(left, ltick, x, y, width, height, wx, wy, text) then
         gb_settings.aimbot.fov_indicator = not gb_settings.aimbot.fov_indicator
      end
   end

   do --- aimbot fov
      local width, height = 120, 20
      local x, y = 10, 70
      local unformat = "aim fov: %s"
      local fov = gb_settings.aimbot.fov
      local text = string.format(unformat, fov)

      --- this is janky
      -- rendering the same button twice is not a good solution
      -- WARNING: fix this later

      if Button(left, ltick, x, y, width, height, wx, wy, text) then
         fov = fov + 1
         if fov > 180 then
            fov = 1
         end

         gb_settings.aimbot.fov = fov

      --- right click, THIS IS NOT A GOOD SOLUTION!
      elseif Button(right, rtick, x, y, width, height, wx, wy, text) then
         fov = fov - 1
         if fov <= 0 then
            fov = 180
         end

         gb_settings.aimbot.fov = fov
      end
   end

   oldmx, oldmy = mx, my
end

function gui.unload()
   gui = nil
   last_tick = nil
   font = nil
end

return gui
