-- ██████████████████████████████████████████████████████
-- Extreme Solutions | Script Hub
-- Hub Loader v1.2  (Polished GUI + Mobile)
-- Key System · Game Detection · Auto Load
-- ██████████████████████████████████████████████████████


-- ══════════════════════════════════════════════════════
-- HUB CONFIG
-- ══════════════════════════════════════════════════════

local CONFIG = {
    APIBaseURL  = "https://extremesolutionskeysystem-production.up.railway.app",
    OfflineKeys = {},
    StoreURL    = "https://extremesolutions.xyz",
    DiscordURL  = "https://discord.gg/extreme",
    Version     = "v1.2",
}


-- ══════════════════════════════════════════════════════
-- GAME MAP
-- ══════════════════════════════════════════════════════

local GAMES = {
    [2753915549] = {
        name      = "Blox Fruits",
        scriptURL = "https://raw.githubusercontent.com/Extreme-Solutions-xyz/ES-HUB/main/BloxFruitsHub.lua",
    },
}


-- ══════════════════════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = game:GetService("Workspace").CurrentCamera


-- ══════════════════════════════════════════════════════
-- MOBILE DETECTION & SCALING
-- ══════════════════════════════════════════════════════

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local vpSize    = camera.ViewportSize

local PANEL_W = IS_MOBILE and math.min(340, vpSize.X - 40) or 420
local PANEL_H = IS_MOBILE and math.min(340, vpSize.Y - 80) or 360
local S       = IS_MOBILE and math.min(PANEL_W / 420, PANEL_H / 360) or 1

local function sc(val)
    return math.floor(val * S)
end


-- ══════════════════════════════════════════════════════
-- KEY VALIDATION
-- ══════════════════════════════════════════════════════

local function isOfflineKey(key)
    for _, k in ipairs(CONFIG.OfflineKeys) do
        if k == key then return true end
    end
    return false
end

local function getHWID()
    if syn and syn.request then
        local ok, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
        if ok and id then return id end
    end
    return tostring(Players.LocalPlayer.UserId)
end

local httpRequest = (syn and syn.request) or (http and http.request) or request or http_request


-- ══════════════════════════════════════════════════════
-- KEY PERSISTENCE
-- ══════════════════════════════════════════════════════

local KEY_FOLDER = "ExtremeSolutions"
local KEY_FILE   = KEY_FOLDER .. "/savedkey.txt"

local function saveKey(key)
    pcall(function() getgenv().ES_HUB_KEY = key end)
    pcall(function()
        if not isfolder(KEY_FOLDER) then makefolder(KEY_FOLDER) end
        writefile(KEY_FILE, key)
    end)
end

local function loadSavedKey()
    local mem = pcall(function() return getgenv().ES_HUB_KEY end) and getgenv().ES_HUB_KEY
    if type(mem) == "string" and mem ~= "" then
        return mem:match("^%s*(.-)%s*$")
    end
    local ok, result = pcall(readfile, KEY_FILE)
    if ok and type(result) == "string" and result ~= "" then
        return result:match("^%s*(.-)%s*$")
    end
    return nil
end

local function clearSavedKey()
    pcall(function() getgenv().ES_HUB_KEY = nil end)
    pcall(function() writefile(KEY_FILE, "") end)
end

local function validateKey(key)
    if isOfflineKey(key) then
        return true, "Key accepted (offline)."
    end
    if not httpRequest then
        return false, "Your executor does not support HTTP requests."
    end

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
    if result.StatusCode and result.StatusCode ~= 200 then
        return false, "Server error " .. tostring(result.StatusCode)
    end

    local parsed, data = pcall(function()
        return HttpService:JSONDecode(result.Body)
    end)
    if not parsed then
        return false, "Bad server response."
    end

    if data.success == true then
        return true, data.message or "Key accepted."
    else
        return false, (data.message or data.error or "Invalid key.")
    end
end


-- ══════════════════════════════════════════════════════
-- GAME DETECTION & SCRIPT LOADER
-- ══════════════════════════════════════════════════════

local function detectGame()
    local entry = GAMES[game.PlaceId]
    if entry then return entry.name, entry.scriptURL end
    return nil, nil
