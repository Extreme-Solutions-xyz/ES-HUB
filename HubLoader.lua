-- ██████████████████████████████████████████████████████
--           Extreme Solutions | Script Hub
--                   Hub Loader v1
--        Key System  ·  Game Detection  ·  Auto Load
-- ██████████████████████████████████████████████████████

-- ══════════════════════════════════════════════════════
--  HUB CONFIG  ← Edit these values for your setup
-- ══════════════════════════════════════════════════════

local CONFIG = {
    -- Your Railway-deployed API base URL (no trailing slash)
    -- e.g. "https://extremesolutions-keysystem.up.railway.app"
    APIBaseURL = "https://extremesolutionskeysystem-production.up.railway.app",

    --[[
        Fallback: add valid keys here for offline testing only.
        Leave empty ({}) in production — server validation is used.
    --]]
    OfflineKeys = {
        -- "ES-TEST-ABCD-1234-5678",
    },

    -- Store / key purchase link shown in the GUI
    StoreURL = "https://extremesolutions.xyz",

    -- Discord invite shown in the GUI
    DiscordURL = "https://discord.gg/yourserver",

    -- Hub version shown in the GUI
    Version = "v1.0",
}

-- ══════════════════════════════════════════════════════
--  GAME MAP  ← Add supported games here
--  Format: [PlaceId] = { name, scriptURL }
--  Find a game's PlaceId in its Roblox URL:
--      roblox.com/games/PLACEID/game-name
-- ══════════════════════════════════════════════════════

local GAMES = {
    [2753915549] = {
        name      = "Blox Fruits",
        scriptURL = "https://raw.githubusercontent.com/ItsYaBoySpooks/ExtremeSolutionsKeySystem/main/BloxFruitsHub.lua",
    },
    --[[  Template for adding more games:
    [PLACE_ID_HERE] = {
        name      = "Game Name",
        scriptURL = "https://raw.githubusercontent.com/.../Script.lua",
    },
    --]]
}

-- ══════════════════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════════════════

local Players      = game:GetService("Players")
local HttpService  = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local player       = Players.LocalPlayer
local playerGui    = player:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════════════════
--  KEY VALIDATION
-- ══════════════════════════════════════════════════════

local function isOfflineKey(key)
    for _, k in ipairs(CONFIG.OfflineKeys) do
        if k == key then return true end
    end
    return false
end

local function getHWID()
    -- Use the executor's built-in HWID function if available,
    -- otherwise fall back to a combination of unique player identifiers.
    if syn and syn.request then
        local ok, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
        if ok and id then return id end
    end
    return tostring(game:GetService("Players").LocalPlayer.UserId)
end

local function validateKey(key)
    -- 1. Check offline whitelist first (instant, no HTTP)
    if isOfflineKey(key) then
        return true, "Key accepted (offline)."
    end

    -- 2. POST /api/validate  { key, hwid }
    --    Matches your server.js endpoint exactly.
    local body = HttpService:JSONEncode({ key = key, hwid = getHWID() })

    local ok, result = pcall(function()
        return HttpService:RequestAsync({
            Url    = CONFIG.APIBaseURL .. "/api/validate",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body   = body,
        })
    end)

    if not ok then
        return false, "Could not reach validation server.\nCheck your connection."
    end

    -- result.Body contains the JSON string from your server
    local parsed, data = pcall(function()
        return HttpService:JSONDecode(result.Body)
    end)

    if not parsed then
        return false, "Unexpected server response."
    end

    -- Your server returns: { success: true/false, message: "..." }
    if data.success == true then
        return true, data.message or "Key accepted."
    else
        return false, data.message or "Invalid key. Purchase one at the store."
    end
end

-- ══════════════════════════════════════════════════════
--  GAME DETECTION
-- ══════════════════════════════════════════════════════

local function detectGame()
    local placeId = game.PlaceId
    local entry   = GAMES[placeId]
    if entry then
        return entry.name, entry.scriptURL
    end
    return nil, nil
