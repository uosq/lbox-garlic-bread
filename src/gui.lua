local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "gui: GB_GLOBALS is nil!")
assert(gb_settings, "gui: GB_SETTINGS is nil!")

---@diagnostic disable: assign-type-mismatch
local lib = require("src.gui utils")

-- Create a window instance
local window = lib.Window:new()
window.x = 1920/2
window.y = 0
window.background = {0, 0, 0, 200}

local title = lib.Text:new()
title.x = 27
title.y = 5
title.str = "Garlic Bread"
title.shadow_color = {150, 150, 255, 100}
title.shadow_voffset = 3
title.shadow_hoffset = 1
title.parent = window
window:AddChild(title)

local lasty = window.y + title.y + 16

--- toggles
for key, option in pairs (gb_settings.aimbot) do
   if type(option) == "boolean" then
      local button = lib.Checkbox:new()
      button.x = 2
      button.y = lasty
      button.background = {40, 40, 40, 255}
      button.outline = {255, 255, 255, 255}
      button.parent = window
      button.width = 180
      button.height = 26
      button.text = key
      button.text_color = {255, 255, 255, 255}
      button.checked = option
      button.events.onclick = function()
         gb_settings.aimbot[key] = not gb_settings.aimbot[key]
         button.checked = gb_settings.aimbot[key]
      end

      window:AddChild(button)
      lasty = lasty + button.height + window.children_gap
   end
end

local GUI = {}

function GUI.Draw()
   window:render()
end

function GUI.unload()
   window = nil
   title = nil
   lib = nil
end

return GUI