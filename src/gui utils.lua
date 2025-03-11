local font = draw.CreateFont("TF2 BUILD", 14, 1000)
local GUI = {}

--- START ROOT

local last_clicked_tick = 0

---@class GUIRoot
---@field parent GUIWindow?
local GUIRoot = {
   width = 0, height = 0,
   x = 0, y = 0,
   background = {0, 0, 0, 250},
   outline = {255, 255, 255, 255},
   enabled = true,
   events = {},
   parent = nil,
}
setmetatable(GUIRoot, {__index = GUIRoot})
function GUIRoot:render()end

---@param parent GUIWindow?
---@param width integer?
---@param height integer?
function GUIRoot:CheckInput(parent, width, height)
   if not self.enabled then return end
   width = width or self.width
   height = height or self.height
   local mousePos = input:GetMousePos()
   local mx, my = mousePos[1], mousePos[2]
   local px, py = (parent and parent.x or 0), (parent and parent.y or 0)

   local mouseIsInside = mx >= self.x + px and mx <= self.x + width + px and my >= self.y + py and my <= self.y + height + py
   if not mouseIsInside then return end

   local state, tick = input.IsButtonPressed(E_ButtonCode.MOUSE_LEFT)

   -- Make sure we're checking events for THIS element, not another one
   if self.events.onhover then
      self.events.onhover(self)
   end

   if state and tick > last_clicked_tick and self.events.onclick then
      last_clicked_tick = tick
      self.events.onclick(self)
   end
end

---@param width integer?
---@param height integer?
function GUIRoot:DrawRectangle(width, height)
   width = width or self.width
   height = height or self.height
   local px, py = self.parent and self.parent.x or 0, self.parent and self.parent.y or 0
   draw.FilledRect(self.x + px, self.y + py, self.x + width + px, self.y + height + py)
end

---@param width integer?
---@param height integer?
function GUIRoot:DrawOutline(width, height)
   width = width or self.width
   height = height or self.height
   local px, py = self.parent and self.parent.x or 0, self.parent and self.parent.y or 0
   draw.Color(table.unpack(self.outline))
   draw.OutlinedRect(self.x + px, self.y + py, self.x + width + px, self.y + height + py)
end

--- END ROOT

--- START WINDOW

---@class GUIWindow: GUIRoot
---@field children (GUIRoot|GUIButton|GUIText)[]
local Window = {children = {}, vpadding = 5, hpadding = 5, children_gap = 10}
setmetatable(Window, {__index = GUIRoot})

function Window:render()
   --- find the width and height
   local width, height = 0, 0
   local num_children = #self.children

   for i = 1, num_children do
      local child = self.children[i]
      if child then
         width = math.max(width, child.width, child.x + child.width) + self.vpadding
         height = math.max(height, child.height, child.y + child.height) + self.hpadding
      end
   end
   draw.Color(table.unpack(self.background))
   draw.FilledRect(self.x, self.y, self.x + width, self.y + height)

   for i = 1, num_children do
      local child = self.children[i]
      child:render()
   end

   self:CheckInput(nil)
end

---@param child GUIRoot
function Window:AddChild(child)
   child.parent = self -- Set the parent reference
   self.children[#self.children+1] = child
end

function Window:new()
   local new = setmetatable({}, {__index = self})
   new.children = {}
   new.events = {}
   return new
end

--- END WINDOW

--- START BUTTON

---@class GUIButton: GUIRoot
local Button = {text = "", text_color = {0, 0, 0, 255}}
setmetatable(Button, {__index = GUIRoot})

function Button:render()
   draw.SetFont(font)

   local px, py = self.parent and self.parent.x or 0, self.parent and self.parent.y or 0

   local textw, texth = draw.GetTextSize(self.text)
   local middlex, middley = math.floor(self.x + (self.width * 0.5) - (textw * 0.5) + px), math.floor(self.y + (self.height * 0.5) - (texth * 0.5) + py)

   self.width = math.floor(math.max(textw, self.width)) + 10

   --- background
   draw.Color(table.unpack(self.background))
   self:DrawRectangle()

   --- outline
   self:DrawOutline()

   draw.Color(table.unpack(self.text_color))
   draw.TextShadow(middlex, middley, self.text)

   self:CheckInput(self.parent)
end

---@return GUIButton
function Button:new()
   local new = setmetatable({}, {__index = self})
   new.events = {}
   return new
end

--- END BUTTON

--- START TEXT

---@class GUIText: GUIRoot
local Text = {str = "", text_color = {255, 255, 255, 255}, shadow_color = {0, 0, 0, 220}, shadow_voffset = 0, shadow_hoffset = 0}
setmetatable(Text, {__index = GUIRoot})

---@return GUIText
function Text:new()
   local newtext = setmetatable({}, {__index = self})
   newtext.events = {}
   return newtext
end

function Text:render()
   draw.SetFont(font)

   local px, py = self.parent and self.parent.x or 0, self.parent and self.parent.y or 0

   --- shadow
   draw.Color(table.unpack(self.shadow_color))
   draw.Text(self.x + self.shadow_voffset + px, self.y + self.shadow_hoffset + py, self.str)

   draw.SetFont(font)

   --- text
   draw.Color(table.unpack(self.text_color))
   draw.Text(self.x + px, self.y + py, self.str)

   draw.SetFont(font)

   --- setting the text width & height so window can resize correctly
   local textw, texth = draw.GetTextSize(self.str)
   self.width = math.floor(textw)
   self.height = texth
end

--- END TEXT

--- START CHECKBOX

---@class GUICheckbox: GUIRoot
local Checkbox =
{
   text = "",
   text_color = {255, 255, 255, 255},
   checked = false,
   checked_color = {150, 255, 150, 255},
   unchecked_color = {255, 150, 150, 255}
}
setmetatable(Checkbox, {__index = GUIRoot})

---@return GUICheckbox
function Checkbox:new()
   local new = setmetatable({}, {__index = self})
   new.events = {}
   return new
end

function Checkbox:render()
   local px, py = self.parent and self.parent.x or 0, self.parent and self.parent.y or 0
   local gap = 5

   draw.SetFont(font)
   local textw, texth = draw.GetTextSize(self.text)
   local middley = math.floor(self.y + (self.height * 0.5) - (texth * 0.5) + py)

   local boxheight = math.floor(self.height * 0.5)
   local boxwidth = boxheight
   local fakewidth = math.floor(math.max(textw + gap, self.width + gap + boxwidth, textw))

   --- background
   draw.Color(table.unpack(self.background))
   self:DrawRectangle(fakewidth)
   self:DrawOutline(fakewidth)

   draw.Color(table.unpack(self.text_color))
   draw.SetFont(font)
   draw.TextShadow(px + self.x + gap, middley, self.text)

   do --- checkbox button
      local x = px + self.x + fakewidth - boxwidth - gap
      local y = py + math.floor(self.y + (self.height * 0.5) - (boxheight * 0.5))
      local color = self.checked and self.checked_color or self.unchecked_color
      draw.Color(table.unpack(color))
      draw.FilledRect(x, y, x + boxwidth, y + boxheight)
   end

   self:CheckInput(self.parent, fakewidth)
end

--- END CHECKBOX

GUI.Window = Window
GUI.Button = Button
GUI.Text = Text
GUI.Checkbox = Checkbox

return GUI