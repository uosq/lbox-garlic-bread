local setvar = "setvar"
local getvars = "getvars"

---@param cmd StringCmd
local function SendStringCmd(cmd)
	if not GB_GLOBALS then
		return
	end
	local sent_command = cmd:Get()
	if sent_command:find(setvar) then
		local words = {}
		for word in string.gmatch(sent_command, "%S+") do
			words[#words + 1] = word
		end

		table.remove(words, 1)
		local var = table.remove(words, 1)

		if GB_GLOBALS[var] == nil then
			cmd:Set("echo Couldnt find var!")
			return
		elseif type(GB_GLOBALS[var]) == "function" then
			GB_GLOBALS[var]()
			cmd:Set("")
			return
		end

		local value = table.remove(words, 1)

		if value == "true" then
			value = true
		elseif value == "false" then
			value = false
		elseif string.find(var, "ang") or string.find(var, "vec") then --- assume its a EulerAngles or Vector3
			local mode = string.find(var, "ang") and "euler" or "vec"
			local x, y, z = table.remove(words, 1), table.remove(words, 1), table.remove(words, 1)
			x, y, z = tonumber(x), tonumber(y), tonumber(z)
			if mode == "vector" then
				value = Vector3(x, y, z)
			elseif mode == "euler" then
				value = EulerAngles(x, y, z)
			end
		else
			value = tonumber(value)
		end

		GB_GLOBALS[var] = value

		cmd:Set("")
	elseif sent_command:find(getvars) then
		for name, value in pairs(GB_GLOBALS) do
			printc(255, 255, 255, 255, name .. " = " .. tostring(value))
		end
		cmd:Set("")
	end
end

printc(
	200,
	255,
	200,
	255,
	"Guide on how to use the commands",
	"setvar -> sets the variable",
	"getvars -> prints all the variables here",
	" ",
	"example:",
	"setvar m_bNoRecoil false",
	"setvar m_vecShootPos vector 200 150 690",
	"setvar m_angViewAngles euler 420 159 69",
	" ",
	"you can run a function by just putting their name",
	"like this: setvar toggle_real_yaw"
)

callbacks.Register("SendStringCmd", "SSC garlic bread console commands", SendStringCmd)
