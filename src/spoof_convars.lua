local clc_RespondCvarValue = 13
local spoofed_cvars = {}
local funcs = {}

---@param msg NetMessage
function funcs.SendNetMsg(msg)
   if (msg:GetType() == clc_RespondCvarValue) then
      local bf = BitBuffer()
      bf:Reset()

      msg:WriteToBitBuffer(bf)
      local result = CLC_RespondCvarValue:ReadFromBitBuffer(bf)
      local cvar = spoofed_cvars[result.cvarName]

      if (cvar) then
         CLC_RespondCvarValue:WriteToBitBuffer(bf, result.cvarName, cvar)
         msg:ReadFromBitBuffer(bf)
      end

      bf:Delete()
   end
   return true
end

--- gb setsvar name value

local function CMD_SpoofConVar(args, num_args)
   if (not args or #args ~= num_args) then return end
   local cvar = tostring(args[1])
   local var = tostring(args[2])
   spoofed_cvars[cvar] = var
   client.SetConVar(cvar, var)
end

GB_GLOBALS.RegisterCommand("spoof->setsvar", "Spoofs a convar to whatever you want the server to see | args: name, new value", 2,  CMD_SpoofConVar)
return funcs