local service = 5397 -- Platoboost Service ID
local secret = "b0e320e6-6ecc-451a-be12-9b72d6a7a89b"
local useNonce = true
local premiumProxy = "https://platoboost-proxy.vercel.app/api/premium-key"

local HttpService = game:GetService("HttpService")
local fSetClipboard = setclipboard or toclipboard
local fRequest = request or http_request
local fStringChar = string.char
local fToString = tostring
local fStringSub = string.sub
local fOsTime = os.time
local fMathRandom = math.random
local fMathFloor = math.floor

-- Utilise CoreGui pour éviter les problèmes avec PlayerGui
local successGui, CoreGui = pcall(function() return game:GetService("CoreGui") end)
if not successGui or not CoreGui then
    warn("Impossible d'accéder à CoreGui. Script arrêté.")
    return
end

-- Vérifie si Players et LocalPlayer sont disponibles
local Players = game:FindFirstChildOfClass("Players")
local localPlayer = Players and Players:FindFirstChildWhichIsA("Player") or nil

local function onMessage(message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", { Text = message })
    end)
end

local function lEncode(data) return HttpService:JSONEncode(data) end
local function lDecode(data) return HttpService:JSONDecode(data) end

local function lDigest(input)
    local inputStr = tostring(input)
    local hash = {}
    for i = 1, #inputStr do table.insert(hash, string.byte(inputStr, i)) end
    local hashHex = ""
    for _, byte in ipairs(hash) do hashHex = hashHex .. string.format("%02x", byte) end
    return hashHex
end

local function fGetHwid()
    return localPlayer and "User_" .. tostring(localPlayer.UserId) or "User_Unknown"
end

-- Connexion API Platoboost
local host = "https://api.platoboost.com"
local try = fRequest({ Url = host .. "/public/connectivity", Method = "GET" })
if try.StatusCode ~= 200 and try.StatusCode ~= 429 then
    host = "https://api.platoboost.net"
end

-- Cache de lien
local cachedLink, cachedTime = "", 0
local function cacheLink()
    if cachedTime + (10 * 60) < fOsTime() then
        local res = fRequest({
            Url = host .. "/public/start",
            Method = "POST",
            Body = lEncode({ service = service, identifier = lDigest(fGetHwid()) }),
            Headers = { ["Content-Type"] = "application/json" }
        })
        if res.StatusCode == 200 then
            local decoded = lDecode(res.Body)
            if decoded.success then
                cachedLink = decoded.data.url
                cachedTime = fOsTime()
                return true, cachedLink
            else
                onMessage(decoded.message)
                return false, decoded.message
            end
        elseif res.StatusCode == 429 then
            onMessage("Rate limited, wait 20 sec.")
            return false, "Rate limited"
        end
        onMessage("Cache failed.")
        return false, "Failed"
    else
        return true, cachedLink
    end
end

local function generateNonce()
    local str = ""
    for _ = 1, 16 do
        str = str .. fStringChar(fMathFloor(fMathRandom() * (122 - 97 + 1)) + 97)
    end
    return str
end

local function copyLink()
    local success, link = cacheLink()
    if success then pcall(function() fSetClipboard(link) end) end
end

local function fetchPremiumKey()
    local res = fRequest({
        Url = premiumProxy .. "?identifier=" .. lDigest(fGetHwid()),
        Method = "GET"
    })
    if res.StatusCode == 200 then
        local decoded = lDecode(res.Body)
        if decoded.success and decoded.key then
            pcall(function() fSetClipboard(decoded.key) end)
            onMessage("Premium key copied!")
        else
            onMessage("Failed to fetch premium key.")
        end
    else
        onMessage("Error contacting premium proxy.")
    end
end

