local service = 5397 -- Platoboost Service ID
local secret = "b0e320e6-6ecc-451a-be12-9b72d6a7a89b" -- Platoboost API secret
local useNonce = true

local premiumProxy = "https://platoboost-proxy.vercel.app/api/premium-key"

local onMessage = function(message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", { Text = message })
    end)
end

-- Attente sécurisée du chargement du jeu et de LocalPlayer
repeat task.wait(1) until game:IsLoaded()

local PlayersService = game:FindFirstChildOfClass("Players")
local localPlayer = PlayersService and PlayersService.LocalPlayer

if not localPlayer then
    onMessage("Erreur : LocalPlayer introuvable.")
    return
end

local requestSending = false
local fSetClipboard = setclipboard or toclipboard
local fRequest = request or http_request
local fStringChar = string.char
local fToString = tostring
local fStringSub = string.sub
local fOsTime = os.time
local fMathRandom = math.random
local fMathFloor = math.floor

local fGetHwid = function()
    return "User_" .. tostring(localPlayer.UserId)
end

local cachedLink, cachedTime = "", 0
local HttpService = game:GetService("HttpService")

function lEncode(data) return HttpService:JSONEncode(data) end
function lDecode(data) return HttpService:JSONDecode(data) end

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
local response = fRequest({ Url = host .. "/public/connectivity", Method = "GET" })
if response.StatusCode ~= 200 and response.StatusCode ~= 429 then
    host = "https://api.platoboost.net"
end

function cacheLink()
    if cachedTime + (10 * 60) < fOsTime() then
        local response = fRequest({
            Url = host .. "/public/start",
            Method = "POST",
            Body = lEncode({ service = service, identifier = lDigest(fGetHwid()) }),
            Headers = { ["Content-Type"] = "application/json" }
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
            local msg = "Rate limited, wait 20 sec."
            onMessage(msg)
            return false, msg
        end
        local msg = "Cache failed."
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

local copyLink = function()
    local success, link = cacheLink()
    if success then
        pcall(function()
            fSetClipboard(link)
        end)
    end
end

local function fetchPremiumKey()
    local response = fRequest({
        Url = premiumProxy .. "?identifier=" .. lDigest(fGetHwid()),
        Method = "GET"
    })
    if response.StatusCode == 200 then
        local decoded = lDecode(response.Body)
        if decoded.success and decoded.key then
            pcall(function()
                fSetClipboard(decoded.key)
            end)
            onMessage("Premium key copied!")
        else
            onMessage("Failed to fetch premium key.")
        end
    else
        onMessage("Error contacting premium proxy.")
    end
end

local redeemKey = function(key)
    local nonce = generateNonce()
    local endpoint = host .. "/public/redeem/" .. fToString(service)
    local body = { identifier = lDigest(fGetHwid()), key = key }
    if useNonce then
        body.nonce = nonce
    end
    local response = fRequest({
        Url = endpoint,
        Method = "POST",
        Body = lEncode(body),
        Headers = { ["Content-Type"] = "application/json" }
    })
    if response.StatusCode == 200 then
        local decoded = lDecode(response.Body)
        if decoded.success and decoded.data.valid then
            if not useNonce or decoded.data.hash == lDigest("true" .. "-" .. nonce .. "-" .. secret) then
                return true
            else
                onMessage("Integrity check failed.")
                return false
            end
        else
            onMessage("Invalid key.")
            return false
        end
    elseif response.StatusCode == 429 then
        onMessage("Rate limited.")
        return false
    else
        onMessage("Server error.")
        return false
    end
end

local verifyKey = function(key)
    if requestSending then
        onMessage("Wait...")
        return false
    else
        requestSending = true
    end
    local nonce = generateNonce()
    local endpoint = host .. "/public/whitelist/" .. service .. "?identifier=" .. lDigest(fGetHwid()) .. "&key=" .. key
    if useNonce then
        endpoint = endpoint .. "&nonce=" .. nonce
    end
    local response = fRequest({ Url = endpoint, Method = "GET" })
    requestSending = false
    if response.StatusCode == 200 then
        local decoded = lDecode(response.Body)
        if decoded.success and decoded.data.valid then
            return true
        elseif fStringSub(key, 1, 5) == "FREE_" or fStringSub(key, 1, 4) == "KEY_" then
            return redeemKey(key)
        else
            onMessage("Key invalid")
            return false
        end
    else
        onMessage("Check failed")
        return false
    end
end

-- GUI Setup
task.spawn(function()
    local gui = Instance.new("ScreenGui")
    gui.Name = "KeyGui"
    gui.ResetOnSpawn = false
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 300, 0, 180)
    frame.Position = UDim2.new(0.35, 0, 0.35, 0)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.Parent = gui

    local keyBox = Instance.new("TextBox")
    keyBox.PlaceholderText = "Enter key..."
    keyBox.Size = UDim2.new(0.8, 0, 0, 30)
    keyBox.Position = UDim2.new(0.1, 0, 0.2, 0)
    keyBox.Parent = frame

    local checkBtn = Instance.new("TextButton")
    checkBtn.Text = "CheckKey"
    checkBtn.Size = UDim2.new(0.35, 0, 0, 30)
    checkBtn.Position = UDim2.new(0.1, 0, 0.5, 0)
    checkBtn.Parent = frame
    checkBtn.MouseButton1Click:Connect(function()
        local k = keyBox.Text
        if verifyKey(k) then
            loadstring(game:HttpGet("https://raw.githubusercontent.com/xxilow/Leyzo-HUB/refs/heads/main/menu.lua"))()
        else
            onMessage("Key failed")
        end
    end)

    local getBtn = Instance.new("TextButton")
    getBtn.Text = "GetKey"
    getBtn.Size = UDim2.new(0.35, 0, 0, 30)
    getBtn.Position = UDim2.new(0.55, 0, 0.5, 0)
    getBtn.Parent = frame
    getBtn.MouseButton1Click:Connect(copyLink)

    local premBtn = Instance.new("TextButton")
    premBtn.Text = "GetPremiumKey"
    premBtn.Size = UDim2.new(0.8, 0, 0, 30)
    premBtn.Position = UDim2.new(0.1, 0, 0.75, 0)
    premBtn.Parent = frame
    premBtn.MouseButton1Click:Connect(function()
        local success, err = pcall(function()
            setclipboard("https://discord.gg/QcZv3DT8Kj")
        end)
        if success then
            onMessage("Lien Discord copié dans le presse-papiers ! Ouvre-le dans ton navigateur.")
        else
            onMessage("Impossible de copier le lien.")
        end
    end)

    local reduceBtn = Instance.new("TextButton")
    reduceBtn.Text = "-"
    reduceBtn.Size = UDim2.new(0, 30, 0, 30)
    reduceBtn.Position = UDim2.new(1, -35, 0, 5)
    reduceBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    reduceBtn.TextColor3 = Color3.new(1, 1, 1)
    reduceBtn.Parent = frame
    reduceBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
end)