end

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
-- THEME
-- ══════════════════════════════════════════════════════

local C = {
    bg        = Color3.fromRGB(  8,  12,   8),
    panel     = Color3.fromRGB( 14,  20,  14),
    header    = Color3.fromRGB( 11,  16,  11),
    border    = Color3.fromRGB( 40,  70,  40),
    accent    = Color3.fromRGB( 98, 210,  60),
    accentHov = Color3.fromRGB(118, 230,  75),
    accentDim = Color3.fromRGB( 55, 120,  35),
    text      = Color3.fromRGB(228, 242, 228),
    textDim   = Color3.fromRGB( 70, 100,  70),
    textSec   = Color3.fromRGB(140, 175, 140),
    inputBg   = Color3.fromRGB( 10,  15,  10),
    success   = Color3.fromRGB( 70, 200, 108),
    error     = Color3.fromRGB(210,  65,  65),
    warning   = Color3.fromRGB(238, 175,  42),
    white     = Color3.fromRGB(255, 255, 255),
    shadow    = Color3.fromRGB(  0,   0,   0),
    glow      = Color3.fromRGB( 98, 210,  60),
}


-- ══════════════════════════════════════════════════════
-- GUI HELPERS
-- ══════════════════════════════════════════════════════

local function tw(obj, props, t, style, dir)
    return TweenService:Create(obj, TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props):Play()
end

local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function makeStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color           = color or C.border
    s.Thickness       = thickness or 1.5
    s.Transparency    = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent          = parent
    return s
end

local function makeGradient(parent, c1, c2, rotation)
    local g = Instance.new("UIGradient")
    g.Color    = ColorSequence.new(c1, c2)
    g.Rotation = rotation or 90
    g.Parent   = parent
    return g
end

-- FIXED: Properly fades ALL descendants including strokes, images, text
local function fadeAll(root, duration)
    local info = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            TweenService:Create(obj, info, {
                TextTransparency = 1,
                TextStrokeTransparency = 1,
                BackgroundTransparency = 1,
            }):Play()
        end
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            TweenService:Create(obj, info, {
                ImageTransparency = 1,
                BackgroundTransparency = 1,
            }):Play()
        end
        if obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
            TweenService:Create(obj, info, { BackgroundTransparency = 1 }):Play()
        end
        if obj:IsA("UIStroke") then
            TweenService:Create(obj, info, { Transparency = 1 }):Play()
        end
    end
    -- Fade root itself
    if root:IsA("Frame") then
        TweenService:Create(root, info, { BackgroundTransparency = 1 }):Play()
    end
end

-- Restore everything (for un-minimize)
local function showAll(root, duration)
    local info = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            TweenService:Create(obj, info, {
                TextTransparency = 0,
                TextStrokeTransparency = 1, -- keep stroke off for clean text
                BackgroundTransparency = obj:GetAttribute("OrigBgT") or 0,
            }):Play()
        end
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            TweenService:Create(obj, info, {
                ImageTransparency = 0,
                BackgroundTransparency = obj:GetAttribute("OrigBgT") or 1,
            }):Play()
        end
        if obj:IsA("Frame") then
            TweenService:Create(obj, info, {
                BackgroundTransparency = obj:GetAttribute("OrigBgT") or 0,
            }):Play()
        end
        if obj:IsA("UIStroke") then
            TweenService:Create(obj, info, { Transparency = 0 }):Play()
        end
    end
    if root:IsA("Frame") then
        TweenService:Create(root, info, { BackgroundTransparency = 0 }):Play()
    end
end


-- ══════════════════════════════════════════════════════
-- MAIN GUI
-- ══════════════════════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "ESHubKeyGui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder   = 100
screenGui.Parent         = playerGui

-- Fullscreen overlay
local overlay = Instance.new("Frame")
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel        = 0
overlay.ZIndex                 = 1
overlay.Parent                 = screenGui

-- ── Shadow (soft glow behind panel) ──
local shadow = Instance.new("Frame")
shadow.AnchorPoint       = Vector2.new(0.5, 0.5)
shadow.Position          = UDim2.new(0.5, 0, 0.5, 4)
shadow.Size              = UDim2.new(0, PANEL_W + 16, 0, PANEL_H + 16)
shadow.BackgroundColor3  = C.glow
shadow.BackgroundTransparency = 0.85
shadow.BorderSizePixel   = 0
shadow.ZIndex            = 1
shadow.Parent            = screenGui
makeCorner(shadow, sc(18))

