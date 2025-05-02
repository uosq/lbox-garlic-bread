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

--- state
--local tabs = {aimbot = 0, esp = 1, chams = 2}
local tabs = {"aimbot", "esp", "chams", "misc"}
local tab = 1
local tabnum = #tabs
---

--- window's variables
local wx, wy = 10, 120
local w_background = {40, 40, 40, 255}
local w_border = 2
local w_title = "garlic bread - %s"
local w_titlesize = 25
local w_outline = {0, 150, 150, 255}
local w_width = 400
local w_height = 300

local w_halfwidth = w_width / 2
local w_halfheight = w_height / 2
local w_halftitlesize = w_titlesize // 2

--[[draw.SetFont(font)
local wtw, wth = draw.GetTextSize(w_title)

local w_halftw, w_halfth = wtw // 2, wth // 2]]
---

--- button's variables
local btn_border = 2
local btn_background = {35, 35, 35, 255}
local btn_hover = {60, 60, 60, 255}
local btn_click = {100, 100, 100, 255}
---

--- slider's variables
local sld_border = 2
local sld_background = {35, 35, 35, 255}
local sld_bar = {0, 150, 150, 255}
---

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

local function Window(mousedown, mx, my)
   draw.Color(table.unpack(w_outline))
   draw.FilledRect(wx - w_border, wy - w_border, wx + w_width + w_border, wy + w_height + w_border)

   draw.Color(table.unpack(w_background))
   draw.FilledRect(wx, wy, wx + w_width, wy + w_height)

   --- title
    draw.Color(table.unpack(w_outline))
    draw.FilledRect(wx - w_border, wy - w_titlesize - w_border, wx + w_width + w_border, wy)

   draw.SetFont(font)
   local tw, th = draw.GetTextSize(string.format(w_title, tabs[tab]))

--   draw.SetFont(font)
   draw.Color(255, 255, 255, 255)
   draw.TextShadow(wx + (w_halfwidth) - (tw//2), wy - w_halftitlesize - (th//2), string.format(w_title, tabs[tab]))

   if isinside(wx - w_border, wy - w_titlesize - w_border, w_width + w_border, w_titlesize) and mousedown then
      dragging = true
   end

   if input.IsButtonReleased(E_ButtonCode.MOUSE_LEFT) and dragging then
      dragging = false
   end

   if dragging then
      local dx, dy = mx - oldmx, my - oldmy --- delta from position from last Draw call and this one
      local sw, sh = draw.GetScreenSize()

      if wx + dx - w_border >= 0 and wx + dx + w_border + w_width <= sw then
         wx = wx + dx
      end

      if wy + dy - w_titlesize - w_border >= 0 and wy + w_height + dy + w_border <= sh then
         wy = wy + dy
      end
   end
end

---@param state boolean
---@param tick integer
---@param x integer
---@param y integer
---@param width integer
---@param height integer
---@param text string
---@return boolean Returns true if it was clicked, and false if not
local function Button(state, tick, x, y, width, height, text)
   --- make them relative to window x and y
   x, y = x + wx, y + wy

   local inside = isinside(x - btn_border, y - btn_border, width + btn_border, height + btn_border)

   draw.Color(255, 255, 255, 255)
   draw.FilledRect(x - btn_border, y - btn_border, x + width + btn_border, y + height + btn_border)

   local color = (inside and input.IsButtonDown(E_ButtonCode.MOUSE_LEFT)) and btn_click or inside and btn_hover or btn_background

   draw.Color(table.unpack(color))
   draw.FilledRect(x, y, x + width, y + height)

   draw.SetFont(font)
   local tw, th = draw.GetTextSize(text)
   local tx, ty = x + (width // 2) - (tw // 2), y + (height // 2) - (th // 2) --- // 2 is divide by 2 and floor

   draw.Color(255, 255, 255, 255)
   draw.TextShadow(tx, ty, text)

   if inside and ispressed(state, tick) then
      last_tick = tick
      return true
   end

   return false
end

---@param mousedown boolean
---@param x integer
---@param y integer
---@param width integer
---@param height integer
---@param min integer
---@param value integer
---@param max integer
---@return integer? Returns a new value if its clicked
local function Slider(mousedown, x, y, width, height, min, value, max, text)
   --- make them relative to the window's x and y
   x, y = x + wx, y + wy

   --- make the % be in the range [0, 1]
   local delta = max - min
   local percentage = (value - min) / delta

   --- outline
   draw.Color(255, 255, 255, 255)
   draw.FilledRect(x - sld_border, y - sld_border, x + width + sld_border, y + height + sld_border)

   --- background
   draw.Color(table.unpack(sld_background))
   draw.FilledRect(x, y, x + width, y + height)

   --- bar
   draw.Color(table.unpack(sld_bar))
   draw.FilledRect(x, y, (x + (width * percentage) // 1), y + height)

   --- text
   draw.SetFont(font)
   local tw, th = draw.GetTextSize(text)
   draw.Color(255, 255, 255, 255)
   draw.TextShadow(x + 2, y + (th // 2), text)

   --- mousedown = input.IsButtonDown(MOUSE_LEFT)
   if mousedown and isinside(x, y, width, height) then
      local mousepos = input.GetMousePos()
      local dx = mousepos[1] - x
      return min + ((dx / width) * delta) --- floor it
   end

   return nil
end

local function DrawAimbotTab(left, ltick, right, rtick, mousedown)
    do --- aimbot toggle
      local width, height = 120, 20
      local x, y = 5, 50 --- relative to window's x & y
      local unformat = "aimbot: %s"
      local enabled = gb_settings.aimbot.enabled
      local text = string.format(unformat, enabled and "ON" or "OFF")

      --- if it was clicked, invert the value
      if Button(left, ltick, x, y, width, height, text) then
         gb_settings.aimbot.enabled = not enabled
      end
   end

   do --- aimbot fov indicator
      local width, height = 120, 20
      local x, y = 5, 80
      local unformat = "indicator: %s"
      local enabled = gb_settings.aimbot.fov_indicator
      local text = string.format(unformat, enabled and "ON" or "OFF")

      if Button(left, ltick, x, y, width, height, text) then
         gb_settings.aimbot.fov_indicator = not gb_settings.aimbot.fov_indicator
      end
   end

   do --- aimbot fov
      local width, height = 120, 20
      local x, y = 5, 110
      local unformat = "aim fov: %s"
      local fov = gb_settings.aimbot.fov
      local text = string.format(unformat, fov)

      local newvalue = Slider(mousedown, x, y, width, height, 0, fov, 180, text)
      if newvalue then
         gb_settings.aimbot.fov = newvalue
      end
   end

   do --- aimbot autoshoot
      local unformatted = "autoshoot: %s"
      local enabled = gb_settings.aimbot.autoshoot
      local text = string.format(unformatted, enabled and "on" or "off")
      local x, y, width, height = 5, 140, 120, 20

      if Button(left, ltick, x, y, width, height, text) then
         gb_settings.aimbot.autoshoot = not enabled
      end
   end
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
   local mousedown = input.IsButtonDown(E_ButtonCode.MOUSE_LEFT)

   local mousepos = input.GetMousePos()
   local mx, my = mousepos[1], mousepos[2]

   --- instead of doing window, button classes
   -- im just gonna inline everything
   -- its too much work for a programming language that doesnt support OOP out of the box

   Window(mousedown, mx, my)

   do --- draw tab buttons, so we can change which tab we are in (aimbot, esp, chams, etc)
      local margin = 5 --- space between the left and right extremes... edges? idk
      local width = (w_width - 2*margin) / tabnum
      local height = 25

      --- initial x and y values
      --- they are changed in the for loop (only x)
      local x, y = 10, 10

      for i = 1, tabnum do
         local btnx = margin + (i-1) * width
         if Button(left, ltick, btnx//1, y, width//1, height, tabs[i]) then
            tab = i
         end
      end
   end

   if tab == 1 then --- tabs[1] = aimbot
      DrawAimbotTab(left, ltick, right, rtick, mousedown)
   else
      print("Somehow you are in a INVALID tab! This is a bug, report it to navet")
   end

   oldmx, oldmy = mx, my
end

function gui.unload()
   gui = nil
   last_tick = nil
   font = nil
end

return gui
