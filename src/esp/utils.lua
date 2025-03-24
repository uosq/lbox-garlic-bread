local utils = {}

local mfloor = math.floor
local mmin = math.min
local mmax = math.max

local classes = {
    [1] = "scout",
    [3] = "soldier",
    [7] = "pyro",
    [4] = "demo",
    [6] = "heavy",
    [9] = "engineer",
    [5] = "medic",
    [2] = "sniper",
    [8] = "spy",
 }

function utils.DrawClass(font, top, class)
    local pos = top
    if pos then
        draw.SetFont(font)
        local str = tostring(classes[class])
        local textw, texth = draw.GetTextSize(str)
        draw.TextShadow(mfloor(pos[1] - textw / 2), mfloor(pos[2] - texth), str)
    end
end

function utils.DrawBuildingClass(font, top, class)
    local pos = top
    if pos then
        draw.SetFont(font)
        local str = tostring(class)

        str = string.gsub(str, "CObject", "")
        str = string.gsub(str, "gun", "")

        local textw, texth = draw.GetTextSize(str)
        draw.TextShadow(mfloor(pos[1] - textw / 2), mfloor(pos[2] - texth), str)
    end
end

function utils.GetHealthColor(currenthealth, maxhealth)
    local healthpercentage = currenthealth / maxhealth
    healthpercentage = mmax(0, mmin(1, healthpercentage))
    local red = 1 - healthpercentage
    local green = healthpercentage
    red = mmax(0, mmin(1, red))
    green = mmax(0, mmin(1, green))
    return mfloor(255 * red), mfloor(255 * green), 0
end

---@param health integer
---@param maxhealth integer
---@param top {[1]: number, [2]: number}
---@param bottom {[1]: number, [2]: number}
---@param left number
---@param h number
function utils.DrawHealthBar(health, maxhealth, top, bottom, left, h, color)
    draw.Color(255, 255, 255, 255)
    local thickness = 1
    local wideness = 6
    local gap = 3

    local x1, y1, x2, y2
    x1 = left - wideness
    y1 = top[2]
    x2 = left - gap
    y2 = bottom[2]

    local percent = health / maxhealth
    percent = percent > 1 and 1 or (percent < 0 and 0 or percent)

    draw.Color(0, 0, 0, 255)
    draw.FilledRect(x1 - thickness, y1 - thickness, x2 + thickness, y2 + thickness)

    local r, g, b

    if color then
        r, g, b = table.unpack(color)
    else
        r, g, b = utils.GetHealthColor(health, maxhealth)
    end

    draw.Color(r, g, b, 255)
    --draw.FilledRect(x1, math.floor(y1 + (h * (1 - percent))), x2, y2)
    draw.FilledRectFade(x1, math.floor(y1 + (h * (1 - percent))), x2, y2, 255, 50, false)
end

---@param health integer
---@param maxhealth integer
---@param top {[1]: number, [2]: number}
---@param bottom {[1]: number, [2]: number}
---@param left number
---@param h number
function utils.DrawOverhealBar(health, maxhealth, maxoverhealhealth, top, bottom, left, h)
    local wideness = 6
    local gap = 3

    local x1, y1, x2, y2
    x1 = left - wideness
    y1 = top[2]
    x2 = left - gap
    y2 = bottom[2]

    local percent = (health - maxhealth) / (maxoverhealhealth - maxhealth)
    percent = percent > 1 and 1 or (percent < 0 and 0 or percent)

    local r, g, b = 0, 255, 255

    draw.Color(r, g, b, 200)
    draw.FilledRect(x1, math.floor(y1 + (h * (1 - percent))), x2, y2)
end

function utils.DrawVerticalHealthBar(health, maxhealth, bottom, left, right)
    local thickness = 1
    local height = 6
    local gap = 3

    local x1, y1, x2, y2
    x1 = left
    y1 = bottom[2] + gap
    x2 = right
    y2 = bottom[2] + height

    local percent = health / maxhealth
    percent = percent > 1 and 1 or (percent < 0 and 0 or percent)

    draw.Color(0, 0, 0, 255)
    draw.FilledRect(x1 - thickness, y1 - thickness, x2 + thickness, y2 + thickness)

    local r, g, b = utils.GetHealthColor(health, maxhealth)
    draw.Color(r, g, b, 255)
    draw.FilledRect(x1, y1, math.floor(x1 + ((right - left) * percent)), y2)
end

return utils