-- Subtle glow pulse animation on shadow
task.spawn(function()
    while shadow and shadow.Parent do
        TweenService:Create(shadow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 0.78
        }):Play()
        task.wait(2)
        TweenService:Create(shadow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 0.9
        }):Play()
        task.wait(2)
    end
end)

-- ── Main Panel ──
local panel = Instance.new("Frame")
panel.AnchorPoint       = Vector2.new(0.5, 0.5)
panel.Position          = UDim2.new(0.5, 0, 0.5, 0)
panel.Size              = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.BackgroundColor3  = C.panel
panel.BorderSizePixel   = 0
panel.ClipsDescendants  = true  -- KEY: clips the header so no sharp edges poke out
panel.ZIndex            = 2
panel.Parent            = screenGui
makeCorner(panel, sc(14))
local panelStroke = makeStroke(panel, C.border, 1.5)

-- ── Subtle gradient overlay on panel for depth ──
local panelSheen = Instance.new("Frame")
panelSheen.Size                   = UDim2.new(1, 0, 0.4, 0)
panelSheen.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
panelSheen.BackgroundTransparency = 0.97
panelSheen.BorderSizePixel        = 0
panelSheen.ZIndex                 = 2
panelSheen.Parent                 = panel
makeGradient(panelSheen, Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0), 90)

-- ── Header (inside panel, clipped by panel corners) ──
local HEADER_H = sc(72)

local headerBg = Instance.new("Frame")
headerBg.Size             = UDim2.new(1, 0, 0, HEADER_H)
headerBg.Position         = UDim2.new(0, 0, 0, 0)
headerBg.BackgroundColor3 = C.header
headerBg.BorderSizePixel  = 0
headerBg.ZIndex           = 3
headerBg.Parent           = panel

-- Accent gradient line at very top (thin, inside the rounded panel)
local accentLine = Instance.new("Frame")
accentLine.Size             = UDim2.new(1, 0, 0, 2)
accentLine.Position         = UDim2.new(0, 0, 0, 0)
accentLine.BackgroundColor3 = C.accent
accentLine.BorderSizePixel  = 0
accentLine.ZIndex           = 10
accentLine.Parent           = panel
makeGradient(accentLine, C.accent, C.accentDim, 0)

-- Header divider
local divider = Instance.new("Frame")
divider.Size             = UDim2.new(1, 0, 0, 1)
divider.Position         = UDim2.new(0, 0, 0, HEADER_H)
divider.BackgroundColor3 = C.border
divider.BorderSizePixel  = 0
divider.ZIndex           = 4
divider.Parent           = panel

-- Layout
local MARGIN     = sc(20)
local BADGE_SIZE = sc(32)

-- ES badge
local esBadge = Instance.new("ImageLabel")
esBadge.Size                   = UDim2.new(0, BADGE_SIZE, 0, BADGE_SIZE)
esBadge.Position               = UDim2.new(0, MARGIN, 0, sc(12))
esBadge.BackgroundTransparency = 1
esBadge.Image                  = "rbxassetid://109874799185427"
esBadge.ScaleType              = Enum.ScaleType.Fit
esBadge.ZIndex                 = 5
esBadge.Parent                 = panel

-- Title
local logoLabel = Instance.new("TextLabel")
logoLabel.Size                   = UDim2.new(1, -(MARGIN * 2 + BADGE_SIZE + 80), 0, sc(22))
logoLabel.Position               = UDim2.new(0, MARGIN + BADGE_SIZE + 10, 0, sc(12))
logoLabel.BackgroundTransparency = 1
logoLabel.TextColor3             = C.white
logoLabel.TextSize               = sc(16)
logoLabel.Font                   = Enum.Font.GothamBold
logoLabel.TextXAlignment         = Enum.TextXAlignment.Left
logoLabel.Text                   = "Extreme Solutions"
logoLabel.TextScaled             = IS_MOBILE
logoLabel.ZIndex                 = 5
logoLabel.Parent                 = panel

