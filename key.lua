local service = 5397 -- Set your Platoboost ID
local secret = "b0e320e6-6ecc-451a-be12-9b72d6a7a89b" -- Set your Platoboost API key
local useNonce = true
local onMessage = function(message)
    game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", { Text = message })
end

repeat task.wait(1) until game:IsLoaded() or game.Players.LocalPlayer

local requestSending = false
local fSetClipboard, fRequest, fStringChar, fToString, fStringSub, fOsTime, fMathRandom, fMathFloor = setclipboard or toclipboard, request or http_request, string.char, tostring, string.sub, os.time, math.random, math.floor

-- ✅ HWID corrigé pour éviter l'erreur SQL
local fGetHwid = function()
    return "User_" .. tostring(game.Players.LocalPlayer.UserId)
end

local cachedLink, cachedTime = "", 0
cachedTime = 0 -- ✅ force refresh à chaque exécution
local HttpService = game:GetService("HttpService")

function lEncode(data)
    return HttpService:JSONEncode(data)
end
function lDecode(data)
    return HttpService:JSONDecode(data)
end

local function lDigest(input)
    local inputStr = tostring(input)
    local hash = {}
    for i = 1, #inputStr do
        table.insert(hash, string.byte(inputStr, i))
    end
    local hashHex = ""
    for _, byte in ipairs(hash) do
        hashHex = hashHex .. string.format("%02x", byte)
    end
    return hashHex
end

local host = "https://api.platoboost.com"
local hostResponse = fRequest({
    Url = host .. "/public/connectivity",
    Method = "GET"
})
if hostResponse.StatusCode ~= 200 or hostResponse.StatusCode ~= 429 then
    host = "https://api.platoboost.net"
end

function cacheLink()
    if cachedTime + (10 * 60) < fOsTime() then
        local response = fRequest({
            Url = host .. "/public/start",
            Method = "POST",
            Body = lEncode({
                service = service,
                identifier = lDigest(fGetHwid())
            }),
            Headers = {
                ["Content-Type"] = "application/json"
            }
        })

        if response.StatusCode == 200 then
            local decoded = lDecode(response.Body)
            if decoded.success == true then
                cachedLink = decoded.data.url
                cachedTime = fOsTime()
                return true, cachedLink
            else
                onMessage(decoded.message)
                return false, decoded.message
            end
        elseif response.StatusCode == 429 then
            local msg = "you are being rate limited, please wait 20 seconds and try again."
            onMessage(msg)
            return false, msg
        end

        local msg = "Failed to cache link."
        onMessage(msg)
        return false, msg
    else
        return true, cachedLink
    end
end

cacheLink()

local generateNonce = function()
    local str = ""
    for _ = 1, 16 do
        str = str .. fStringChar(fMathFloor(fMathRandom() * (122 - 97 + 1)) + 97)
    end
    return str
end

for _ = 1, 5 do
    local oNonce = generateNonce()
    task.wait(0.2)
    if generateNonce() == oNonce then
        local msg = "platoboost nonce error."
        onMessage(msg)
        error(msg)
    end
end

local copyLink = function()
    local success, link = cacheLink()
    if success then
        print("SetClipboard")
        fSetClipboard(link)
    end
end

local redeemKey = function(key)
    local nonce = generateNonce()
    local endpoint = host .. "/public/redeem/" .. fToString(service)

    local body = {
        identifier = lDigest(fGetHwid()),
        key = key
    }

    if useNonce then
        body.nonce = nonce
    end

    local response = fRequest({
        Url = endpoint,
        Method = "POST",
        Body = lEncode(body),
        Headers = {
            ["Content-Type"] = "application/json"
        }
    })

    if response.StatusCode == 200 then
        local decoded = lDecode(response.Body)
        if decoded.success == true then
            if decoded.data.valid == true then
                if useNonce then
                    if decoded.data.hash == lDigest("true" .. "-" .. nonce .. "-" .. secret) then
                        return true
                    else
                        onMessage("failed to verify integrity.")
                        return false
                    end
                else
                    return true
                end
            else
                onMessage("key is invalid.")
                return false
            end
        else
            if fStringSub(decoded.message, 1, 27) == "unique constraint violation" then
                onMessage("you already have an active key, please wait for it to expire before redeeming it.")
                return false
            else
                onMessage(decoded.message)
                return false
            end
        end
    elseif response.StatusCode == 429 then
        onMessage("you are being rate limited, please wait 20 seconds and try again.")
        return false
    else
        onMessage("server returned an invalid status code, please try again later.")
        return false
    end
end

