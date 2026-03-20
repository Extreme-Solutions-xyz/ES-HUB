-- ██████████████████████████████████████████████████████
--           Extreme Solutions  |  ES-UI Library
--                       v1.2
--      Custom UI framework for all ES Hub scripts
-- ██████████████████████████████████████████████████████

-- ══════════════════════════════════════════════════════
--  MODULE
-- ══════════════════════════════════════════════════════

local ESLib = {}
ESLib.__index = ESLib

-- ══════════════════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════════════════

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")
local RunService   = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════════════════
--  THEME  (ES Green)
-- ══════════════════════════════════════════════════════

local T = {
    -- Backgrounds
    bg          = Color3.fromRGB( 8,  12,  8),
    sidebar     = Color3.fromRGB(11,  16, 11),
    panel       = Color3.fromRGB(14,  20, 14),
    card        = Color3.fromRGB(19,  26, 19),
    cardHov     = Color3.fromRGB(24,  32, 24),
    input       = Color3.fromRGB(10,  15, 10),
    overlay     = Color3.fromRGB(11,  15, 11),

    -- Accent (ES lime-green)
    accent      = Color3.fromRGB( 98, 210,  60),
    accentDark  = Color3.fromRGB( 65, 145,  35),
    accentLight = Color3.fromRGB(140, 235, 100),

    -- Tab states
    tabActive   = Color3.fromRGB(18,  30, 18),
    tabHov      = Color3.fromRGB(15,  22, 15),

    -- Text
    textPri     = Color3.fromRGB(228, 242, 228),
    textSec     = Color3.fromRGB(140, 175, 140),
    textDim     = Color3.fromRGB( 70, 100,  70),

    -- Status
    success     = Color3.fromRGB( 70, 200, 108),
    error       = Color3.fromRGB(210,  65,  65),
    warning     = Color3.fromRGB(238, 175,  42),

    -- Toggle
    toggleOn    = Color3.fromRGB( 98, 210,  60),
    toggleOff   = Color3.fromRGB( 30,  45,  30),

    -- Borders
    border      = Color3.fromRGB( 40,  70,  40),
    borderHov   = Color3.fromRGB( 65, 110,  65),

    white       = Color3.fromRGB(255, 255, 255),
    black       = Color3.fromRGB(  0,   0,   0),
}

-- ══════════════════════════════════════════════════════
--  LAYOUT CONSTANTS
-- ══════════════════════════════════════════════════════

local WIN_W     = 600
local WIN_H     = 420
local HEADER_H  = 42
local SIDEBAR_W = 152
local CONTENT_W = WIN_W - SIDEBAR_W
local CONTENT_H = WIN_H - HEADER_H

-- ══════════════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════════════

local function tw(obj, props, t, style, dir)
    TweenService:Create(
        obj,
        TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
        props
    ):Play()
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color           = color or T.border
    s.Thickness       = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent          = parent
    return s
end

-- NOTE: All padding values use UDim.new (not UDim2.new) — UIPadding requires UDim
local function pad(parent, top, right, bot, left)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, top   or 0)
    p.PaddingRight  = UDim.new(0, right or 0)
    p.PaddingBottom = UDim.new(0, bot   or 0)
    p.PaddingLeft   = UDim.new(0, left  or 0)
    p.Parent        = parent
end

local function listLayout(parent, spacing, dir)
    local l = Instance.new("UIListLayout")
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.Padding       = UDim.new(0, spacing or 5)
    l.Parent        = parent
    return l
end

local function newFrame(props)
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    for k, v in pairs(props or {}) do f[k] = v end
    return f
end