-- Subtitle
local subLabel = Instance.new("TextLabel")
subLabel.Size                   = UDim2.new(1, -(MARGIN * 2 + BADGE_SIZE + 80), 0, sc(16))
subLabel.Position               = UDim2.new(0, MARGIN + BADGE_SIZE + 10, 0, sc(36))
subLabel.BackgroundTransparency = 1
subLabel.TextColor3             = C.textDim
subLabel.TextSize               = sc(11)
subLabel.Font                   = Enum.Font.Gotham
subLabel.TextXAlignment         = Enum.TextXAlignment.Left
subLabel.Text                   = "Script Hub · Key Required"
subLabel.ZIndex                 = 5
subLabel.Parent                 = panel

-- Version
local versionLabel = Instance.new("TextLabel")
versionLabel.Size                   = UDim2.new(0, sc(50), 0, sc(20))
versionLabel.Position               = UDim2.new(0, PANEL_W - MARGIN - sc(50) - sc(34), 0, sc(14))
versionLabel.BackgroundTransparency = 1
versionLabel.TextColor3             = C.textDim
versionLabel.TextSize               = sc(11)
versionLabel.Font                   = Enum.Font.Gotham
versionLabel.TextXAlignment         = Enum.TextXAlignment.Right
versionLabel.Text                   = CONFIG.Version
versionLabel.ZIndex                 = 5
versionLabel.Parent                 = panel

-- Close button (clean rounded, no sharp edges)
local closeBtn = Instance.new("TextButton")
closeBtn.Size              = UDim2.new(0, sc(26), 0, sc(26))
closeBtn.Position          = UDim2.new(0, PANEL_W - MARGIN - sc(26) + 4, 0, sc(14))
closeBtn.BackgroundColor3  = Color3.fromRGB(26, 36, 24)
closeBtn.TextColor3        = C.textDim
closeBtn.TextSize          = sc(12)
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.Text              = "✕"
closeBtn.BorderSizePixel   = 0
closeBtn.AutoButtonColor   = false
closeBtn.ZIndex            = 6
closeBtn.Parent            = panel
makeCorner(closeBtn, sc(13)) -- fully round
makeStroke(closeBtn, C.border, 1)

closeBtn.MouseEnter:Connect(function()
    tw(closeBtn, { BackgroundColor3 = C.error, TextColor3 = C.white }, 0.15)
end)
closeBtn.MouseLeave:Connect(function()
    tw(closeBtn, { BackgroundColor3 = Color3.fromRGB(26, 36, 24), TextColor3 = C.textDim }, 0.15)
end)
closeBtn.MouseButton1Click:Connect(function()
    fadeAll(panel, 0.3)
    tw(shadow, { BackgroundTransparency = 1 }, 0.3)
    tw(panelStroke, { Transparency = 1 }, 0.3)
    tw(overlay, { BackgroundTransparency = 1 }, 0.35)
    task.wait(0.4)
    screenGui:Destroy()
end)


-- ══════════════════════════════════════════════════════
-- CONTENT AREA (below header)
-- ══════════════════════════════════════════════════════

local yPos = HEADER_H + sc(14)

-- Game detection label
local gameLabel = Instance.new("TextLabel")
gameLabel.Size                   = UDim2.new(1, -MARGIN * 2, 0, sc(20))
gameLabel.Position               = UDim2.new(0, MARGIN, 0, yPos)
gameLabel.BackgroundTransparency = 1
gameLabel.TextColor3             = C.textDim
gameLabel.TextSize               = sc(13)
gameLabel.Font                   = Enum.Font.Gotham
gameLabel.TextXAlignment         = Enum.TextXAlignment.Left
gameLabel.Text                   = "Detecting game..."
gameLabel.ZIndex                 = 3
gameLabel.Parent                 = panel
yPos = yPos + sc(20) + sc(14)

-- Input label
local inputLabel = Instance.new("TextLabel")
inputLabel.Size                   = UDim2.new(1, -MARGIN * 2, 0, sc(16))
inputLabel.Position               = UDim2.new(0, MARGIN, 0, yPos)
inputLabel.BackgroundTransparency = 1
inputLabel.TextColor3             = C.textDim
inputLabel.TextSize               = sc(11)
inputLabel.Font                   = Enum.Font.GothamBold
inputLabel.TextXAlignment         = Enum.TextXAlignment.Left
inputLabel.Text                   = "ENTER YOUR KEY"
inputLabel.ZIndex                 = 3
inputLabel.Parent                 = panel
yPos = yPos + sc(20)

