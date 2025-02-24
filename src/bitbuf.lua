---@diagnostic disable: duplicate-set-field
---@diagnostic disable: duplicate-doc-field
local NEW_COMMANDS_SIZE = 4
local BACKUP_COMMANDS_SIZE = 3
local MSG_SIZE = 6
local WORD_SIZE = 16

--local net_SetConVar = 5
local clc_Move = 9

NET_SetConVar = {}
CLC_Move = {}
CLC_RespondCvarValue = {}

---@class ConVar
---@field name string # size 260
---@field value string # size 260

---@param buffer BitBuffer
---@param convars ConVar[]
function NET_SetConVar:WriteToBitBuffer(buffer, convars)
	buffer:Reset()
	--buffer:WriteInt(net_SetConVar, MSG_SIZE) we currently dont need this

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
	buffer:SetCurBit(MSG_SIZE)
	return convars
end

---@param buffer BitBuffer
---@param new_commands integer
---@param backup_commands integer
function CLC_Move:WriteToBitBuffer(buffer, new_commands, backup_commands)
	buffer:Reset()

	-- im not sure if we need to add the message type, but just in case its there
	buffer:WriteInt(clc_Move, MSG_SIZE)
	local length = buffer:GetDataBitsLength()

	buffer:WriteInt(new_commands, NEW_COMMANDS_SIZE) --- m_nNewCommands
	buffer:WriteInt(backup_commands, BACKUP_COMMANDS_SIZE) --- m_nBackupCommands
	buffer:WriteInt(length, WORD_SIZE) --- m_nLength

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE) --- skip msg type
end

---@param buffer BitBuffer
function CLC_Move:ReadFromBitBuffer(buffer)
	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)

	local new_commands, backup_commands, length
	new_commands = buffer:ReadInt(NEW_COMMANDS_SIZE)
	backup_commands = buffer:ReadInt(BACKUP_COMMANDS_SIZE)
	length = buffer:ReadInt(WORD_SIZE)

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)
	return { new_commands = new_commands, backup_commands = backup_commands, length = length }
end

---@param buffer BitBuffer
function CLC_RespondCvarValue:ReadFromBitBuffer(buffer)
	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)

	local m_iCookie = buffer:ReadInt(32)
	local m_eStatusCode = buffer:ReadInt(4) --- isnt this just a byte?
	local cvarName, cvarEndPos = buffer:ReadString(32)

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)
	return {m_iCookie = m_iCookie, m_eStatusCode = m_eStatusCode, cvarName = cvarName, cvarEndPos = cvarEndPos}
end

---@param buffer BitBuffer
---@param cvarName string
---@param cvarValue string
function CLC_RespondCvarValue:WriteToBitBuffer(buffer, cvarName, cvarValue)
	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)

	--- skip cookie, we dont care about it :(
	buffer:ReadInt(32) --- m_iCookie
	local _, statusEndPos = buffer:ReadInt(4) --- m_eStatusCode

	local _, cvarNameEndPos = buffer:ReadString(32)

	buffer:SetCurBit(statusEndPos)
	buffer:WriteString(cvarName)

	buffer:SetCurBit(cvarNameEndPos)
	buffer:WriteString(cvarValue)

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)
end