local binds = {
   key_press = {
      --[[
      {
         key = E_ButtonCode.KEY_R,
         command = "visuals->toggle_thirdperson, chams->material textured, ...",
         id = #binds.key_press+1
      }
      ]]
   },
   class_change = {
      --[[
      {
         class = selected_class (9 engineer, eggsample),
         command = "dgfiogjdifjg"
      }
      ]]
   }
}

local last_pressed_button_tick = 0
local last_id = 0

local classes = {
   scout = 1,
   soldier = 3,
   pyro = 7,
   demo = 4,
   heavy = 6,
   engineer = 9,
   medic = 5,
   sniper = 2,
   spy = 8,
}

local function RunCommand(text)
   GB_GLOBALS.RunCommand("gb " .. text)
end

---@param usercmd UserCmd
local function CreateMove(usercmd)
   for _, bind in pairs(binds.key_press) do
      local key = bind.key
      local command = bind.command

      local state, tick = input.IsButtonPressed(key)
      if command and state and tick > last_pressed_button_tick then
         RunCommand(command)
         last_pressed_button_tick = tick
      end
   end
end

---@param event GameEvent
local function FireGameEvent(event)
   if event:GetName() == "player_changeclass" then
      local userid = event:GetInt("userid")
      local class = event:GetInt("class")
      if userid and class then
         local playerinfo = client.GetPlayerInfo(client.GetLocalPlayerIndex())
         if not playerinfo then return end
         if not playerinfo.UserID == userid then return end

         for _, bind in pairs(binds.class_change) do
            local selected_class, command = bind.class, bind.command
            if selected_class == class then
               RunCommand(command)
            end
         end
      end
   end
end

local function MakeKPBind(words)
   local key = table.remove(words, 1)
   local selected_key = E_ButtonCode["KEY_" .. string.upper(key)]
   local command = table.concat(words, " ")
   local id = last_id + 1
   local new_bind = {
      key = selected_key,
      key_str = key,
      command = command,
      id = id,
   }
   binds.key_press[#binds.key_press + 1] = new_bind
   last_id = id
end

local function MakeClassBind(words)
   local class = table.remove(words, 1)
   local selected_class = classes[tostring(class)]
   local command = table.concat(words)
   local id = last_id + 1
   local new_bind = {
      class = selected_class,
      class_str = class,
      command = command,
      id = id
   }
   binds.class_change[#binds.class_change + 1] = new_bind
   last_id = id
end

--- gb binds->create event name what it does
--- example: gb binds->create kp R visuals->toggle_thirdperson
--- only supports 1 command per bind :(
--- TODO: improve it
local function CMD_CreateBind(args, num_args, whole_string)
   if not args then return end
   local words = {}
   for word in string.gmatch(whole_string, "%S+") do
      words[#words + 1] = word
   end

   local bindtype = table.remove(words, 1)
   if bindtype == "kp" then
      MakeKPBind(words)
   elseif bindtype == "class" then
      MakeClassBind(words)
   end
end

local function CMD_GetAllBindIDs()
   printc(150, 255, 150, 255, "Binds:")

   for _, bind in pairs(binds.key_press) do
      local unformatted_str = "id: %s | key: %s | command: %s"
      local str = string.format(unformatted_str, bind.id, bind.key_str, bind.command)
      printc(255, 255, 255, 255, str)
   end

   for _, bind in pairs(binds.class_change) do
      local unformatted_str = "Id: %s | class: %s | command: %s"
      local str = string.format(unformatted_str, bind.id, bind.class_str, bind.command)
      printc(255, 255, 255, 255, str)
   end
end

local function CMD_RemoveBind(args, num_args)
   if (not args or #args ~= num_args) then return end
   local id = tonumber(args[1])
   if id then
      for _, bindtype in pairs(binds) do
         for i, bind in ipairs(bindtype) do
            if bind.id == id then
               table.remove(bindtype, i)
               printc(150, 255, 150, 255, "Removed bind successfully!")
               break
            end
         end
      end
   end
end

GB_GLOBALS.RegisterCommand("binds->create", "Creates a new bind", -1, CMD_CreateBind)
GB_GLOBALS.RegisterCommand("binds->getall", "Prints all bind IDs and their commands", 0, CMD_GetAllBindIDs)
GB_GLOBALS.RegisterCommand("binds->remove", "Removes a bind using a id | args: id (number)", 1, CMD_RemoveBind)

local req = {}

req.CreateMove = CreateMove
req.FireGameEvent = FireGameEvent

function req.unload()
   req = nil
   binds = nil
   last_pressed_button_tick = nil
   last_id = nil
   classes = nil
end

return req