-- Key input box (with inner glow effect)
local inputBox = Instance.new("TextBox")
inputBox.Size              = UDim2.new(1, -MARGIN * 2, 0, sc(42))
inputBox.Position          = UDim2.new(0, MARGIN, 0, yPos)
inputBox.BackgroundColor3  = C.inputBg
inputBox.TextColor3        = C.text
inputBox.PlaceholderColor3 = C.textDim
inputBox.PlaceholderText   = "ES-XXXX-XXXX-XXXX-XXXX"
inputBox.Text              = ""
inputBox.TextSize          = sc(14)
inputBox.Font              = Enum.Font.GothamBold
inputBox.ClearTextOnFocus  = false
inputBox.TextXAlignment    = Enum.TextXAlignment.Center
inputBox.BorderSizePixel   = 0
inputBox.ZIndex            = 3
inputBox.Parent            = panel
makeCorner(inputBox, sc(10))
local inputStroke = makeStroke(inputBox, C.border, 1.5)
yPos = yPos + sc(42) + sc(8)

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size                   = UDim2.new(1, -MARGIN * 2, 0, sc(34))
statusLabel.Position               = UDim2.new(0, MARGIN, 0, yPos)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3             = C.textDim
statusLabel.TextSize               = sc(12)
statusLabel.Font                   = Enum.Font.Gotham
statusLabel.TextXAlignment         = Enum.TextXAlignment.Center
statusLabel.TextWrapped            = true
statusLabel.Text                   = "Enter your key and press Validate."
statusLabel.ZIndex                 = 3
statusLabel.Parent                 = panel
yPos = yPos + sc(34) + sc(6)

-- Validate button (with gradient for shine)
local validateBtn = Instance.new("TextButton")
validateBtn.Size              = UDim2.new(1, -MARGIN * 2, 0, sc(42))
validateBtn.Position          = UDim2.new(0, MARGIN, 0, yPos)
validateBtn.BackgroundColor3  = C.accent
validateBtn.TextColor3        = C.white
validateBtn.TextSize          = sc(14)
validateBtn.Font              = Enum.Font.GothamBold
validateBtn.Text              = "Validate Key"
validateBtn.BorderSizePixel   = 0
validateBtn.AutoButtonColor   = false
validateBtn.ZIndex            = 3
validateBtn.Parent            = panel
makeCorner(validateBtn, sc(10))
makeStroke(validateBtn, C.accentDim, 1)
-- Subtle shine gradient on the button
makeGradient(validateBtn, Color3.fromRGB(140, 235, 100), Color3.fromRGB(70, 170, 40), 90)
yPos = yPos + sc(42) + sc(12)

-- Bottom buttons
local linkW = math.floor((PANEL_W - MARGIN * 2 - sc(10)) / 2)

local storeBtn = Instance.new("TextButton")
storeBtn.Size              = UDim2.new(0, linkW, 0, sc(30))
storeBtn.Position          = UDim2.new(0, MARGIN, 0, yPos)
storeBtn.BackgroundColor3  = Color3.fromRGB(18, 25, 16)
storeBtn.TextColor3        = C.textDim
storeBtn.TextSize          = sc(11)
storeBtn.Font              = Enum.Font.Gotham
storeBtn.Text              = "Get a Key →"
storeBtn.BorderSizePixel   = 0
storeBtn.AutoButtonColor   = false
storeBtn.ZIndex            = 3
storeBtn.Parent            = panel
makeCorner(storeBtn, sc(8))
makeStroke(storeBtn, C.border, 1)

