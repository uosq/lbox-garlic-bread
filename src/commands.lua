local m_commands = {}
local m_prefix = "gb"

callbacks.Register("Unload", "UNLOAD garlic bread commands", function ()
	m_prefix = nil
	m_commands = nil
	callbacks.Unregister("SendStringCmd", "SSC garlic bread console commands")
end)

--- If no additional param other than cmdname, the command has no args
---@param cmdname string
---@param help string
---@param num_args integer
---@param func function?
local function RegisterCommand(cmdname, help, num_args, func)
	m_commands[cmdname] = {func = func, help = help, num_args = num_args}
end

---@param text string
local function RunCommand(text)
	local words = {}
	for word in string.gmatch(text, "%S+") do
		words[#words + 1] = word
	end

	if (words[1] ~= m_prefix) then return end
	--- remove prefix
	table.remove(words, 1)

	if (m_commands[words[1]]) then
		local command = m_commands[words[1]]
		table.remove(words, 1)

		local func = command.func
		assert(type(func) == "function", "SendStringCmd -> command.func is not a function! wtf")

		local num_args = command.num_args
		assert(type(num_args) == "number", "SendStringCmd -> command.num_args is not a number! wtf")

		local args = {}
		if num_args >= 1 then
			for i = 1, num_args do
				local arg = tostring(words[i])
				args[i] = arg
			end
		end

		local whole_string = table.concat(words, " ")
		func(args, num_args, whole_string)
	else
		printc(171, 160, 2, 255, "Invalid option! Use 'gb help' if you want to know the correct name")
		return false
	end
	return true
end

---@param cmd StringCmd
local function SendStringCmd(cmd)
	local sent_command = cmd:Get()
	if RunCommand(sent_command) then
		cmd:Set("")
	end
end

local function print_help()
	printc(255, 150, 150, 255, "Stac is " .. (GB_GLOBALS.bIsStacRunning and "detected" or "not running") .. " in this server")
	printc(255, 255, 255, 255, "The commands are:")

	for name, props in pairs (m_commands) do
		local str = "%s : %s"
		printc(200, 200, 200, 200, string.format(str, name, props.help))
	end
end

RegisterCommand("help", "prints all command's description and usage", 0, print_help)

GB_GLOBALS.RegisterCommand = RegisterCommand
GB_GLOBALS.RunCommand = RunCommand

callbacks.Unregister("SendStringCmd", "SSC garlic bread console commands")
callbacks.Register("SendStringCmd", "SSC garlic bread console commands", SendStringCmd)