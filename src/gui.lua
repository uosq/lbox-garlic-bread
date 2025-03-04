GUI = {}

---@class GUIRoot
local root = {
   m_vecPosition = Vector3(),
   m_Size = {m_width = 0, m_height = 0},
   m_Background = {20, 20, 20, 255},
   m_Outline = {m_thickness = 1, m_color = {150, 150, 255, 255}},
   m_nChildGap = 0,

   events = {
      mouseclick = nil,
      mousehover = nil,
   },

   m_sType = "root",
}
setmetatable(root, {__index = root})

function root:IsMouseInside()
   local mousePos = input:GetMousePos()
   local x, y = mousePos[1] + self.m_nChildGap, mousePos[2] + self.m_nChildGap
   return x >= self.m_vecPosition.x and x <= self.m_vecPosition.x + self.m_Size.m_width
   and y >= self.m_vecPosition.y and y <= self.m_vecPosition.y + self.m_Size.m_height
end

function root:DrawRectangle(x, y, width, height)
   draw.FilledRect(x, y, x + width, y + height)
end

function root:new()
   local new_element = {}
   setmetatable(new_element, {__index = self})
   return new_element
end

---@return string
local function ToString(this)
   return this.m_sType
end

---@class GUIWindow: GUIRoot
local window = {
   m_Children = {},
   m_nPadding = 10,
   m_Background = {255, 255, 255, 255},
   m_vecPosition = Vector3(50, 50, 0),
   m_sType = "window"
}
setmetatable(window, {__index = root, __tostring = ToString})

function window:Render()
   local height = 0
   local width = 0

   ---@param child GUIRoot
   for _, child in pairs(self.m_Children) do
      height = height + child.m_Size.m_height + child.m_vecPosition.y + self.m_nPadding
      width = width > child.m_Size.m_width + child.m_nChildGap and width or child.m_Size.m_width + child.m_nChildGap
   end

   print(string.format("width: %s, height: %s", width, height))

   local x, y = self.m_vecPosition:Unpack()
   draw.Color(table.unpack(self.m_Background))
   self:DrawRectangle(x, y, width, height)

   for i = 1, #self.m_Children do
      local child = self.m_Children[i]
      child:Render()
   end
end

function window:AddChild(child)
   self.m_Children[#self.m_Children+1] = child
end

---@class GUIButton: GUIRoot
---@field m_Text string
---@field parent GUIWindow?
local button = {m_Text = "lorem ipsum", m_Background = {0, 0, 0, 100}}
setmetatable(button, {__index = root, __tostring = ToString})

function button:IsMouseInside()
   local mousePos = input:GetMousePos()
   local x, y = mousePos[1], mousePos[2]
   return x >= self.m_vecPosition.x + self.m_nChildGap and x <= self.m_vecPosition.x + self.m_Size.m_width - self.m_nChildGap + window.m_vecPosition.x
   and y >= self.m_vecPosition.y + self.m_nChildGap + window.m_vecPosition.x and y <= self.m_vecPosition.y + self.m_Size.m_height + window.m_vecPosition.y
end

function button:Render()
   local x, y = (window.m_vecPosition + self.m_vecPosition):Unpack()
   local width, height = self.m_Size.m_width, self.m_Size.m_height
   local WHITE = {255, 255, 255, 255}
   local color = self:IsMouseInside() == true and self.m_Background or WHITE
   draw.Color(table.unpack(color))
   self:DrawRectangle(x, y, width, height)
end

function window.AddButton(text, x, y, width, height)
   ---@type GUIButton
   local newbutton = button:new()
   newbutton.m_vecPosition = Vector3(x, y)
   newbutton.m_Size.m_width = width
   newbutton.m_Size.m_height = height
   newbutton.m_Text = text
   window:AddChild(newbutton)
end

function GUI.Draw()
   window:Render()
end

function GUI.unload()
   window, root = nil, nil
   callbacks.Unregister("Draw", "DRAW garlic bread gui")
end

GUI.Window = window
GUI.Button = button

window.AddButton("hi", 15, 0, 50, 20)

callbacks.Register("Draw", "DRAW garlic bread gui", GUI.Draw)
return GUI