local discordBtn = Instance.new("TextButton")
discordBtn.Size              = UDim2.new(0, linkW, 0, sc(30))
discordBtn.Position          = UDim2.new(0, MARGIN + linkW + sc(10), 0, yPos)
discordBtn.BackgroundColor3  = Color3.fromRGB(18, 25, 16)
discordBtn.TextColor3        = C.textDim
discordBtn.TextSize          = sc(11)
discordBtn.Font              = Enum.Font.Gotham
discordBtn.Text              = "Discord →"
discordBtn.BorderSizePixel   = 0
discordBtn.AutoButtonColor   = false
discordBtn.ZIndex            = 3
discordBtn.Parent            = panel
makeCorner(discordBtn, sc(8))
makeStroke(discordBtn, C.border, 1)


-- ══════════════════════════════════════════════════════
-- ENTRANCE ANIMATION (smooth slide up + fade in)
-- ══════════════════════════════════════════════════════

panel.Position               = UDim2.new(0.5, 0, 0.5, 40)
panel.BackgroundTransparency = 1
shadow.BackgroundTransparency = 1
panelStroke.Transparency     = 1

-- Set all children transparent initially
for _, obj in ipairs(panel:GetDescendants()) do
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        obj.TextTransparency = 1
        if obj.BackgroundTransparency < 1 then
            obj:SetAttribute("OrigBgT", obj.BackgroundTransparency)
            obj.BackgroundTransparency = 1
        else
            obj:SetAttribute("OrigBgT", 1)
        end
    end
    if obj:IsA("ImageLabel") then
        obj.ImageTransparency = 1
        obj:SetAttribute("OrigBgT", obj.BackgroundTransparency)
        obj.BackgroundTransparency = 1
    end
    if obj:IsA("Frame") then
        obj:SetAttribute("OrigBgT", obj.BackgroundTransparency)
        obj.BackgroundTransparency = 1
    end
    if obj:IsA("UIStroke") then
        obj.Transparency = 1
    end
end

task.spawn(function()
    tw(panel, { Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 0 }, 0.5, Enum.EasingStyle.Back)
    tw(shadow, { BackgroundTransparency = 0.85 }, 0.5)
    tw(panelStroke, { Transparency = 0 }, 0.4)
    task.wait(0.1)
    showAll(panel, 0.35)
end)


-- ══════════════════════════════════════════════════════
-- DRAGGING (smooth, mouse + touch)
-- ══════════════════════════════════════════════════════

local dragging, dragInput, dragStart, startPos

panel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
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
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        local vp    = camera.ViewportSize
        local newX  = math.clamp(startPos.X.Offset + delta.X, PANEL_W / 2 - vp.X / 2, vp.X / 2 - PANEL_W / 2)
        local newY  = math.clamp(startPos.Y.Offset + delta.Y, PANEL_H / 2 - vp.Y / 2, vp.Y / 2 - PANEL_H / 2)
        -- Smooth drag with tween instead of instant snap
        TweenService:Create(panel, TweenInfo.new(0.08, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
        }):Play()
        TweenService:Create(shadow, TweenInfo.new(0.08, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY + 4)
        }):Play()
    end
end)


-- ══════════════════════════════════════════════════════
-- GAME DETECTION
-- ══════════════════════════════════════════════════════

local detectedGameName, detectedScriptURL = detectGame()

if detectedGameName then
    gameLabel.TextColor3 = C.success
    gameLabel.Text       = "Game detected: " .. detectedGameName
else
    gameLabel.TextColor3 = C.warning
    gameLabel.Text       = "Game not supported (PlaceId: " .. tostring(game.PlaceId) .. ")"
    validateBtn.BackgroundColor3 = Color3.fromRGB(30, 46, 26)
    validateBtn.Text             = "Unsupported Game"
    validateBtn.Active           = false
end


-- ══════════════════════════════════════════════════════
-- BUTTON INTERACTIONS
-- ══════════════════════════════════════════════════════

local isValidating = false

validateBtn.MouseEnter:Connect(function()
    if not isValidating then tw(validateBtn, { BackgroundColor3 = C.accentHov }, 0.15) end
end)
validateBtn.MouseLeave:Connect(function()
    if not isValidating then tw(validateBtn, { BackgroundColor3 = C.accent }, 0.15) end
end)

