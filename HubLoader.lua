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
    DiscordURL = "https://discord.gg/extreme",

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
        scriptURL = "https://raw.githubusercontent.com/Extreme-Solutions-xyz/ES-HUB/main/BloxFruitsHub.lua",
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

-- Executor-compatible HTTP request (works across Synapse, KRNL, Fluxus, etc.)
local httpRequest = (syn and syn.request) or (http and http.request) or request or http_request

-- ══════════════════════════════════════════════════════
--  KEY PERSISTENCE  (save / load from executor filesystem)
-- ══════════════════════════════════════════════════════

local KEY_FOLDER = "ExtremeSolutions"
local KEY_FILE   = KEY_FOLDER .. "/savedkey.txt"

local function saveKey(key)
    pcall(function()
        if not isfolder(KEY_FOLDER) then makefolder(KEY_FOLDER) end
        writefile(KEY_FILE, key)
    end)
end

local function loadSavedKey()
    local ok, result = pcall(function()
        if isfolder(KEY_FOLDER) and isfile(KEY_FILE) then
            return readfile(KEY_FILE)
        end
    end)
    if ok and type(result) == "string" and result ~= "" then
        return result:match("^%s*(.-)%s*$")  -- trim whitespace
    end
    return nil
end

local function clearSavedKey()
    pcall(function()
        if isfile(KEY_FILE) then writefile(KEY_FILE, "") end
    end)
end

local function validateKey(key)
    -- 1. Check offline whitelist first (instant, no HTTP)
    if isOfflineKey(key) then
        return true, "Key accepted (offline)."
    end

    if not httpRequest then
        return false, "Your executor does not support HTTP requests."
    end

    -- 2. POST /api/validate  { key, hwid }
    local body = HttpService:JSONEncode({ key = key, hwid = getHWID() })

    local ok, result = pcall(function()
        return httpRequest({
            Url     = CONFIG.APIBaseURL .. "/api/validate",
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = body,
        })
    end)

    if not ok or not result then
        return false, "Could not reach server.\n(" .. tostring(result) .. ")"
    end

    -- Some executors surface HTTP errors as non-200 status codes
    if result.StatusCode and result.StatusCode ~= 200 then
        return false, "Server error " .. tostring(result.StatusCode) .. ":\n" .. tostring(result.Body):sub(1, 120)
    end

    local parsed, data = pcall(function()
        return HttpService:JSONDecode(result.Body)
    end)

    if not parsed then
        return false, "Bad server response:\n" .. tostring(result.Body):sub(1, 120)
    end

    -- Your server returns: { success: true/false, message: "..." }
    if data.success == true then
        return true, data.message or "Key accepted."
    else
        return false, (data.message or data.error or "Invalid key.") .. "\n[Status: " .. tostring(result.StatusCode) .. "]"
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
panel.ClipsDescendants    = true   -- lets children be clipped by the panel's rounded corners
panel.ZIndex              = 2
panel.Parent              = screenGui
makeCorner(panel, 14)
makeStroke(panel, COLORS.border, 1.5)

-- Accent bar at top of panel
-- No UICorner needed — panel.ClipsDescendants handles the rounded top corners
local accentBar = Instance.new("Frame")
accentBar.Size             = UDim2.new(1, 0, 0, 4)
accentBar.BackgroundColor3 = COLORS.accent
accentBar.BorderSizePixel  = 0
accentBar.ZIndex           = 3
accentBar.Parent           = panel

-- Header background strip (matches ESLib sidebar colour)
local headerBg = Instance.new("Frame")
headerBg.Size             = UDim2.new(1, 0, 0, 78)
headerBg.Position         = UDim2.new(0, 0, 0, 4)   -- sits just below accent bar
headerBg.BackgroundColor3 = Color3.fromRGB(13, 13, 21)
headerBg.BorderSizePixel  = 0
headerBg.ZIndex           = 2
headerBg.Parent           = panel

-- ES badge (purple square with "ES" text, top-left of header)
local esBadge = Instance.new("Frame")
esBadge.Size             = UDim2.new(0, 28, 0, 28)
esBadge.Position         = UDim2.new(0, 18, 0, 24)
esBadge.BackgroundColor3 = COLORS.accent
esBadge.BorderSizePixel  = 0
esBadge.ZIndex           = 4
esBadge.Parent           = panel
makeCorner(esBadge, 7)
local esBadgeLbl = Instance.new("TextLabel")
esBadgeLbl.Size                   = UDim2.new(1, 0, 1, 0)
esBadgeLbl.BackgroundTransparency = 1
esBadgeLbl.TextColor3             = COLORS.white
esBadgeLbl.TextSize               = 11
esBadgeLbl.Font                   = Enum.Font.GothamBold
esBadgeLbl.TextXAlignment         = Enum.TextXAlignment.Center
esBadgeLbl.TextYAlignment         = Enum.TextYAlignment.Center
esBadgeLbl.Text                   = "ES"
esBadgeLbl.ZIndex                 = 5
esBadgeLbl.Parent                 = esBadge

