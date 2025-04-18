--- prototype, im not sure if i'll finish this

printc(255, 255, 0, 255, "Your game might lag for a second or two!")

local link = "https://api.github.com/repos/uosq/lbox-garlic-bread/releases"
local json = load(http.Get("https://raw.githubusercontent.com/rxi/json.lua/refs/heads/master/json.lua"))()

local function RunScript(response)
    print("hi")
    local chunk = load(response)
    if chunk then
        local co = coroutine.create(chunk)
        coroutine.resume(co)

        callbacks.Register("Unload", function()
            coroutine.close(co)
        end)
    end
end

---@param response string
local function RunResponse(response)
    local decoded = json.decode(response)
    if decoded then
        local browser_download_url = decoded[1]["assets"][1]["browser_download_url"]
        http.GetAsync(browser_download_url, RunScript)
    end
end

http.GetAsync(link, RunResponse)