storeBtn.MouseEnter:Connect(function() tw(storeBtn, { TextColor3 = C.text, BackgroundColor3 = Color3.fromRGB(24, 34, 22) }, 0.15) end)
storeBtn.MouseLeave:Connect(function() tw(storeBtn, { TextColor3 = C.textDim, BackgroundColor3 = Color3.fromRGB(18, 25, 16) }, 0.15) end)
discordBtn.MouseEnter:Connect(function() tw(discordBtn, { TextColor3 = C.text, BackgroundColor3 = Color3.fromRGB(24, 34, 22) }, 0.15) end)
discordBtn.MouseLeave:Connect(function() tw(discordBtn, { TextColor3 = C.textDim, BackgroundColor3 = Color3.fromRGB(18, 25, 16) }, 0.15) end)

storeBtn.MouseButton1Click:Connect(function()
    pcall(function() setclipboard(CONFIG.StoreURL) end)
    statusLabel.TextColor3 = C.textSec
    statusLabel.Text = "Store link copied to clipboard!"
end)

discordBtn.MouseButton1Click:Connect(function()
    pcall(function() setclipboard(CONFIG.DiscordURL) end)
    statusLabel.TextColor3 = C.textSec
    statusLabel.Text = "Discord link copied to clipboard!"
end)

-- Input focus glow
inputBox.Focused:Connect(function()
    tw(inputBox, { BackgroundColor3 = Color3.fromRGB(14, 22, 12) }, 0.15)
    tw(inputStroke, { Color = C.accent }, 0.15)
end)
inputBox.FocusLost:Connect(function()
    tw(inputBox, { BackgroundColor3 = C.inputBg }, 0.15)
    tw(inputStroke, { Color = C.border }, 0.15)
end)


-- ══════════════════════════════════════════════════════
-- VALIDATE LOGIC
-- ══════════════════════════════════════════════════════

local function onValidate()
    if isValidating then return end
    if not detectedGameName then return end

    local key = inputBox.Text:match("^%s*(.-)%s*$")
    if key == "" then
        statusLabel.TextColor3 = C.error
        statusLabel.Text = "Please enter a key."
        return
    end

    isValidating = true
    validateBtn.Text = "Validating..."
    validateBtn.BackgroundColor3 = Color3.fromRGB(40, 68, 28)
    statusLabel.TextColor3 = C.textDim
    statusLabel.Text = "Checking key with server..."

    task.spawn(function()
        local valid, message = validateKey(key)

        if valid then
            saveKey(key)
            statusLabel.TextColor3 = C.success
            statusLabel.Text = "Key accepted! Loading " .. detectedGameName .. "..."
            validateBtn.Text = "Loading..."
            validateBtn.BackgroundColor3 = C.success

            task.wait(0.8)
            fadeAll(panel, 0.35)
            tw(shadow, { BackgroundTransparency = 1 }, 0.35)
            tw(panelStroke, { Transparency = 1 }, 0.35)
            tw(overlay, { BackgroundTransparency = 1 }, 0.4)
            task.wait(0.5)
            screenGui:Destroy()

            local loaded, loadErr = loadGameScript(detectedScriptURL, detectedGameName)
            if not loaded then
                warn("[ES Hub] Script load error: " .. tostring(loadErr))
            end
        else
            clearSavedKey()
            statusLabel.TextColor3 = C.error
            statusLabel.Text = message or "Invalid key."
            validateBtn.Text = "Validate Key"
            validateBtn.BackgroundColor3 = C.accent

            -- Shake
            local origPos = inputBox.Position
            for i = 1, 4 do
                tw(inputBox, { Position = origPos + UDim2.new(0, (i % 2 == 0 and -6 or 6), 0, 0) }, 0.05)
                task.wait(0.06)
            end
            tw(inputBox, { Position = origPos }, 0.1)

            isValidating = false
        end
    end)
end

validateBtn.MouseButton1Click:Connect(onValidate)
inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then onValidate() end
end)


-- ══════════════════════════════════════════════════════
-- AUTO-LOGIN
-- ══════════════════════════════════════════════════════

task.spawn(function()
    task.wait(0.8) -- wait for entrance animation
    local saved = loadSavedKey()
    if saved and saved ~= "" and detectedGameName then
        inputBox.Text = saved
        statusLabel.TextColor3 = C.textDim
        statusLabel.Text = "Remembered key found — validating..."
        task.wait(0.3)
        onValidate()
    end
end)