local function redeemKey(key)
    local nonce = generateNonce()
    local endpoint = host .. "/public/redeem/" .. fToString(service)
    local body = { identifier = lDigest(fGetHwid()), key = key }
    if useNonce then body.nonce = nonce end
    local res = fRequest({
        Url = endpoint,
        Method = "POST",
        Body = lEncode(body),
        Headers = { ["Content-Type"] = "application/json" }
    })
    if res.StatusCode == 200 then
        local decoded = lDecode(res.Body)
        if decoded.success and decoded.data.valid then
            if not useNonce or decoded.data.hash == lDigest("true" .. "-" .. nonce .. "-" .. secret) then
                return true
            else
                onMessage("Integrity check failed.")
            end
        else
            onMessage("Invalid key.")
        end
    elseif res.StatusCode == 429 then
        onMessage("Rate limited.")
    else
        onMessage("Server error.")
    end
    return false
end

local requestSending = false
local function verifyKey(key)
    if requestSending then
        onMessage("Wait...")
        return false
    end
    requestSending = true
    local nonce = generateNonce()
    local endpoint = host .. "/public/whitelist/" .. service .. "?identifier=" .. lDigest(fGetHwid()) .. "&key=" .. key
    if useNonce then endpoint = endpoint .. "&nonce=" .. nonce end
    local res = fRequest({ Url = endpoint, Method = "GET" })
    requestSending = false
    if res.StatusCode == 200 then
        local decoded = lDecode(res.Body)
        if decoded.success and decoded.data.valid then
            return true
        elseif fStringSub(key, 1, 5) == "FREE_" or fStringSub(key, 1, 4) == "KEY_" then
            return redeemKey(key)
        else
            onMessage("Key invalid")
        end
    else
        onMessage("Check failed")
    end
    return false
end

-- GUI
task.spawn(function()
    local gui = Instance.new("ScreenGui")
    gui.Name = "KeyGui"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui

    local frame = Instance.new("Frame", gui)
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 300, 0, 180)
    frame.Position = UDim2.new(0.35, 0, 0.35, 0)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)

    local keyBox = Instance.new("TextBox", frame)
    keyBox.PlaceholderText = "Enter key..."
    keyBox.Size = UDim2.new(0.8, 0, 0, 30)
    keyBox.Position = UDim2.new(0.1, 0, 0.2, 0)

    local checkBtn = Instance.new("TextButton", frame)
    checkBtn.Text = "CheckKey"
    checkBtn.Size = UDim2.new(0.35, 0, 0, 30)
    checkBtn.Position = UDim2.new(0.1, 0, 0.5, 0)
    checkBtn.MouseButton1Click:Connect(function()
        local k = keyBox.Text
        if verifyKey(k) then
            loadstring(game:HttpGet("https://raw.githubusercontent.com/xxilow/Leyzo-HUB/refs/heads/main/menu.lua"))()
        else
            onMessage("Key failed")
        end
    end)

    local getBtn = Instance.new("TextButton", frame)
    getBtn.Text = "GetKey"
    getBtn.Size = UDim2.new(0.35, 0, 0, 30)
    getBtn.Position = UDim2.new(0.55, 0, 0.5, 0)
    getBtn.MouseButton1Click:Connect(copyLink)

    local premBtn = Instance.new("TextButton", frame)
    premBtn.Text = "GetPremiumKey"
    premBtn.Size = UDim2.new(0.8, 0, 0, 30)
    premBtn.Position = UDim2.new(0.1, 0, 0.75, 0)
    premBtn.MouseButton1Click:Connect(function()
        local success = pcall(function()
            setclipboard("https://discord.gg/QcZv3DT8Kj")
        end)
        if success then
            onMessage("Lien Discord copié dans le presse-papiers ! Ouvre-le dans ton navigateur.")
        else
            onMessage("Impossible de copier le lien.")
        end
    end)

    local reduceBtn = Instance.new("TextButton", frame)
    reduceBtn.Text = "-"
    reduceBtn.Size = UDim2.new(0, 30, 0, 30)
    reduceBtn.Position = UDim2.new(1, -35, 0, 5)
    reduceBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    reduceBtn.TextColor3 = Color3.new(1, 1, 1)
    reduceBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
end)