local verifyKey = function(key)
    if requestSending == true then
        onMessage("a request is already being sent, please slow down.")
        return false
    else
        requestSending = true
    end

    local nonce = generateNonce()
    local endpoint = host .. "/public/whitelist/" .. fToString(service) .. "?identifier=" .. lDigest(fGetHwid()) .. "&key=" .. key
    if useNonce then
        endpoint = endpoint .. "&nonce=" .. nonce
    end

    local response = fRequest({
        Url = endpoint,
        Method = "GET"
    })

    requestSending = false

    if response.StatusCode == 200 then
        local decoded = lDecode(response.Body)
        if decoded.success == true then
            if decoded.data.valid == true then
                return true
            else
                if fStringSub(key, 1, 5) == "FREE_" then
                    return redeemKey(key)
                else
                    onMessage("key is invalid.")
                    return false
                end
            end
        else
            onMessage(decoded.message)
            return false
        end
    elseif response.StatusCode == 429 then
        onMessage("you are being rate limited, please wait 20 seconds and try again.")
        return false
    else
        onMessage("server returned an invalid status code, please try again later.")
        return false
    end
end

-- GUI setup
task.spawn(function()
    local ScreenGui = Instance.new("ScreenGui")
    local Frame = Instance.new("Frame")
    local Topbar = Instance.new("Frame")
    local Exit = Instance.new("TextButton")
    local minimize = Instance.new("TextButton")
    local Frame_2 = Instance.new("Frame")
    local Getkey = Instance.new("TextButton")
    local Checkkey = Instance.new("TextButton")
    local TextBox = Instance.new("TextBox")
    local TextLabel = Instance.new("TextLabel")

    ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    Frame.Parent = ScreenGui
    Frame.BackgroundColor3 = Color3.fromRGB(76, 76, 76)
    Frame.Position = UDim2.new(0.286, 0, 0.295, 0)
    Frame.Size = UDim2.new(0, 359, 0, 217)

    Topbar.Name = "Topbar"
    Topbar.Parent = Frame
    Topbar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Topbar.Size = UDim2.new(0, 359, 0, 27)

    Exit.Name = "Exit"
    Exit.Parent = Topbar
    Exit.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    Exit.Position = UDim2.new(0.91, 0, 0.1, 0)
    Exit.Size = UDim2.new(0, 25, 0, 20)
    Exit.Text = "X"

    minimize.Name = "minimize"
    minimize.Parent = Topbar
    minimize.BackgroundColor3 = Color3.fromRGB(85, 255, 0)
    minimize.Position = UDim2.new(0.81, 0, 0.1, 0)
    minimize.Size = UDim2.new(0, 25, 0, 20)
    minimize.Text = "-"

    Frame_2.Parent = Frame
    Frame_2.BackgroundTransparency = 1.000
    Frame_2.Position = UDim2.new(0, 0, 0.124, 0)
    Frame_2.Size = UDim2.new(0, 359, 0, 189)

    Getkey.Name = "Getkey"
    Getkey.Parent = Frame_2
    Getkey.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Getkey.Position = UDim2.new(0.317, 0, 0.524, 0)
    Getkey.Size = UDim2.new(0, 130, 0, 32)
    Getkey.Text = "Getkey"

    Checkkey.Name = "Checkkey"
    Checkkey.Parent = Frame_2
    Checkkey.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Checkkey.Position = UDim2.new(0.317, 0, 0.767, 0)
    Checkkey.Size = UDim2.new(0, 130, 0, 32)
    Checkkey.Text = "CheckKey"

    TextBox.Parent = Frame_2
    TextBox.BackgroundColor3 = Color3.fromRGB(139, 139, 139)
    TextBox.BackgroundTransparency = 0.6
    TextBox.Position = UDim2.new(0.078, 0, 0.138, 0)
    TextBox.Size = UDim2.new(0, 304, 0, 42)
    TextBox.Text = ""

    TextLabel.Parent = Frame_2
    TextLabel.BackgroundTransparency = 1.000
    TextLabel.Position = UDim2.new(0.078, 0, 0.138, 0)
    TextLabel.Size = UDim2.new(0, 304, 0, 42)
    TextLabel.Text = "In Put Your Key"
    TextLabel.TextTransparency = 0.55

    TextBox:GetPropertyChangedSignal("Text"):Connect(function()
        if TextBox.Text == "" then
            TextLabel.Text = "In Put Your Key"
        else
            TextLabel.Text = TextBox.Text
        end
    end)

    Checkkey.MouseButton1Down:Connect(function()
        if TextBox and TextBox.Text then
            local Verify = verifyKey(TextBox.Text)
            if Verify then
                loadstring(game:HttpGet("https://raw.githubusercontent.com/xxilow/Leyzo-HUB/refs/heads/main/menu.lua"))()
            else
                print("Key is invalid")
            end
        end
    end)

    Getkey.MouseButton1Down:Connect(function()
        copyLink()
    end)

    Exit.MouseButton1Down:Connect(function()
        ScreenGui:Destroy()
    end)

    minimize.MouseButton1Down:Connect(function()
        ScreenGui.Enabled = false
    end)
end)