end

-- ══════════════════════════════════════════════════════
--  SCRIPT LOADER
-- ══════════════════════════════════════════════════════

local function loadGameScript(scriptURL, gameName)
    local ok, err = pcall(function()
        loadstring(game:HttpGet(scriptURL))()
    end)
    if not ok then
        warn("[ES Hub] Failed to load script for " .. gameName .. ": " .. tostring(err))
        return false, tostring(err)
    end
    return true, nil
end

-- ══════════════════════════════════════════════════════
--  GUI BUILDER
-- ══════════════════════════════════════════════════════

local COLORS = {
    bg         = Color3.fromRGB(15, 15, 20),
    panel      = Color3.fromRGB(22, 22, 30),
    border     = Color3.fromRGB(60, 60, 90),
    accent     = Color3.fromRGB(100, 80, 255),
    accentHov  = Color3.fromRGB(120, 100, 255),
    text       = Color3.fromRGB(220, 220, 235),
    textDim    = Color3.fromRGB(130, 130, 155),
    inputBg    = Color3.fromRGB(12, 12, 18),
    success    = Color3.fromRGB(80, 210, 120),
    error      = Color3.fromRGB(220, 80, 80),
    warning    = Color3.fromRGB(255, 190, 50),
    white      = Color3.fromRGB(255, 255, 255),
}

local function tween(obj, props, t, style, dir)
    style = style or Enum.EasingStyle.Quart
    dir   = dir   or Enum.EasingDirection.Out
    return TweenService:Create(obj, TweenInfo.new(t or 0.25, style, dir), props):Play()
end

local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function makeStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color or COLORS.border
    s.Thickness = thickness or 1
    s.Parent    = parent
    return s
end

-- ══════════════════════════════════════════════════════
--  MAIN GUI  (Key Entry Screen)
-- ══════════════════════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name              = "ESHubKeyGui"
screenGui.ResetOnSpawn      = false
screenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset    = true
screenGui.Parent            = playerGui

-- Fullscreen dark overlay
local overlay = Instance.new("Frame")
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel        = 0
overlay.ZIndex                 = 1
overlay.Parent                 = screenGui

-- Central panel
local panel = Instance.new("Frame")
panel.AnchorPoint         = Vector2.new(0.5, 0.5)
panel.Position            = UDim2.new(0.5, 0, 0.5, 0)
panel.Size                = UDim2.new(0, 420, 0, 360)
panel.BackgroundColor3    = COLORS.panel
panel.BorderSizePixel     = 0
panel.ZIndex              = 2
panel.Parent              = screenGui
makeCorner(panel, 14)
makeStroke(panel, COLORS.border, 1.5)

-- Accent bar at top of panel
local accentBar = Instance.new("Frame")
accentBar.Size             = UDim2.new(1, 0, 0, 3)
accentBar.BackgroundColor3 = COLORS.accent
accentBar.BorderSizePixel  = 0
accentBar.ZIndex           = 3
accentBar.Parent           = panel

local accentBarCorner = Instance.new("UICorner")
accentBarCorner.CornerRadius = UDim.new(0, 14)
accentBarCorner.Parent       = accentBar

-- Logo / title
local logoLabel = Instance.new("TextLabel")
logoLabel.Size                   = UDim2.new(1, -40, 0, 32)
logoLabel.Position               = UDim2.new(0, 20, 0, 22)
logoLabel.BackgroundTransparency = 1
logoLabel.TextColor3             = COLORS.white
logoLabel.TextSize               = 20
logoLabel.Font                   = Enum.Font.GothamBold
logoLabel.TextXAlignment         = Enum.TextXAlignment.Left
logoLabel.Text                   = "Extreme Solutions"
logoLabel.ZIndex                 = 3
logoLabel.Parent                 = panel