-- Logo / title (shifted right of badge)
local logoLabel = Instance.new("TextLabel")
logoLabel.Size                   = UDim2.new(1, -120, 0, 28)
logoLabel.Position               = UDim2.new(0, 54, 0, 24)
logoLabel.BackgroundTransparency = 1
logoLabel.TextColor3             = COLORS.white
logoLabel.TextSize               = 17
logoLabel.Font                   = Enum.Font.GothamBold
logoLabel.TextXAlignment         = Enum.TextXAlignment.Left
logoLabel.Text                   = "Extreme Solutions"
logoLabel.ZIndex                 = 4
logoLabel.Parent                 = panel

local versionLabel = Instance.new("TextLabel")
versionLabel.Size                   = UDim2.new(0, 55, 0, 28)
versionLabel.Position               = UDim2.new(0, 308, 0, 24)
versionLabel.BackgroundTransparency = 1
versionLabel.TextColor3             = COLORS.textDim
versionLabel.TextSize               = 12
versionLabel.Font                   = Enum.Font.Gotham
versionLabel.TextXAlignment         = Enum.TextXAlignment.Right
versionLabel.Text                   = CONFIG.Version
versionLabel.ZIndex                 = 4
versionLabel.Parent                 = panel

local subLabel = Instance.new("TextLabel")
subLabel.Size                   = UDim2.new(1, -40, 0, 18)
subLabel.Position               = UDim2.new(0, 54, 0, 50)
subLabel.BackgroundTransparency = 1
subLabel.TextColor3             = COLORS.textDim
subLabel.TextSize               = 12
subLabel.Font                   = Enum.Font.Gotham
subLabel.TextXAlignment         = Enum.TextXAlignment.Left
subLabel.Text                   = "Script Hub  ·  Key Required"
subLabel.ZIndex                 = 4
subLabel.Parent                 = panel

-- Divider (sits at bottom of header strip)
local divider = Instance.new("Frame")
divider.Size             = UDim2.new(1, 0, 0, 1)
divider.Position         = UDim2.new(0, 0, 0, 82)
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

-- Store link button (left half)
local storeBtn = Instance.new("TextButton")
storeBtn.Size             = UDim2.new(0, 185, 0, 30)
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

-- Discord link button (right half)
local discordBtn = Instance.new("TextButton")
discordBtn.Size             = UDim2.new(0, 185, 0, 30)
discordBtn.Position         = UDim2.new(0, 215, 0, 308)
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

-- Close button (X) top-right — positioned fully inside the panel
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 28, 0, 28)
closeBtn.Position         = UDim2.new(0, 374, 0, 27)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
closeBtn.TextColor3       = COLORS.textDim
closeBtn.TextSize         = 14
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.Text             = "X"
closeBtn.BorderSizePixel  = 0
closeBtn.ZIndex           = 5
closeBtn.Parent           = panel
makeCorner(closeBtn, 6)

closeBtn.MouseEnter:Connect(function()
    tween(closeBtn, { BackgroundColor3 = Color3.fromRGB(200, 60, 60), TextColor3 = COLORS.white }, 0.15)
end)
closeBtn.MouseLeave:Connect(function()
    tween(closeBtn, { BackgroundColor3 = Color3.fromRGB(40, 40, 55), TextColor3 = COLORS.textDim }, 0.15)
end)
closeBtn.MouseButton1Click:Connect(function()
    tween(panel,   { BackgroundTransparency = 1 }, 0.2)
    tween(overlay, { BackgroundTransparency = 1 }, 0.25)
    task.wait(0.3)
    screenGui:Destroy()
end)

-- (dragging is handled directly on the panel below)

-- ══════════════════════════════════════════════════════
--  PANEL ENTRANCE ANIMATION
-- ══════════════════════════════════════════════════════

panel.Position = UDim2.new(0.5, 0, 0.5, 30)
panel.BackgroundTransparency = 1
task.spawn(function()
    tween(panel, { Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 0 }, 0.4)
end)

-- ══════════════════════════════════════════════════════
--  DRAGGING
-- ══════════════════════════════════════════════════════

local UserInputService = game:GetService("UserInputService")
local dragging, dragInput, dragStart, startPos

local PANEL_W, PANEL_H = 420, 360

panel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = input.Position
        startPos  = panel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

panel.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        local vp    = game:GetService("Workspace").CurrentCamera.ViewportSize
        local newX  = math.clamp(startPos.X.Offset + delta.X, PANEL_W / 2 - vp.X / 2, vp.X / 2 - PANEL_W / 2)
        local newY  = math.clamp(startPos.Y.Offset + delta.Y, PANEL_H / 2 - vp.Y / 2, vp.Y / 2 - PANEL_H / 2)
        panel.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
    end
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
            -- Success — persist the key so the user isn't prompted next time
            saveKey(key)
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
            -- Failure — clear any saved key so it doesn't auto-retry a bad/revoked key
            clearSavedKey()
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

-- ══════════════════════════════════════════════════════
--  AUTO-LOGIN  (runs after GUI is built)
--  If a saved key exists, pre-fill and auto-validate
--  so the user skips the key screen entirely.
-- ══════════════════════════════════════════════════════

task.spawn(function()
    -- Small delay so the entrance animation plays first
    task.wait(0.6)
    local saved = loadSavedKey()
    if saved and saved ~= "" and detectedGameName then
        inputBox.Text          = saved
        statusLabel.TextColor3 = COLORS.textDim
        statusLabel.Text       = "Remembered key found — validating..."
        task.wait(0.3)
        onValidate()
    end
end)
