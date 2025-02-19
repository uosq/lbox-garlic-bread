local NEW_COMMANDS_SIZE = 4
local BACKUP_COMMANDS_SIZE = 3
local MSG_SIZE = 6

local net_SetConVar = 5
local clc_Move = 9

NET_SetConVar = {}
CLC_Move = {}

---@class ConVar
---@field name string # Size 260
---@field value string # Size 260

---@param buffer BitBuffer
---@param convars ConVar[]
function NET_SetConVar:WriteToBitBuffer(buffer, convars)
	buffer:Reset()
	--buffer:WriteInt(net_SetConVar, MSG_SIZE) currently we dont need this

	local numvars = #convars
	buffer:WriteByte(numvars)

	for i = 1, numvars do
		local var = convars[i]
		buffer:WriteString(var.name)
		buffer:WriteString(var.value)
	end

	buffer:SetCurBit(MSG_SIZE)
end

---@param buffer BitBuffer
function NET_SetConVar:ReadFromBitBuffer(buffer)
	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE) --- skip first 6 useless bits of msg:GetType()
	local numvars = buffer:ReadByte()

	---@type ConVar[]
	local convars = {}

	for i = 1, numvars do
		convars[i] = { name = buffer:ReadString(260), value = buffer:ReadString(260) }
	end

	buffer:Reset()
	return convars
end

---@param buffer BitBuffer
---@param new_commands integer
---@param backup_commands integer
function CLC_Move:WriteToBitBuffer(buffer, new_commands, backup_commands)
	buffer:Reset()

	buffer:WriteInt(clc_Move, MSG_SIZE)
	local length = buffer:GetDataBitsLength()

	buffer:WriteInt(new_commands, NEW_COMMANDS_SIZE)
	buffer:WriteInt(backup_commands, BACKUP_COMMANDS_SIZE)
	buffer:WriteInt(length, 16)

	buffer:Reset()
	buffer:SetCurBit(6)
end

---@param buffer BitBuffer
function CLC_Move:ReadFromBitBuffer(buffer)
	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)

	local new_commands, backup_commands, length
	new_commands = buffer:ReadInt(NEW_COMMANDS_SIZE)
	backup_commands = buffer:ReadInt(BACKUP_COMMANDS_SIZE)
	length = buffer:ReadInt(16)

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)
	return { new_commands = new_commands, backup_commands = backup_commands, length = length }
end