local versionLabel = Instance.new("TextLabel")
versionLabel.Size                   = UDim2.new(0, 60, 0, 32)
versionLabel.Position               = UDim2.new(1, -80, 0, 22)
versionLabel.BackgroundTransparency = 1
versionLabel.TextColor3             = COLORS.textDim
versionLabel.TextSize               = 13
versionLabel.Font                   = Enum.Font.Gotham
versionLabel.TextXAlignment         = Enum.TextXAlignment.Right
versionLabel.Text                   = CONFIG.Version
versionLabel.ZIndex                 = 3
versionLabel.Parent                 = panel

local subLabel = Instance.new("TextLabel")
subLabel.Size                   = UDim2.new(1, -40, 0, 20)
subLabel.Position               = UDim2.new(0, 20, 0, 52)
subLabel.BackgroundTransparency = 1
subLabel.TextColor3             = COLORS.textDim
subLabel.TextSize               = 13
subLabel.Font                   = Enum.Font.Gotham
subLabel.TextXAlignment         = Enum.TextXAlignment.Left
subLabel.Text                   = "Script Hub  ·  Key Required"
subLabel.ZIndex                 = 3
subLabel.Parent                 = panel

-- Divider
local divider = Instance.new("Frame")
divider.Size             = UDim2.new(1, -40, 0, 1)
divider.Position         = UDim2.new(0, 20, 0, 82)
divider.BackgroundColor3 = COLORS.border
divider.BorderSizePixel  = 0
divider.ZIndex           = 3
divider.Parent           = panel

-- Game detection status
local gameLabel = Instance.new("TextLabel")
gameLabel.Size                   = UDim2.new(1, -40, 0, 22)
gameLabel.Position               = UDim2.new(0, 20, 0, 96)
gameLabel.BackgroundTransparency = 1
gameLabel.TextColor3             = COLORS.textDim
gameLabel.TextSize               = 13
gameLabel.Font                   = Enum.Font.Gotham
gameLabel.TextXAlignment         = Enum.TextXAlignment.Left
gameLabel.Text                   = "Detecting game..."
gameLabel.ZIndex                 = 3
gameLabel.Parent                 = panel

-- Key input label
local inputLabel = Instance.new("TextLabel")
inputLabel.Size                   = UDim2.new(1, -40, 0, 18)
inputLabel.Position               = UDim2.new(0, 20, 0, 136)
inputLabel.BackgroundTransparency = 1
inputLabel.TextColor3             = COLORS.textDim
inputLabel.TextSize               = 12
inputLabel.Font                   = Enum.Font.GothamBold
inputLabel.TextXAlignment         = Enum.TextXAlignment.Left
inputLabel.Text                   = "ENTER YOUR KEY"
inputLabel.ZIndex                 = 3
inputLabel.Parent                 = panel

-- Key input box
local inputBox = Instance.new("TextBox")
inputBox.Size                   = UDim2.new(1, -40, 0, 42)
inputBox.Position               = UDim2.new(0, 20, 0, 158)
inputBox.BackgroundColor3       = COLORS.inputBg
inputBox.TextColor3             = COLORS.text
inputBox.PlaceholderColor3      = COLORS.textDim
inputBox.PlaceholderText        = "XXXX-XXXX-XXXX-XXXX"
inputBox.Text                   = ""
inputBox.TextSize               = 15
inputBox.Font                   = Enum.Font.GothamBold
inputBox.ClearTextOnFocus       = false
inputBox.TextXAlignment         = Enum.TextXAlignment.Center
inputBox.BorderSizePixel        = 0
inputBox.ZIndex                 = 3
inputBox.Parent                 = panel
makeCorner(inputBox, 8)
makeStroke(inputBox, COLORS.border, 1)

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size                   = UDim2.new(1, -40, 0, 36)
statusLabel.Position               = UDim2.new(0, 20, 0, 208)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3             = COLORS.textDim
statusLabel.TextSize               = 13
statusLabel.Font                   = Enum.Font.Gotham
statusLabel.TextXAlignment         = Enum.TextXAlignment.Center
statusLabel.TextWrapped            = true
statusLabel.Text                   = "Enter your key and press Validate."
statusLabel.ZIndex                 = 3
statusLabel.Parent                 = panel