local function newLabel(props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel        = 0
    l.Font                   = Enum.Font.Gotham
    l.TextSize               = 13
    l.TextColor3             = T.textPri
    l.TextXAlignment         = Enum.TextXAlignment.Left
    for k, v in pairs(props or {}) do l[k] = v end
    return l
end

local function newBtn(props)
    local b = Instance.new("TextButton")
    b.BorderSizePixel   = 0
    b.AutoButtonColor   = false
    b.Font              = Enum.Font.Gotham
    b.TextSize          = 13
    b.TextColor3        = T.textPri
    b.TextXAlignment    = Enum.TextXAlignment.Left
    for k, v in pairs(props or {}) do b[k] = v end
    return b
end

local function scrollFrame(parent, zindex)
    local s = Instance.new("ScrollingFrame")
    s.BackgroundTransparency = 1
    s.BorderSizePixel        = 0
    s.ScrollBarThickness     = 3
    s.ScrollBarImageColor3   = T.accent
    s.CanvasSize             = UDim2.new(0, 0, 0, 0)
    s.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    s.ZIndex                 = zindex or 2
    s.Parent                 = parent
    return s
end

local function fadeOutGui(root, duration)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            tw(obj, { TextTransparency = 1, BackgroundTransparency = 1 }, duration)
        elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            tw(obj, { ImageTransparency = 1, BackgroundTransparency = 1 }, duration)
        elseif obj:IsA("Frame") then
            tw(obj, { BackgroundTransparency = 1 }, duration)
        elseif obj:IsA("UIStroke") then
            tw(obj, { Transparency = 1 }, duration)
        end
    end
    tw(root, { BackgroundTransparency = 1 }, duration)
end

-- ══════════════════════════════════════════════════════
--  CONFIG PERSISTENCE
-- ══════════════════════════════════════════════════════

local function saveConfig(folder, file, data)
    pcall(function()
        if not isfolder(folder) then makefolder(folder) end
        writefile(folder .. "/" .. file .. ".json", HttpService:JSONEncode(data))
    end)
end

local function loadCfg(folder, file)
    local ok, result = pcall(function()
        return HttpService:JSONDecode(readfile(folder .. "/" .. file .. ".json"))
    end)
    return ok and type(result) == "table" and result or {}
end

-- ══════════════════════════════════════════════════════
--  NOTIFICATION SYSTEM
-- ══════════════════════════════════════════════════════

local notifGui = Instance.new("ScreenGui")
notifGui.Name           = "ESNotifications"
notifGui.ResetOnSpawn   = false
notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
notifGui.IgnoreGuiInset = true
notifGui.DisplayOrder   = 200
notifGui.Parent         = PlayerGui

local notifHolder = newFrame({
    Size                   = UDim2.new(0, 290, 1, 0),
    Position               = UDim2.new(1, -300, 0, 0),
    BackgroundTransparency = 1,
    Parent                 = notifGui,
})
listLayout(notifHolder, 8)
pad(notifHolder, 14, 0, 14, 0)

local function notify(title, content, ntype, duration)
    ntype    = ntype    or "info"
    duration = duration or 4

    local col = ntype == "success" and T.success
             or ntype == "error"   and T.error
             or ntype == "warning" and T.warning
             or T.accent

    local card = newFrame({
        Size             = UDim2.new(1, 0, 0, 68),
        BackgroundColor3 = T.panel,
        ClipsDescendants = true,
        Parent           = notifHolder,
    })
    corner(card, 10)
    stroke(card, T.border, 1.5)

    local bar = newFrame({ Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = col, Parent = card })
    corner(bar, 2)

    newLabel({
        Size       = UDim2.new(1, -22, 0, 18),
        Position   = UDim2.new(0, 13, 0, 10),
        Text       = title,
        TextSize   = 13,
        Font       = Enum.Font.GothamBold,
        TextColor3 = T.textPri,
        Parent     = card,
    })
    newLabel({
        Size        = UDim2.new(1, -22, 0, 28),
        Position    = UDim2.new(0, 13, 0, 30),
        Text        = content,
        TextSize    = 11,
        TextColor3  = T.textSec,
        TextWrapped = true,
        Parent      = card,
    })

    card.Position = UDim2.new(1, 14, 0, 0)
    tw(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.3, Enum.EasingStyle.Back)

    local prog = newFrame({
        Size             = UDim2.new(1, 0, 0, 2),
        Position         = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = col,
        BackgroundTransparency = 0.5,
        Parent           = card,
    })
    tw(prog, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)

    task.delay(duration, function()
        fadeOutGui(card, 0.25)
        tw(card, { Position = UDim2.new(1, 14, 0, 0) }, 0.25)
        task.wait(0.3)
        pcall(function() card:Destroy() end)
    end)
end

-- ══════════════════════════════════════════════════════
--  CREATE WINDOW
-- ══════════════════════════════════════════════════════

function ESLib:CreateWindow(config)
    config = config or {}

    local gui = Instance.new("ScreenGui")
    gui.Name            = "ESHub"
    gui.ResetOnSpawn    = false
    gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset  = true
    gui.DisplayOrder    = 100
    gui.Parent          = PlayerGui

    local shadow = newFrame({
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 3, 0.5, 5),
        Size                   = UDim2.new(0, WIN_W + 14, 0, WIN_H + 14),
        BackgroundColor3       = T.black,
        BackgroundTransparency = 0.5,
        ZIndex                 = 1,
        Parent                 = gui,
    })
    corner(shadow, 18)

    local win = newFrame({
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0.5, 0, 0.5, 0),
        Size             = UDim2.new(0, WIN_W, 0, WIN_H),
        BackgroundColor3 = T.bg,
        ClipsDescendants = true,
        ZIndex           = 2,
        Parent           = gui,
    })
    corner(win, 16)

    local borderOverlay = newFrame({
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.5, 0),
        Size                   = UDim2.new(0, WIN_W, 0, WIN_H),
        BackgroundTransparency = 1,
        ZIndex                 = 10,
        Parent                 = gui,
    })
    corner(borderOverlay, 16)
    stroke(borderOverlay, T.border, 1.5)

    -- Header
    local header = newFrame({
        Size             = UDim2.new(1, 0, 0, HEADER_H),
        BackgroundColor3 = T.sidebar,
        ZIndex           = 4,
        Parent           = win,
    })
    newFrame({
        Size             = UDim2.new(1, 0, 0, 1),
        Position         = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = T.border,
        ZIndex           = 4,
        Parent           = header,
    })

    -- ES Logo badge
    local badge = Instance.new("ImageLabel")
    badge.Size                   = UDim2.new(0, 32, 0, 32)
    badge.Position               = UDim2.new(0, 8, 0.5, -16)
    badge.BackgroundTransparency = 1
    badge.Image                  = "rbxassetid://138296930859915"
    badge.ScaleType              = Enum.ScaleType.Fit
    badge.ZIndex                 = 5
    badge.Parent                 = header

    newLabel({
        Size           = UDim2.new(0, 240, 1, 0),
        Position       = UDim2.new(0, 48, 0, 0),
        Text           = config.Name or "Extreme Solutions",
        TextSize       = 14,
        Font           = Enum.Font.GothamBold,
        TextColor3     = T.textPri,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex         = 5,
        Parent         = header,
    })

    newLabel({
        Size           = UDim2.new(0, 180, 1, 0),
        Position       = UDim2.new(0.5, -90, 0, 0),
        Text           = config.Subtitle or "",
        TextSize       = 11,
        TextColor3     = T.textDim,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex         = 5,
        Parent         = header,
    })

    -- Window control buttons
    local function makeCtrl(offsetX, label, hoverColor)
        local b = newBtn({
            Size             = UDim2.new(0, 26, 0, 26),
            Position         = UDim2.new(1, offsetX, 0.5, -13),
            BackgroundColor3 = T.card,
            Text             = label,
            TextSize         = 12,
            Font             = Enum.Font.GothamBold,
            TextColor3       = T.textSec,
            TextXAlignment   = Enum.TextXAlignment.Center,
            ZIndex           = 6,
            Parent           = header,
        })
        corner(b, 7)
        stroke(b, T.border, 1)
        b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = hoverColor, TextColor3 = T.white }, 0.15) end)
        b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = T.card,     TextColor3 = T.textSec }, 0.15) end)
        return b
    end

    local closeBtn = makeCtrl(-36, "X", T.error)
    local minBtn   = makeCtrl(-68, "-", T.accentDark)

    -- Sidebar
    local sidebar = newFrame({
        Size             = UDim2.new(0, SIDEBAR_W, 0, CONTENT_H),
        Position         = UDim2.new(0, 0, 0, HEADER_H),
        BackgroundColor3 = T.sidebar,
        ZIndex           = 3,
        Parent           = win,
    })
    newFrame({
        Size             = UDim2.new(0, 1, 1, 0),
        Position         = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = T.border,
        ZIndex           = 3,
        Parent           = sidebar,
    })

    local brandStrip = newFrame({
        Size             = UDim2.new(1, -2, 0, 28),
        Position         = UDim2.new(0, 0, 1, -28),
        BackgroundColor3 = T.bg,
        ZIndex           = 4,
        Parent           = sidebar,
    })
    newLabel({
        Size           = UDim2.new(1, 0, 1, 0),
        Text           = "Extreme Solutions",
        TextSize       = 10,
        Font           = Enum.Font.GothamBold,
        TextColor3     = T.accent,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex         = 5,
        Parent         = brandStrip,
    })

    local tabListScroll = scrollFrame(sidebar, 4)
    tabListScroll.Size     = UDim2.new(1, 0, 1, -34)
    tabListScroll.Position = UDim2.new(0, 0, 0, 6)
    listLayout(tabListScroll, 2)
    pad(tabListScroll, 0, 6, 0, 6)

    -- Content area
    local contentArea = newFrame({
        Size             = UDim2.new(0, CONTENT_W, 0, CONTENT_H),
        Position         = UDim2.new(0, SIDEBAR_W, 0, HEADER_H),
        BackgroundColor3 = T.panel,
        ZIndex           = 2,
        Parent           = win,
    })

    -- Drag
    do
        local dragging, dragInput, dragStart, startWin, startShadow

        local function onDragBegan(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging    = true
                dragStart   = input.Position
                startWin    = win.Position
                startShadow = shadow.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end
        local function onDragMoved(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
        end

        header.InputBegan:Connect(onDragBegan)
        sidebar.InputBegan:Connect(onDragBegan)
        header.InputChanged:Connect(onDragMoved)
        sidebar.InputChanged:Connect(onDragMoved)

        UIS.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local d    = input.Position - dragStart
                local vp   = game:GetService("Workspace").CurrentCamera.ViewportSize
                local newX = math.clamp(startWin.X.Offset + d.X, WIN_W / 2 - vp.X / 2, vp.X / 2 - WIN_W / 2)
                local newY = math.clamp(startWin.Y.Offset + d.Y, WIN_H / 2 - vp.Y / 2, vp.Y / 2 - WIN_H / 2)
                win.Position           = UDim2.new(startWin.X.Scale,    newX,     startWin.Y.Scale,    newY)
                shadow.Position        = UDim2.new(startShadow.X.Scale, newX + 3, startShadow.Y.Scale, newY + 5)
                borderOverlay.Position = UDim2.new(startWin.X.Scale,    newX,     startWin.Y.Scale,    newY)
            end
        end)
    end

    -- Mini bubble (shown when minimised)
    local glowRing = newFrame({
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(1, -60, 1, -60),
        Size                   = UDim2.new(0, 96, 0, 96),
        BackgroundColor3       = T.accent,
        BackgroundTransparency = 0.7,
        ZIndex                 = 19,
        Visible                = false,
        Parent                 = gui,
    })
    corner(glowRing, 48)

    local miniBubble = newFrame({
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(1, -60, 1, -60),
        Size             = UDim2.new(0, 80, 0, 80),
        BackgroundColor3 = T.bg,
        ZIndex           = 20,
        Visible          = false,
        Parent           = gui,
    })
    corner(miniBubble, 40)
    stroke(miniBubble, T.accent, 2)

    local bubbleImg = Instance.new("ImageLabel")
    bubbleImg.Size                   = UDim2.new(0, 70, 0, 70)
    bubbleImg.Position               = UDim2.new(0.5, -35, 0.5, -35)
    bubbleImg.BackgroundTransparency = 1
    bubbleImg.Image                  = "rbxassetid://138296930859915"
    bubbleImg.ScaleType              = Enum.ScaleType.Fit
    bubbleImg.ZIndex                 = 21
    bubbleImg.Parent                 = miniBubble

    -- Pulsing glow animation
    task.spawn(function()
        while glowRing.Parent do
            tw(glowRing, { BackgroundTransparency = 0.85 }, 0.9, Enum.EasingStyle.Sine)
            task.wait(0.95)
            tw(glowRing, { BackgroundTransparency = 0.65 }, 0.9, Enum.EasingStyle.Sine)
            task.wait(0.95)
        end
    end)

    -- Minimize / Close
    local minimised = false

    local function restoreWindow()
        minimised             = false
        miniBubble.Visible    = false
        glowRing.Visible      = false
        win.Visible           = true
        shadow.Visible        = true
        borderOverlay.Visible = true
        minBtn.Text           = "-"
        win.Size           = UDim2.new(0, WIN_W, 0, 0)
        shadow.Size        = UDim2.new(0, WIN_W + 14, 0, 0)
        borderOverlay.Size = UDim2.new(0, WIN_W, 0, 0)
        tw(win,           { Size = UDim2.new(0, WIN_W, 0, WIN_H) }, 0.4, Enum.EasingStyle.Back)
        tw(shadow,        { Size = UDim2.new(0, WIN_W + 14, 0, WIN_H + 14) }, 0.4, Enum.EasingStyle.Back)
        tw(borderOverlay, { Size = UDim2.new(0, WIN_W, 0, WIN_H) }, 0.4, Enum.EasingStyle.Back)
    end

    minBtn.MouseButton1Click:Connect(function()
        minimised = not minimised
        if minimised then
            win.Visible           = false
            shadow.Visible        = false
            borderOverlay.Visible = false
            miniBubble.Visible    = true
            glowRing.Visible      = true
            minBtn.Text           = "+"
        else
            restoreWindow()
        end
    end)
    do
        local bubbleDragging  = false
        local bubbleDragInput = nil
        local bubbleDragStart = nil
        local bubbleStartAbsX = 0
        local bubbleStartAbsY = 0
        local bubbleMoved     = false

        miniBubble.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                bubbleDragging  = true
                bubbleDragStart = input.Position
                bubbleStartAbsX = miniBubble.AbsolutePosition.X + miniBubble.AbsoluteSize.X / 2
                bubbleStartAbsY = miniBubble.AbsolutePosition.Y + miniBubble.AbsoluteSize.Y / 2
                bubbleMoved     = false
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        bubbleDragging = false
                        if not bubbleMoved then
                            restoreWindow()
                        end
                    end
                end)
            end
        end)
        miniBubble.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                bubbleDragInput = input
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if input == bubbleDragInput and bubbleDragging then
                local DRAG_THRESHOLD   = 6   -- px — distinguishes click from drag
                local BUBBLE_EDGE_MARGIN = 40 -- px — safe zone from screen edges
                local delta = input.Position - bubbleDragStart
                if delta.Magnitude > DRAG_THRESHOLD then bubbleMoved = true end
                local vp = game:GetService("Workspace").CurrentCamera.ViewportSize
                local nx = math.clamp(bubbleStartAbsX + delta.X, BUBBLE_EDGE_MARGIN, vp.X - BUBBLE_EDGE_MARGIN)
                local ny = math.clamp(bubbleStartAbsY + delta.Y, BUBBLE_EDGE_MARGIN, vp.Y - BUBBLE_EDGE_MARGIN)
                miniBubble.Position = UDim2.new(0, nx, 0, ny)
                glowRing.Position   = UDim2.new(0, nx, 0, ny)
            end
        end)
    end
    closeBtn.MouseButton1Click:Connect(function()
        fadeOutGui(win, 0.25)
        fadeOutGui(shadow, 0.25)
        fadeOutGui(borderOverlay, 0.25)
        task.wait(0.3)
        gui:Destroy()
        notifGui:Destroy()
    end)

    -- Keybind toggle
    if config.ToggleUIKeybind then
        local keyStr = config.ToggleUIKeybind:upper()
        UIS.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            local k = tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
            if k == keyStr then
                if not minimised then
                    win.Visible    = not win.Visible
                    shadow.Visible = win.Visible
                    borderOverlay.Visible = win.Visible
                end
            end
        end)
    end

    -- Entrance animation
    win.Size           = UDim2.new(0, WIN_W, 0, 0)
    shadow.Size        = UDim2.new(0, WIN_W + 14, 0, 0)
    borderOverlay.Size = UDim2.new(0, WIN_W, 0, 0)
    task.spawn(function()
        tw(win,           { Size = UDim2.new(0, WIN_W, 0, WIN_H) }, 0.45, Enum.EasingStyle.Back)
        tw(shadow,        { Size = UDim2.new(0, WIN_W + 14, 0, WIN_H + 14) }, 0.45, Enum.EasingStyle.Back)
        tw(borderOverlay, { Size = UDim2.new(0, WIN_W, 0, WIN_H) }, 0.45, Enum.EasingStyle.Back)
    end)

    -- Config state
    local cfgFolder   = (config.ConfigurationSaving and config.ConfigurationSaving.FolderName) or "ESHub"
    local cfgFile     = (config.ConfigurationSaving and config.ConfigurationSaving.FileName)   or "config"
    local savedValues = {}
    local flagCbs     = {}

    if config.ConfigurationSaving and config.ConfigurationSaving.Enabled then
        task.spawn(function()
            while gui.Parent do
                task.wait(12)
                saveConfig(cfgFolder, cfgFile, savedValues)
            end
        end)
    end

    -- ══════════════════════════════════════════════════
    --  WINDOW OBJECT
    -- ══════════════════════════════════════════════════

    local Window    = {}
    local tabObjs   = {}
    local activeTab = nil

    local function activateTab(tabObj)
        if activeTab == tabObj then return end
        if activeTab then
            tw(activeTab._btn, { BackgroundColor3 = T.sidebar }, 0.15)
            activeTab._indicator.BackgroundTransparency = 1
            tw(activeTab._lblName, { TextColor3 = T.textSec }, 0.15)
            activeTab._content.Visible = false
        end
        activeTab = tabObj
        tw(tabObj._btn, { BackgroundColor3 = T.tabActive }, 0.15)
        tabObj._indicator.BackgroundTransparency = 0
        tw(tabObj._lblName, { TextColor3 = T.textPri }, 0.15)
        tabObj._content.Visible = true
    end

    -- ══════════════════════════════════════════════════
    --  CreateTab
    -- ══════════════════════════════════════════════════

    function Window:CreateTab(name, _icon)

        local btn = newBtn({
            Size             = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = T.sidebar,
            Text             = "",
            ZIndex           = 5,
            Parent           = tabListScroll,
        })
        corner(btn, 8)

        local indicator = newFrame({
            Size                   = UDim2.new(0, 3, 0, 18),
            Position               = UDim2.new(0, 1, 0.5, -9),
            BackgroundColor3       = T.accent,
            BackgroundTransparency = 1,
            ZIndex                 = 6,
            Parent                 = btn,
        })
        corner(indicator, 2)

        local lblName = newLabel({
            Size       = UDim2.new(1, -16, 1, 0),
            Position   = UDim2.new(0, 12, 0, 0),
            Text       = name,
            TextSize   = 13,
            Font       = Enum.Font.GothamSemibold,
            TextColor3 = T.textSec,
            ZIndex     = 6,
            Parent     = btn,
        })

        btn.MouseEnter:Connect(function()
            if activeTab and activeTab._btn == btn then return end
            tw(btn, { BackgroundColor3 = T.tabHov }, 0.12)
        end)
        btn.MouseLeave:Connect(function()
            if activeTab and activeTab._btn == btn then return end
            tw(btn, { BackgroundColor3 = T.sidebar }, 0.12)
        end)

        local content = scrollFrame(contentArea, 3)
        content.Size    = UDim2.new(1, 0, 1, 0)
        content.Visible = false
        listLayout(content, 5)
        pad(content, 10, 12, 10, 12)

        local tabObj = {
            _btn       = btn,
            _indicator = indicator,
            _lblName   = lblName,
            _content   = content,
        }

        btn.MouseButton1Click:Connect(function() activateTab(tabObj) end)
        table.insert(tabObjs, tabObj)
        if #tabObjs == 1 then
            task.defer(function() activateTab(tabObj) end)
        end

        -- ════════════════════════════════════════════
        --  TAB OBJECT
        -- ════════════════════════════════════════════

        local Tab = {}

        local function card(h)
            local f = newFrame({
                Size             = UDim2.new(1, 0, 0, h or 44),
                BackgroundColor3 = T.card,
                ClipsDescendants = true,
                LayoutOrder      = #content:GetChildren() + 1,
                Parent           = content,
            })
            corner(f, 8)
            stroke(f, T.border, 1)
            return f
        end

        -- SECTION
        function Tab:CreateSection(sectionName)
            local sec = newFrame({
                Size                   = UDim2.new(1, 0, 0, 26),
                BackgroundTransparency = 1,
                LayoutOrder            = #content:GetChildren() + 1,
                Parent                 = content,
            })
            newLabel({
                Size           = UDim2.new(0, 0, 1, 0),
                AutomaticSize  = Enum.AutomaticSize.X,
                Text           = sectionName:upper(),
                TextSize       = 10,
                Font           = Enum.Font.GothamBold,
                TextColor3     = T.accent,
                TextYAlignment = Enum.TextYAlignment.Center,
                Parent         = sec,
            })
            newFrame({
                Size             = UDim2.new(1, 0, 0, 1),
                Position         = UDim2.new(0, 0, 1, -1),
                BackgroundColor3 = T.border,
                Parent           = sec,
            })
        end

        -- TOGGLE
        function Tab:CreateToggle(cfg)
            cfg = cfg or {}
            local val  = cfg.CurrentValue or false
            local tall = cfg.Description and 56 or 44
            local c    = card(tall)
            pad(c, 0, 12, 0, 12)

            newLabel({
                Size     = UDim2.new(1, -56, 0, 18),
                Position = UDim2.new(0, 0, 0, cfg.Description and 8 or 13),
                Text     = cfg.Name or "Toggle",
                TextSize = 13,
                Font     = Enum.Font.GothamSemibold,
                Parent   = c,
            })

            if cfg.Description then
                newLabel({
                    Size       = UDim2.new(1, -56, 0, 15),
                    Position   = UDim2.new(0, 0, 0, 30),
                    Text       = cfg.Description,
                    TextSize   = 11,
                    TextColor3 = T.textDim,
                    Parent     = c,
                })
            end

            local pill = newFrame({
                Size             = UDim2.new(0, 40, 0, 20),
                Position         = UDim2.new(1, -40, 0.5, -10),
                BackgroundColor3 = val and T.toggleOn or T.toggleOff,
                Parent           = c,
            })
            corner(pill, 10)

            local knob = newFrame({
                Size             = UDim2.new(0, 16, 0, 16),
                Position         = val and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
                BackgroundColor3 = T.white,
                ZIndex           = 2,
                Parent           = pill,
            })
            corner(knob, 8)

            c.MouseEnter:Connect(function() tw(c, { BackgroundColor3 = T.cardHov }, 0.12) end)
            c.MouseLeave:Connect(function() tw(c, { BackgroundColor3 = T.card    }, 0.12) end)

            local toggleObj = {}

            local function apply(v, fire)
                val = v
                tw(pill, { BackgroundColor3 = v and T.toggleOn or T.toggleOff }, 0.18)
                tw(knob, { Position = v and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8) }, 0.18)
                if fire and cfg.Callback then cfg.Callback(v) end
                if cfg.Flag then savedValues[cfg.Flag] = v end
            end

            local hitbox = newBtn({
                Size                   = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text                   = "",
                ZIndex                 = 3,
                Parent                 = c,
            })
            hitbox.MouseButton1Click:Connect(function() apply(not val, true) end)

            function toggleObj:Set(v) apply(v, false) end
            if cfg.Flag then flagCbs[cfg.Flag] = function(v) apply(v, false) end end
            return toggleObj
        end

        -- SLIDER
        function Tab:CreateSlider(cfg)
            cfg = cfg or {}
            local mn  = cfg.Range and cfg.Range[1] or 0
            local mx  = cfg.Range and cfg.Range[2] or 100
            local inc = cfg.Increment  or 1
            local sfx = cfg.Suffix     or ""
            local val = math.clamp(cfg.CurrentValue or mn, mn, mx)

            local c = card(56)
            pad(c, 0, 12, 0, 12)

            newLabel({
                Size     = UDim2.new(0.6, 0, 0, 18),
                Position = UDim2.new(0, 0, 0, 8),
                Text     = cfg.Name or "Slider",
                TextSize = 13,
                Font     = Enum.Font.GothamSemibold,
                Parent   = c,
            })

            local valLbl = newLabel({
                Size           = UDim2.new(0.4, 0, 0, 18),
                Position       = UDim2.new(0.6, 0, 0, 8),
                Text           = tostring(val) .. sfx,
                TextSize       = 12,
                Font           = Enum.Font.GothamBold,
                TextColor3     = T.accent,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent         = c,
            })

            local track = newFrame({
                Size             = UDim2.new(1, 0, 0, 6),
                Position         = UDim2.new(0, 0, 0, 36),
                BackgroundColor3 = T.input,
                Parent           = c,
            })
            corner(track, 3)

            local fill = newFrame({
                Size             = UDim2.new((val - mn) / (mx - mn), 0, 1, 0),
                BackgroundColor3 = T.accent,
                Parent           = track,
            })
            corner(fill, 3)

            local knob = newFrame({
                Size             = UDim2.new(0, 14, 0, 14),
                Position         = UDim2.new((val - mn) / (mx - mn), -7, 0.5, -7),
                BackgroundColor3 = T.white,
                ZIndex           = 2,
                Parent           = track,
            })
            corner(knob, 7)

            local sliderObj  = {}
            local draggingSl = false

            local function setVal(v, fire)
                v   = math.clamp(math.round(v / inc) * inc, mn, mx)
                val = v
                local pct     = (v - mn) / (mx - mn)
                fill.Size     = UDim2.new(pct, 0, 1, 0)
                knob.Position = UDim2.new(pct, -7, 0.5, -7)
                valLbl.Text   = tostring(v) .. sfx
                if fire and cfg.Callback then cfg.Callback(v) end
                if cfg.Flag then savedValues[cfg.Flag] = v end
            end

            track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingSl = true
                    local rel  = input.Position.X - track.AbsolutePosition.X
                    setVal(mn + (rel / math.max(track.AbsoluteSize.X, 1)) * (mx - mn), true)
                end
            end)
            UIS.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSl = false end
            end)
            UIS.InputChanged:Connect(function(input)
                if draggingSl and input.UserInputType == Enum.UserInputType.MouseMovement then
                    local rel = input.Position.X - track.AbsolutePosition.X
                    setVal(mn + (rel / math.max(track.AbsoluteSize.X, 1)) * (mx - mn), true)
                end
            end)

            function sliderObj:Set(v) setVal(v, false) end
            if cfg.Flag then flagCbs[cfg.Flag] = function(v) setVal(v, false) end end
            return sliderObj
        end

        -- BUTTON
        function Tab:CreateButton(cfg)
            cfg = cfg or {}
            local tall = cfg.Description and 56 or 40
            local c    = card(tall)
            pad(c, 0, 12, 0, 12)

            newLabel({
                Size     = UDim2.new(1, -24, 0, 18),
                Position = UDim2.new(0, 0, 0, cfg.Description and 8 or 11),
                Text     = cfg.Name or "Button",
                TextSize = 13,
                Font     = Enum.Font.GothamSemibold,
                Parent   = c,
            })

            local arrow = newLabel({
                Size           = UDim2.new(0, 20, 1, 0),
                Position       = UDim2.new(1, -20, 0, 0),
                Text           = ">",
                TextSize       = 13,
                Font           = Enum.Font.GothamBold,
                TextColor3     = T.textDim,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent         = c,
            })

            if cfg.Description then
                newLabel({
                    Size       = UDim2.new(1, -24, 0, 15),
                    Position   = UDim2.new(0, 0, 0, 30),
                    Text       = cfg.Description,
                    TextSize   = 11,
                    TextColor3 = T.textDim,
                    Parent     = c,
                })
            end

            local hitbox = newBtn({
                Size                   = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text                   = "",
                ZIndex                 = 2,
                Parent                 = c,
            })

            c.MouseEnter:Connect(function()
                tw(c,     { BackgroundColor3 = T.cardHov }, 0.12)
                tw(arrow, { TextColor3 = T.accent }, 0.12)
            end)
            c.MouseLeave:Connect(function()
                tw(c,     { BackgroundColor3 = T.card }, 0.12)
                tw(arrow, { TextColor3 = T.textDim }, 0.12)
            end)
            hitbox.MouseButton1Click:Connect(function()
                tw(c, { BackgroundColor3 = T.tabActive }, 0.06)
                task.delay(0.14, function() tw(c, { BackgroundColor3 = T.card }, 0.12) end)
                if cfg.Callback then cfg.Callback() end
            end)
        end

        -- DROPDOWN
        function Tab:CreateDropdown(cfg)
            cfg = cfg or {}
            local options    = cfg.Options or {}
            local cur        = (type(cfg.CurrentOption) == "table" and cfg.CurrentOption[1])
                            or cfg.CurrentOption
                            or options[1] or ""
            local searchable = cfg.Searchable ~= false and #options > 6

            local c = card(44)
            pad(c, 0, 12, 0, 12)

            newLabel({ Size = UDim2.new(0.5, 0, 1, 0), Text = cfg.Name or "Dropdown", TextSize = 13, Font = Enum.Font.GothamSemibold, Parent = c })

            local pill = newFrame({ Size = UDim2.new(0, 165, 0, 28), Position = UDim2.new(1, -165, 0.5, -14), BackgroundColor3 = T.input, Parent = c })
            corner(pill, 7)
            stroke(pill, T.border, 1)

            local curLbl  = newLabel({ Size = UDim2.new(1, -26, 1, 0), Position = UDim2.new(0, 8, 0, 0), Text = cur, TextSize = 12, TextColor3 = T.textPri, Parent = pill })
            local chevron = newLabel({ Size = UDim2.new(0, 18, 1, 0), Position = UDim2.new(1, -20, 0, 0), Text = "v", TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = T.textDim, TextXAlignment = Enum.TextXAlignment.Center, Parent = pill })

            local isOpen    = false
            local dropFrame = nil
            local dropObj   = {}

            local function closeDD()
                if dropFrame then
                    tw(dropFrame, { Size = UDim2.new(0, dropFrame.Size.X.Offset, 0, 0) }, 0.15)
                    task.delay(0.18, function() if dropFrame then dropFrame:Destroy(); dropFrame = nil end end)
                end
                isOpen = false
                tw(chevron, { Rotation = 0 }, 0.15)
            end

            local outsideConn

            local function openDD()
                if dropFrame then dropFrame:Destroy(); dropFrame = nil end
                local ap    = pill.AbsolutePosition
                local as    = pill.AbsoluteSize
                local optH  = 30
                local listH = math.min(#options * (optH + 2) + 6, 190)
                local totalH = listH + (searchable and 38 or 6)

                dropFrame = newFrame({ Size = UDim2.new(0, as.X, 0, totalH), Position = UDim2.new(0, ap.X, 0, ap.Y + as.Y + 4), BackgroundColor3 = T.overlay, ClipsDescendants = true, ZIndex = 60, Parent = gui })
                corner(dropFrame, 8)
                stroke(dropFrame, T.borderHov, 1)

                local searchBox
                if searchable then
                    local sh = newFrame({ Size = UDim2.new(1, -8, 0, 26), Position = UDim2.new(0, 4, 0, 4), BackgroundColor3 = T.input, ZIndex = 62, Parent = dropFrame })
                    corner(sh, 6)
                    newLabel({ Size = UDim2.new(0, 20, 1, 0), Text = "?", TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = T.textDim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 63, Parent = sh })
                    searchBox = Instance.new("TextBox")
                    searchBox.Size = UDim2.new(1, -28, 1, 0); searchBox.Position = UDim2.new(0, 22, 0, 0)
                    searchBox.BackgroundTransparency = 1; searchBox.Font = Enum.Font.Gotham; searchBox.TextSize = 12
                    searchBox.TextColor3 = T.textPri; searchBox.PlaceholderText = "Search..."; searchBox.PlaceholderColor3 = T.textDim
                    searchBox.Text = ""; searchBox.TextXAlignment = Enum.TextXAlignment.Left; searchBox.ClearTextOnFocus = false
                    searchBox.ZIndex = 63; searchBox.Parent = sh
                    task.defer(function() searchBox:CaptureFocus() end)
                end

                local listSF = scrollFrame(dropFrame, 61)
                listSF.Size     = UDim2.new(1, 0, 1, -(searchable and 36 or 2))
                listSF.Position = UDim2.new(0, 0, 0, searchable and 36 or 2)
                listLayout(listSF, 2)
                pad(listSF, 2, 3, 2, 3)

                for _, opt in ipairs(options) do
                    local isSelected = opt == cur
                    local row = newBtn({ Size = UDim2.new(1, 0, 0, optH), BackgroundColor3 = isSelected and T.tabActive or T.overlay, BackgroundTransparency = isSelected and 0 or 1, Text = "", ZIndex = 62, Parent = listSF })
                    corner(row, 6)
                    newLabel({ Size = UDim2.new(1, isSelected and -22 or -8, 1, 0), Position = UDim2.new(0, 8, 0, 0), Text = opt, TextSize = 12, TextColor3 = isSelected and T.textPri or T.textSec, ZIndex = 63, Parent = row })
                    if isSelected then
                        local dot = newFrame({ Size = UDim2.new(0, 6, 0, 6), Position = UDim2.new(1, -14, 0.5, -3), BackgroundColor3 = T.accent, ZIndex = 63, Parent = row })
                        corner(dot, 3)
                    end
                    row.MouseEnter:Connect(function() if opt ~= cur then tw(row, { BackgroundTransparency = 0, BackgroundColor3 = T.card }, 0.1) end end)
                    row.MouseLeave:Connect(function() if opt ~= cur then tw(row, { BackgroundTransparency = 1 }, 0.1) end end)
                    row.MouseButton1Click:Connect(function()
                        cur = opt; curLbl.Text = opt
                        if cfg.Flag then savedValues[cfg.Flag] = opt end
                        if cfg.Callback then cfg.Callback(opt) end
                        closeDD()
                    end)
                end

                if searchBox then
                    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                        local q = searchBox.Text:lower()
                        for _, row in ipairs(listSF:GetChildren()) do
                            if row:IsA("TextButton") then
                                local lbl = row:FindFirstChildOfClass("TextLabel")
                                row.Visible = q == "" or (lbl and lbl.Text:lower():find(q, 1, true) ~= nil)
                            end
                        end
                    end)
                end

                dropFrame.Size = UDim2.new(0, as.X, 0, 0)
                tw(dropFrame, { Size = UDim2.new(0, as.X, 0, totalH) }, 0.2)

                if outsideConn then outsideConn:Disconnect() end
                outsideConn = UIS.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    task.wait()
                    if not dropFrame or not dropFrame:IsDescendantOf(game) then
                        closeDD(); outsideConn:Disconnect()
                    end
                end)
            end

            c.MouseEnter:Connect(function() tw(c, { BackgroundColor3 = T.cardHov }, 0.12) end)
            c.MouseLeave:Connect(function() tw(c, { BackgroundColor3 = T.card    }, 0.12) end)

            local hitbox = newBtn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = c })
            hitbox.MouseButton1Click:Connect(function()
                if isOpen then closeDD() else isOpen = true; tw(chevron, { Rotation = 180 }, 0.15); openDD() end
            end)

            function dropObj:Set(opt) cur = opt; curLbl.Text = opt end
            function dropObj:Refresh(newOpts)
                options = newOpts
                if isOpen then closeDD(); task.wait(0.2); openDD() end
            end
            if cfg.Flag then flagCbs[cfg.Flag] = function(v) dropObj:Set(v) end end
            return dropObj
        end

        -- MULTI-DROPDOWN
        function Tab:CreateMultiDropdown(cfg)
            cfg = cfg or {}
            local options    = cfg.Options or {}
            local selected   = {}
            local searchable = cfg.Searchable ~= false and #options > 6

            if cfg.CurrentOptions then
                for _, v in ipairs(cfg.CurrentOptions) do selected[v] = true end
            end

            local function selText()
                local keys = {}
                for k in pairs(selected) do table.insert(keys, k) end
                if #keys == 0 then return "None" end
                if #keys == 1 then return keys[1] end
                return keys[1] .. " +" .. (#keys - 1)
            end

            local c = card(44)
            pad(c, 0, 12, 0, 12)

            newLabel({ Size = UDim2.new(0.5,0,1,0), Text = cfg.Name or "Multi Select", TextSize = 13, Font = Enum.Font.GothamSemibold, Parent = c })

            local pill = newFrame({ Size = UDim2.new(0,165,0,28), Position = UDim2.new(1,-165,0.5,-14), BackgroundColor3 = T.input, Parent = c })
            corner(pill, 7); stroke(pill, T.border, 1)

            local curLbl  = newLabel({ Size = UDim2.new(1,-26,1,0), Position = UDim2.new(0,8,0,0), Text = selText(), TextSize = 12, TextColor3 = T.textPri, Parent = pill })
            local chevron = newLabel({ Size = UDim2.new(0,18,1,0), Position = UDim2.new(1,-20,0,0), Text = "v", TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = T.textDim, TextXAlignment = Enum.TextXAlignment.Center, Parent = pill })

            local isOpen = false; local dropFrame = nil; local outsideConn

            local function closeM()
                if dropFrame then
                    tw(dropFrame, { Size = UDim2.new(0, dropFrame.Size.X.Offset, 0, 0) }, 0.15)
                    task.delay(0.18, function() if dropFrame then dropFrame:Destroy(); dropFrame = nil end end)
                end
                isOpen = false; tw(chevron, { Rotation = 0 }, 0.15)
            end

            local function openM()
                if dropFrame then dropFrame:Destroy() end
                local ap = pill.AbsolutePosition; local as = pill.AbsoluteSize
                local rowH = 34
                local listH = math.min(#options * (rowH + 2) + 6, 200)
                local totalH = listH + (searchable and 38 or 6)

                dropFrame = newFrame({ Size = UDim2.new(0,as.X,0,totalH), Position = UDim2.new(0,ap.X,0,ap.Y+as.Y+4), BackgroundColor3 = T.overlay, ClipsDescendants = true, ZIndex = 60, Parent = gui })
                corner(dropFrame, 8); stroke(dropFrame, T.borderHov, 1)

                if searchable then
                    local sh = newFrame({ Size = UDim2.new(1,-8,0,26), Position = UDim2.new(0,4,0,4), BackgroundColor3 = T.input, ZIndex = 62, Parent = dropFrame })
                    corner(sh, 6)
                    local sb = Instance.new("TextBox")
                    sb.Size = UDim2.new(1,-10,1,0); sb.Position = UDim2.new(0,8,0,0)
                    sb.BackgroundTransparency = 1; sb.Font = Enum.Font.Gotham; sb.TextSize = 12
                    sb.TextColor3 = T.textPri; sb.PlaceholderText = "Search..."; sb.PlaceholderColor3 = T.textDim
                    sb.Text = ""; sb.TextXAlignment = Enum.TextXAlignment.Left; sb.ClearTextOnFocus = false
                    sb.ZIndex = 63; sb.Parent = sh
                    task.defer(function() sb:CaptureFocus() end)
                    sb:GetPropertyChangedSignal("Text"):Connect(function()
                        local q = sb.Text:lower()
                        for _, row in ipairs(dropFrame:GetChildren()) do
                            if row:IsA("Frame") and row ~= sh then
                                local lbl = row:FindFirstChildOfClass("TextLabel")
                                row.Visible = q == "" or (lbl and lbl.Text:lower():find(q,1,true) ~= nil)
                            end
                        end
                    end)
                end

                local listSF = scrollFrame(dropFrame, 61)
                listSF.Size = UDim2.new(1,0,1,-(searchable and 36 or 2))
                listSF.Position = UDim2.new(0,0,0,searchable and 36 or 2)
                listLayout(listSF, 2); pad(listSF, 2, 3, 2, 3)

                for _, opt in ipairs(options) do
                    local row = newFrame({ Size = UDim2.new(1,0,0,rowH), BackgroundColor3 = T.card, BackgroundTransparency = 1, ZIndex = 61, Parent = listSF })
                    corner(row, 6)
                    local chk = newFrame({ Size = UDim2.new(0,16,0,16), Position = UDim2.new(0,8,0.5,-8), BackgroundColor3 = selected[opt] and T.accent or T.input, ZIndex = 62, Parent = row })
                    corner(chk, 4); stroke(chk, selected[opt] and T.accent or T.border, 1)
                    if selected[opt] then
                        newLabel({ Size = UDim2.new(1,0,1,0), Text = "v", TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = T.white, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 63, Parent = chk })
                    end
                    newLabel({ Size = UDim2.new(1,-36,1,0), Position = UDim2.new(0,30,0,0), Text = opt, TextSize = 12, TextColor3 = selected[opt] and T.textPri or T.textSec, ZIndex = 62, Parent = row })
                    local hb = newBtn({ Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", ZIndex = 63, Parent = row })
                    hb.MouseEnter:Connect(function() tw(row, { BackgroundTransparency = 0, BackgroundColor3 = T.card }, 0.1) end)
                    hb.MouseLeave:Connect(function() tw(row, { BackgroundTransparency = 1 }, 0.1) end)
                    hb.MouseButton1Click:Connect(function()
                        selected[opt] = not selected[opt]
                        tw(chk, { BackgroundColor3 = selected[opt] and T.accent or T.input }, 0.15)
                        for _, ch in ipairs(chk:GetChildren()) do
                            if ch:IsA("UIStroke") then tw(ch, { Color = selected[opt] and T.accent or T.border }, 0.15) end
                            if ch:IsA("TextLabel") then ch.Visible = selected[opt] end
                        end
                        curLbl.Text = selText()
                        local list = {}
                        for k, v in pairs(selected) do if v then table.insert(list, k) end end
                        if cfg.Flag then savedValues[cfg.Flag] = list end
                        if cfg.Callback then cfg.Callback(list) end
                    end)
                end

                dropFrame.Size = UDim2.new(0,as.X,0,0)
                tw(dropFrame, { Size = UDim2.new(0,as.X,0,totalH) }, 0.2)

                if outsideConn then outsideConn:Disconnect() end
                outsideConn = UIS.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    task.wait()
                    if not dropFrame or not dropFrame:IsDescendantOf(game) then
                        closeM(); outsideConn:Disconnect()
                    end
                end)
            end

            c.MouseEnter:Connect(function() tw(c, { BackgroundColor3 = T.cardHov }, 0.12) end)
            c.MouseLeave:Connect(function() tw(c, { BackgroundColor3 = T.card    }, 0.12) end)

            local hb = newBtn({ Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = c })
            hb.MouseButton1Click:Connect(function() if isOpen then closeM() else isOpen = true; tw(chevron, { Rotation = 180 }, 0.15); openM() end end)

            local mdObj = {}
            function mdObj:Set(opts) selected = {}; for _, v in ipairs(opts) do selected[v] = true end; curLbl.Text = selText() end
            return mdObj
        end

        -- INPUT
        function Tab:CreateInput(cfg)
            cfg = cfg or {}
            local c = card(58)
            pad(c, 8, 12, 8, 12)

            newLabel({ Size = UDim2.new(1,0,0,16), Text = cfg.Name or "Input", TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = T.textSec, Parent = c })

            local ih = newFrame({ Size = UDim2.new(1,0,0,28), Position = UDim2.new(0,0,0,18), BackgroundColor3 = T.input, Parent = c })
            corner(ih, 6)
            local s = stroke(ih, T.border, 1)

            local box = Instance.new("TextBox")
            box.Size = UDim2.new(1,-16,1,0); box.Position = UDim2.new(0,8,0,0)
            box.BackgroundTransparency = 1; box.Font = Enum.Font.Gotham; box.TextSize = 13
            box.TextColor3 = T.textPri; box.PlaceholderText = cfg.PlaceholderText or "Type here..."
            box.PlaceholderColor3 = T.textDim; box.Text = cfg.DefaultValue or ""
            box.TextXAlignment = Enum.TextXAlignment.Left; box.ClearTextOnFocus = false; box.Parent = ih

            box.Focused:Connect(function()
                tw(ih, { BackgroundColor3 = Color3.fromRGB(12, 20, 12) }, 0.15)
                tw(s,  { Color = T.accent }, 0.15)
            end)
            box.FocusLost:Connect(function(entered)
                tw(ih, { BackgroundColor3 = T.input }, 0.15)
                tw(s,  { Color = T.border }, 0.15)
                if entered and cfg.Callback then cfg.Callback(box.Text) end
                if cfg.Flag then savedValues[cfg.Flag] = box.Text end
            end)

            local inputObj = {}
            function inputObj:Set(v) box.Text = v end
            if cfg.Flag then flagCbs[cfg.Flag] = function(v) inputObj:Set(v) end end
            return inputObj
        end

        -- PARAGRAPH
        function Tab:CreateParagraph(cfg)
            cfg = cfg or {}
            local lines    = select(2, (cfg.Content or ""):gsub("\n", "")) + 1
            local bodyH    = lines * 16
            local hasTitle = cfg.Title and cfg.Title ~= ""
            local totalH   = math.max((hasTitle and 34 or 10) + bodyH, 48)
            local c        = card(totalH)
            pad(c, 10, 12, 10, 12)

            if hasTitle then
                newLabel({ Size = UDim2.new(1,0,0,18), Text = cfg.Title, TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = T.textPri, Parent = c })
            end
            newLabel({
                Size           = UDim2.new(1,0,0,bodyH),
                Position       = UDim2.new(0,0,0,hasTitle and 24 or 0),
                Text           = cfg.Content or "",
                TextSize       = 12,
                TextColor3     = T.textSec,
                TextWrapped    = true,
                TextYAlignment = Enum.TextYAlignment.Top,
                Parent         = c,
            })
        end

        -- KEYBIND
        function Tab:CreateKeybind(cfg)
            cfg = cfg or {}
            local cur       = cfg.CurrentKeybind or "None"
            local listening = false
            local c         = card(44)
            pad(c, 0, 12, 0, 12)

            newLabel({ Size = UDim2.new(0.55,0,1,0), Text = cfg.Name or "Keybind", TextSize = 13, Font = Enum.Font.GothamSemibold, Parent = c })

            local kd = newFrame({ Size = UDim2.new(0,90,0,28), Position = UDim2.new(1,-90,0.5,-14), BackgroundColor3 = T.input, Parent = c })
            corner(kd, 6); stroke(kd, T.border, 1)

            local kLbl = newLabel({ Size = UDim2.new(1,0,1,0), Text = cur, TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = T.accent, TextXAlignment = Enum.TextXAlignment.Center, Parent = kd })

            local hb = newBtn({ Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", ZIndex = 2, Parent = c })
            c.MouseEnter:Connect(function() tw(c, { BackgroundColor3 = T.cardHov }, 0.12) end)
            c.MouseLeave:Connect(function() tw(c, { BackgroundColor3 = T.card    }, 0.12) end)

            hb.MouseButton1Click:Connect(function()
                if listening then return end
                listening = true; kLbl.Text = "..."; tw(kLbl, { TextColor3 = T.warning }, 0.1)
                local conn
                conn = UIS.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        cur = tostring(input.KeyCode):gsub("Enum.KeyCode.", ""); kLbl.Text = cur; tw(kLbl, { TextColor3 = T.accent }, 0.1)
                        listening = false; conn:Disconnect()
                        if cfg.Flag then savedValues[cfg.Flag] = cur end
                        if cfg.Callback then cfg.Callback(input.KeyCode) end
                    end
                end)
            end)

            local kbObj = {}
            function kbObj:Set(key) cur = tostring(key):gsub("Enum.KeyCode.", ""); kLbl.Text = cur end
            return kbObj
        end

        return Tab
    end

    -- Window-level methods
    function Window:Notify(cfg)
        cfg = cfg or {}
        notify(cfg.Title or "", cfg.Content or "", cfg.Type, cfg.Duration)
    end

    function Window:LoadConfiguration()
        if not (config.ConfigurationSaving and config.ConfigurationSaving.Enabled) then return end
        local data = loadCfg(cfgFolder, cfgFile)
        for flag, val in pairs(data) do
            savedValues[flag] = val
            if flagCbs[flag] then pcall(flagCbs[flag], val) end
        end
    end

    return Window
end

return ESLib