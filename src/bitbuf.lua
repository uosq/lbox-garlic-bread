---@diagnostic disable: duplicate-set-field
---@diagnostic disable: duplicate-doc-field
local MSG_SIZE = 6

CLC_RespondCvarValue = {}

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

callbacks.Register("Unload", "UNLOAD garlic bread bitbuf", function ()
	MSG_SIZE = nil
	CLC_RespondCvarValue = nil
end)