-- Validate button
local validateBtn = Instance.new("TextButton")
validateBtn.Size             = UDim2.new(1, -40, 0, 42)
validateBtn.Position         = UDim2.new(0, 20, 0, 252)
validateBtn.BackgroundColor3 = COLORS.accent
validateBtn.TextColor3       = COLORS.white
validateBtn.TextSize         = 15
validateBtn.Font             = Enum.Font.GothamBold
validateBtn.Text             = "Validate Key"
validateBtn.BorderSizePixel  = 0
validateBtn.ZIndex           = 3
validateBtn.Parent           = panel
makeCorner(validateBtn, 8)

-- Store link button
local storeBtn = Instance.new("TextButton")
storeBtn.Size             = UDim2.new(0.47, 0, 0, 30)
storeBtn.Position         = UDim2.new(0, 20, 0, 308)
storeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
storeBtn.TextColor3       = COLORS.textDim
storeBtn.TextSize         = 12
storeBtn.Font             = Enum.Font.Gotham
storeBtn.Text             = "Get a Key →"
storeBtn.BorderSizePixel  = 0
storeBtn.ZIndex           = 3
storeBtn.Parent           = panel
makeCorner(storeBtn, 6)
makeStroke(storeBtn, COLORS.border, 1)

-- Discord link button
local discordBtn = Instance.new("TextButton")
discordBtn.Size             = UDim2.new(0.47, 0, 0, 30)
discordBtn.Position         = UDim2.new(1, -20 - (420 * 0.47), 0, 308)  -- right-aligned
discordBtn.Position         = UDim2.new(0.5, 4, 0, 308)
discordBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
discordBtn.TextColor3       = COLORS.textDim
discordBtn.TextSize         = 12
discordBtn.Font             = Enum.Font.Gotham
discordBtn.Text             = "Discord →"
discordBtn.BorderSizePixel  = 0
discordBtn.ZIndex           = 3
discordBtn.Parent           = panel
makeCorner(discordBtn, 6)
makeStroke(discordBtn, COLORS.border, 1)

-- ══════════════════════════════════════════════════════
--  PANEL ENTRANCE ANIMATION
-- ══════════════════════════════════════════════════════

panel.Position = UDim2.new(0.5, 0, 0.5, 30)
panel.BackgroundTransparency = 1
task.spawn(function()
    tween(panel, { Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 0 }, 0.4)
end)

-- ══════════════════════════════════════════════════════
--  GAME DETECTION (runs at startup)
-- ══════════════════════════════════════════════════════

local detectedGameName, detectedScriptURL = detectGame()

if detectedGameName then
    gameLabel.TextColor3 = COLORS.success
    gameLabel.Text       = "Game detected:  " .. detectedGameName
else
    gameLabel.TextColor3 = COLORS.warning
    gameLabel.Text       = "Game not supported (PlaceId: " .. tostring(game.PlaceId) .. ")"
    validateBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    validateBtn.Text             = "Unsupported Game"
    validateBtn.Active           = false
end

-- ══════════════════════════════════════════════════════
--  BUTTON INTERACTIONS
-- ══════════════════════════════════════════════════════

local isValidating = false

validateBtn.MouseEnter:Connect(function()
    if not isValidating then
        tween(validateBtn, { BackgroundColor3 = COLORS.accentHov }, 0.15)
    end
end)
validateBtn.MouseLeave:Connect(function()
    if not isValidating then
        tween(validateBtn, { BackgroundColor3 = COLORS.accent }, 0.15)
    end
end)

storeBtn.MouseEnter:Connect(function()
    tween(storeBtn, { TextColor3 = COLORS.text }, 0.15)
end)
storeBtn.MouseLeave:Connect(function()
    tween(storeBtn, { TextColor3 = COLORS.textDim }, 0.15)
end)

discordBtn.MouseEnter:Connect(function()
    tween(discordBtn, { TextColor3 = COLORS.text }, 0.15)
end)
discordBtn.MouseLeave:Connect(function()
    tween(discordBtn, { TextColor3 = COLORS.textDim }, 0.15)
end)

-- Open store/discord via setclipboard (executors don't allow browser opens)
storeBtn.MouseButton1Click:Connect(function()
    pcall(function() setclipboard(CONFIG.StoreURL) end)
    statusLabel.TextColor3 = COLORS.textDim
    statusLabel.Text       = "Store link copied to clipboard!"
end)

discordBtn.MouseButton1Click:Connect(function()
    pcall(function() setclipboard(CONFIG.DiscordURL) end)
    statusLabel.TextColor3 = COLORS.textDim
    statusLabel.Text       = "Discord link copied to clipboard!"
end)

-- ══════════════════════════════════════════════════════
--  VALIDATE BUTTON LOGIC
-- ══════════════════════════════════════════════════════

local function onValidate()
    if isValidating then return end
    if not detectedGameName then return end

    local key = inputBox.Text:match("^%s*(.-)%s*$")  -- trim whitespace

    if key == "" then
        statusLabel.TextColor3 = COLORS.error
        statusLabel.Text       = "Please enter a key."
        return
    end

    isValidating = true
    validateBtn.Text             = "Validating..."
    validateBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    statusLabel.TextColor3       = COLORS.textDim
    statusLabel.Text             = "Checking key with server..."

    task.spawn(function()
        local valid, message = validateKey(key)

        if valid then
            -- Success
            statusLabel.TextColor3 = COLORS.success
            statusLabel.Text       = "Key accepted! Loading " .. detectedGameName .. "..."
            validateBtn.Text             = "Loading..."
            validateBtn.BackgroundColor3 = COLORS.success

            -- Animate panel out
            task.wait(0.8)
            tween(panel,   { Position = UDim2.new(0.5, 0, 0.5, -20), BackgroundTransparency = 1 }, 0.4)
            tween(overlay, { BackgroundTransparency = 1 }, 0.5)
            task.wait(0.5)
            screenGui:Destroy()

            -- Load the correct script
            local loaded, loadErr = loadGameScript(detectedScriptURL, detectedGameName)
            if not loaded then
                -- Recreate a minimal error notice since our GUI is gone
                warn("[ES Hub] Script load error: " .. tostring(loadErr))
            end
        else
            -- Failure
            statusLabel.TextColor3       = COLORS.error
            statusLabel.Text             = message or "Invalid key."
            validateBtn.Text             = "Validate Key"
            validateBtn.BackgroundColor3 = COLORS.accent

            -- Shake the input box
            local origPos = inputBox.Position
            for i = 1, 4 do
                tween(inputBox, { Position = origPos + UDim2.new(0, (i % 2 == 0 and -6 or 6), 0, 0) }, 0.05)
                task.wait(0.06)
            end
            tween(inputBox, { Position = origPos }, 0.1)

            isValidating = false
        end
    end)
end

validateBtn.MouseButton1Click:Connect(onValidate)

-- Also trigger on Enter key in the input box
inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then onValidate() end
end)

-- Input stroke highlight on focus
inputBox.Focused:Connect(function()
    tween(inputBox, { BackgroundColor3 = Color3.fromRGB(18, 18, 26) }, 0.15)
    for _, s in ipairs(inputBox:GetChildren()) do
        if s:IsA("UIStroke") then
            tween(s, { Color = COLORS.accent }, 0.15)
        end
    end
end)
inputBox.FocusLost:Connect(function()
    tween(inputBox, { BackgroundColor3 = COLORS.inputBg }, 0.15)
    for _, s in ipairs(inputBox:GetChildren()) do
        if s:IsA("UIStroke") then
            tween(s, { Color = COLORS.border }, 0.15)
        end
    end
end)
