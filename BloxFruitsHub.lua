-- ██████████████████████████████████████████████████████
--           Extreme Solutions | Blox Fruits Hub
--                      By Tzqy
--              Rayfield UI — Full BF Edition (v3)
-- ██████████████████████████████████████████████████████

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ══════════════════════════════════════════════════════
--  WINDOW
-- ══════════════════════════════════════════════════════

local Window = Rayfield:CreateWindow({
    Name                  = "Extreme Solutions | Blox Fruits",
    Icon                  = "sword",
    LoadingTitle          = "Extreme Solutions Hub",
    LoadingSubtitle       = "Blox Fruits  ·  Loading...",
    Theme                 = "DarkBlue",
    ToggleUIKeybind       = "K",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings  = true,
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "ExtremeSolutions",
        FileName   = "BloxFruitsHub"
    },
    Discord = {
        Enabled      = true,
        Invite       = "yourserver",    -- replace with your actual Discord invite code
        RememberJoins = true
    },
    KeySystem = false,
})

-- ══════════════════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService  = game:GetService("TeleportService")
local Workspace        = game:GetService("Workspace")
local HttpService      = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- ══════════════════════════════════════════════════════
--  TABS
-- ══════════════════════════════════════════════════════

local PlayerTab   = Window:CreateTab("Player",    "user")
local FarmTab     = Window:CreateTab("Auto Farm", "swords")
local TeleportTab = Window:CreateTab("Teleport",  "map-pin")
local FruitTab    = Window:CreateTab("ESP",        "eye")
local VisualTab   = Window:CreateTab("Visuals",   "palette")
local MiscTab     = Window:CreateTab("Misc",       "settings")

-- ══════════════════════════════════════════════════════
--  GLOBAL STATE
-- ══════════════════════════════════════════════════════

getgenv().BF = getgenv().BF or {}
local S = getgenv().BF

-- Movement
S.SpeedValue       = 16
S.JumpValue        = 50
S.InfJump          = false
S.NoClip           = false
S.AntiKB           = false

-- Survival
S.GodMode          = false

-- Farm
S.AutoFarm         = false
S.AutoFarmBoss     = false
S.AutoMastery      = false
S.FarmTarget       = "Bandits"
S.FarmRadius       = 40
S.AttackInterval   = 0.4
S.FlySpeed         = 80   -- fly-to-enemy speed
S.HitRange         = 10
S.BossTarget       = "Greybeard"

-- Fruit
S.FruitESP         = false
S.AutoCollectFruit = false

-- ESP
S.PlayerESP        = false
S.ChestESP         = false

-- ESP Customisation (defaults)
S.ESP_FruitColor   = Color3.fromRGB(255, 80, 80)
S.ESP_PlayerColor  = Color3.fromRGB(80, 200, 255)
S.ESP_ChestColor   = Color3.fromRGB(255, 215, 0)
S.ESP_TextSize     = 14
S.ESP_BgTransp     = 0.45
S.ESP_ShowDist     = true

-- Misc
S.FullBright       = false
S.AntiAFK          = false

local connections = {}
local espObjects  = {}

-- ══════════════════════════════════════════════════════
--  CORE HELPERS
-- ══════════════════════════════════════════════════════

local function getChar()  return player.Character end
local function getRoot()
    local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid")
end

local function disconnectKey(key)
    if connections[key] then
        pcall(function() connections[key]:Disconnect() end)
        connections[key] = nil
    end
end

local function notify(title, content, image)
    Rayfield:Notify({
        Title    = title,
        Content  = content,
        Duration = 3,
        Image    = image or 4483362458,
    })
end

-- ══════════════════════════════════════════════════════
--  SPEED ENFORCE (Heartbeat)
--  FIX: Re-applies speed/jump every Heartbeat so the
--       server can never reset it between frames.
-- ══════════════════════════════════════════════════════

local speedEnforceConn = nil

local function startSpeedEnforce()
    if speedEnforceConn then
        pcall(function() speedEnforceConn:Disconnect() end)
    end
    speedEnforceConn = RunService.Heartbeat:Connect(function()
        local h = getHum()
        if not h then return end
        -- Only write when mismatched to avoid unnecessary sets
        if h.WalkSpeed ~= S.SpeedValue then
            h.WalkSpeed = S.SpeedValue
        end
        if h.JumpPower ~= S.JumpValue then
            h.JumpPower = S.JumpValue
        end
    end)
end

startSpeedEnforce()

-- ══════════════════════════════════════════════════════
--  TELEPORT  (Anchored lock)
--  FIX: Anchor root → set CFrame → unanchor after delay
--       Uses a proper sequence so physics can't fight us.
-- ══════════════════════════════════════════════════════

local function tpTo(cf, anchorTime)
    anchorTime = anchorTime or 0
    local root = getRoot()
    if not root then return end

    -- Disable physics momentarily
    root.Anchored = true
    root.CFrame   = cf
    -- Double-set to survive one physics step
    task.wait()
    local r2 = getRoot()
    if r2 then
        r2.CFrame = cf
    end

    if anchorTime > 0 then
        task.delay(anchorTime, function()
            local r = getRoot()
            if r then r.Anchored = false end
        end)
    else
        local r = getRoot()
        if r then r.Anchored = false end
    end
end

-- ══════════════════════════════════════════════════════
--  FLY LOCOMOTION
--  Smoothly moves the character toward a target CFrame
--  using Heartbeat + BodyVelocity so it looks like flying.
-- ══════════════════════════════════════════════════════

local function flyTo(targetCF, reachedCallback)
    local root = getRoot()
    if not root then
        if reachedCallback then reachedCallback() end
        return
    end

    -- Remove any old BodyVelocity/BodyGyro we left
    for _, v in ipairs(root:GetChildren()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end
    end

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent   = root

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.CFrame    = targetCF
    bg.Parent    = root

    local conn
    conn = RunService.Heartbeat:Connect(function()
        local r = getRoot()
        if not r then
            pcall(function() bv:Destroy() bg:Destroy() end)
            conn:Disconnect()
            if reachedCallback then reachedCallback() end
            return
        end

        local diff = targetCF.Position - r.Position
        local dist = diff.Magnitude

        if dist < 3 then
            bv.Velocity = Vector3.zero
            pcall(function() bv:Destroy() bg:Destroy() end)
            conn:Disconnect()
            if reachedCallback then reachedCallback() end
            return
        end

        bv.Velocity = diff.Unit * math.min(S.FlySpeed, dist * 8)
        bg.CFrame   = CFrame.new(r.Position, targetCF.Position)
    end)

    return conn
end

-- ══════════════════════════════════════════════════════
--  WILD FRUIT DETECTION
--  FIX: Only pick up fruits that are ON THE GROUND
--       (i.e., not inside GachaMachine / GamePasses /
--        ReplicatedStorage / StarterPack, etc.)
--  We check the parent ancestry — a wild fruit lives
--  somewhere under Workspace but NOT in known gacha
--  containers.
-- ══════════════════════════════════════════════════════

local GACHA_BLACKLIST = {
    "GachaMachine", "GachaResults", "GachaFruits",
    "ShopFruits", "ShopGui", "FruitShop",
    "Inventory", "StarterPack", "ReplicatedStorage",
    "ServerStorage", "ReplicatedFirst",
}

local function isBlacklisted(obj)
    local cur = obj
    for _ = 1, 15 do
        if not cur or not cur.Parent then break end
        for _, bl in ipairs(GACHA_BLACKLIST) do
            if cur.Name:lower():find(bl:lower()) then
                return true
            end
        end
        -- If we've reached Workspace root that's fine
        if cur == Workspace then return false end
        cur = cur.Parent
    end
    return false
end

-- Wild fruits in Blox Fruits are models that:
-- 1. Live somewhere under Workspace
-- 2. Have a ClickDetector or ProximityPrompt (pickup trigger)
-- 3. Are NOT inside a known gacha/shop container

local FRUIT_KEYWORDS = {
    -- Generic
    "fruit","devil fruit",
    -- Common / Uncommon
    "kilo","bomb","spike","spring","chop",
    -- Rare
    "smoke","flame","ice","sand","dark","diamond","light",
    "rubber","barrier","magma","quake","door","gravity",
    -- Legendary
    "buddha","love","spider","sound","phoenix","blizzard",
    "rumble","paw","revive","venom","control","spirit",
    -- Mythical
    "dragon","leopard","kitsune","dough","shadow","mammoth",
    "t-rex","gas","portal","ope","venom","soul",
    -- Rarity tags (some servers label fruits this way)
    "mythical","legendary","rare","uncommon","common",
}

local function isFruitName(name)
    local low = name:lower()
    for _, kw in ipairs(FRUIT_KEYWORDS) do
        if low:find(kw) then return true end
    end
    return false
end

local function isWildFruit(obj)
    if not (obj:IsA("Model") or obj:IsA("BasePart")) then return false end
    if not isFruitName(obj.Name) then return false end
    if isBlacklisted(obj) then return false end

    -- Must be a descendant of Workspace
    local inWS = false
    local cur  = obj.Parent
    for _ = 1, 20 do
        if cur == Workspace then inWS = true; break end
        if cur == nil or cur == game then break end
        cur = cur.Parent
    end
    if not inWS then return false end

    -- Must have a pickup mechanism
    local hasPickup = false
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("ClickDetector") or d:IsA("ProximityPrompt") then
            hasPickup = true; break
        end
    end
    -- Some fruits fire a RemoteEvent directly on touch
    if not hasPickup then
        if obj:FindFirstChildOfClass("RemoteEvent") then
            hasPickup = true
        end
    end
    return hasPickup
end

-- ══════════════════════════════════════════════════════
--  ENEMY CACHE  (debounced, TTL 1.5s)
-- ══════════════════════════════════════════════════════

local CACHE_TTL    = 1.5
local enemyCache   = {}
local lastScanTime = 0

local function invalidateCache() lastScanTime = 0 end

local function rebuildEnemyCache()
    local t = tick()
    if t - lastScanTime < CACHE_TTL then return end
    lastScanTime = t
    local newCache = {}
    local myChar   = getChar()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= myChar then
            local h = obj:FindFirstChildOfClass("Humanoid")
            local r = obj:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 then
                table.insert(newCache, {
                    model = obj,
                    root  = r,
                    hum   = h,
                    name  = obj.Name:lower()
                })
            end
        end
    end
    enemyCache = newCache
end

local function findNearestEnemy(targetName, overrideRadius)
    rebuildEnemyCache()
    local myRoot = getRoot()
    if not myRoot then return nil, nil end
    local targetLower = tostring(targetName or S.FarmTarget):lower()
    local maxDist     = overrideRadius or S.FarmRadius
    local closest, closestDist, closestRoot = nil, maxDist + 1, nil
    for _, entry in ipairs(enemyCache) do
        if entry.name:find(targetLower, 1, true) then
            if entry.hum and entry.hum.Health > 0
                and entry.root and entry.root.Parent
            then
                local dist = (myRoot.Position - entry.root.Position).Magnitude
                if dist < closestDist then
                    closestDist  = dist
                    closest      = entry.model
                    closestRoot  = entry.root
                end
            end
        end
    end
    return closest, closestRoot
end

-- ══════════════════════════════════════════════════════
--  ATTACK
-- ══════════════════════════════════════════════════════

local function attackEnemy(enemy, eRoot)
    if not enemy or not eRoot then return end
    local char = getChar(); if not char then return end

    for _, d in ipairs(enemy:GetDescendants()) do
        if d:IsA("ClickDetector") then pcall(fireclickdetector, d) end
    end
    for _, d in ipairs(enemy:GetDescendants()) do
        if d:IsA("ProximityPrompt") then pcall(fireproximityprompt, d) end
    end

    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then
        tool = player.Backpack:FindFirstChildOfClass("Tool")
        if tool then tool.Parent = char; task.wait(0.05) end
    end
    if tool then
        pcall(function() tool:Activate() end)
        for _, r in ipairs(tool:GetDescendants()) do
            if r:IsA("RemoteEvent") then
                pcall(function() r:FireServer(eRoot.CFrame) end)
                break
            end
        end
    end
end

-- ══════════════════════════════════════════════════════
--  SHARED FLY-FARM LOOP
--  FIX: No teleport. Fly to the enemy using BodyVelocity,
--       wait until close, then attack. Minimum 0.3s cycle.
-- ══════════════════════════════════════════════════════

local function runFlyFarm(targetNameGetter, activeFlag, overrideRadius)
    task.spawn(function()
        while activeFlag() do
            local targetName         = targetNameGetter()
            local maxR               = overrideRadius and overrideRadius() or nil
            local enemy, eRoot       = findNearestEnemy(targetName, maxR)

            if enemy and eRoot then
                -- Fly toward enemy
                local attackPos = eRoot.CFrame * CFrame.new(0, 0, -3.5)
                local arrived   = false

                local flyConn = flyTo(attackPos, function() arrived = true end)

                -- Wait until arrived or enemy dies / disappears
                local timeout = tick() + 8
                while not arrived and tick() < timeout and activeFlag() do
                    -- Check enemy still alive
                    local h = enemy:FindFirstChildOfClass("Humanoid")
                    if not h or h.Health <= 0 or not eRoot.Parent then
                        if flyConn then pcall(function() flyConn:Disconnect() end) end
                        -- Clean up body movers
                        local r = getRoot()
                        if r then
                            for _, v in ipairs(r:GetChildren()) do
                                if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end
                            end
                        end
                        invalidateCache()
                        break
                    end
                    task.wait(0.05)
                end

                -- Attack if still valid
                if arrived and activeFlag() then
                    local freshRoot = enemy:FindFirstChild("HumanoidRootPart")
                    if freshRoot then
                        attackEnemy(enemy, freshRoot)
                    end
                end
            else
                invalidateCache()
                task.wait(1.5)
            end

            task.wait(math.max(0.3, S.AttackInterval))
        end

        -- Cleanup body movers when farm stops
        local r = getRoot()
        if r then
            for _, v in ipairs(r:GetChildren()) do
                if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════
--  ESP HELPERS
-- ══════════════════════════════════════════════════════

local function makeESPGui(adornee, text, color)
    local bb = Instance.new("BillboardGui")
    bb.AlwaysOnTop  = true
    bb.Size         = UDim2.new(0, 160, 0, 44)
    bb.StudsOffset  = Vector3.new(0, 3.5, 0)
    bb.Adornee      = adornee
    bb.Parent       = adornee

    local frame = Instance.new("Frame")
    frame.Size                   = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = S.ESP_BgTransp
    frame.BorderSizePixel        = 0
    frame.Parent                 = bb

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent       = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -6, 1, 0)
    lbl.Position               = UDim2.new(0, 3, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = color or Color3.fromRGB(255, 255, 255)
    lbl.TextSize               = S.ESP_TextSize
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.TextWrapped            = true
    lbl.Text                   = text
    lbl.Parent                 = frame

    return bb, lbl
end

local function clearESP(tag)
    if espObjects[tag] then
        for _, gui in ipairs(espObjects[tag]) do
            pcall(function() gui:Destroy() end)
        end
        espObjects[tag] = {}
    end
end

-- ══════════════════════════════════════════════════════
--  SECTION: PLAYER TAB
-- ══════════════════════════════════════════════════════

PlayerTab:CreateSection("Movement")

local SpeedSlider = PlayerTab:CreateSlider({
    Name         = "Walk Speed",
    Range        = {16, 500},
    Increment    = 1,
    Suffix       = " studs/s",
    CurrentValue = S.SpeedValue,
    Flag         = "SpeedSlider",
    Callback = function(v)
        S.SpeedValue = v
        -- Direct set too, enforce picks it up instantly
        local h = getHum()
        if h then h.WalkSpeed = v end
    end
})

PlayerTab:CreateButton({
    Name = "Reset Speed",
    Callback = function()
        S.SpeedValue = 16
        SpeedSlider:Set(16)
        local h = getHum(); if h then h.WalkSpeed = 16 end
        notify("Speed Reset", "Walk speed reset to 16.")
    end
})

local JumpSlider = PlayerTab:CreateSlider({
    Name         = "Jump Power",
    Range        = {50, 500},
    Increment    = 1,
    Suffix       = " power",
    CurrentValue = S.JumpValue,
    Flag         = "JumpSlider",
    Callback = function(v)
        S.JumpValue = v
        local h = getHum()
        if h then h.JumpPower = v end
    end
})

PlayerTab:CreateButton({
    Name = "Reset Jump",
    Callback = function()
        S.JumpValue = 50
        JumpSlider:Set(50)
        local h = getHum(); if h then h.JumpPower = 50 end
        notify("Jump Reset", "Jump power reset to 50.")
    end
})

PlayerTab:CreateToggle({
    Name         = "Infinite Jump",
    CurrentValue = false,
    Flag         = "InfJump",
    Callback = function(v)
        S.InfJump = v
        disconnectKey("infJump")
        if v then
            connections["infJump"] = UserInputService.JumpRequest:Connect(function()
                local h = getHum()
                if h and h:GetState() ~= Enum.HumanoidStateType.Dead then
                    h:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
        end
        notify("Infinite Jump", v and "Enabled." or "Disabled.")
    end
})

PlayerTab:CreateToggle({
    Name         = "No Clip",
    CurrentValue = false,
    Flag         = "NoClip",
    Callback = function(v)
        S.NoClip = v
        disconnectKey("noClip")
        if v then
            connections["noClip"] = RunService.Stepped:Connect(function()
                local c = getChar(); if not c then return end
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end)
        else
            local c = getChar()
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = true end
                end
            end
        end
        notify("No Clip", v and "Enabled." or "Disabled.")
    end
})

PlayerTab:CreateSection("Survival")

local function applyGodMode(char)
    disconnectKey("godMode")
    local h = char:WaitForChild("Humanoid", 5)
    if not h then return end
    if S.GodMode then
        h.Health = h.MaxHealth
        connections["godMode"] = h.HealthChanged:Connect(function(hp)
            if hp < h.MaxHealth then h.Health = h.MaxHealth end
        end)
    end
end

PlayerTab:CreateToggle({
    Name         = "God Mode",
    CurrentValue = false,
    Flag         = "GodMode",
    Callback = function(v)
        S.GodMode = v
        local c = getChar(); if c then applyGodMode(c) end
        notify("God Mode", v and "Invincible." or "Mortal.", 4483345998)
    end
})

PlayerTab:CreateToggle({
    Name         = "Anti Knock-back",
    CurrentValue = false,
    Flag         = "AntiKB",
    Callback = function(v)
        S.AntiKB = v
        disconnectKey("antiKB")
        if v then
            connections["antiKB"] = RunService.Heartbeat:Connect(function()
                local root = getRoot()
                if root then root.Velocity = Vector3.new(0, root.Velocity.Y, 0) end
            end)
        end
        notify("Anti Knock-back", v and "Enabled." or "Disabled.")
    end
})

PlayerTab:CreateSection("Combat")

PlayerTab:CreateSlider({
    Name         = "Hit Range (studs)",
    Range        = {5, 100},
    Increment    = 1,
    Suffix       = " studs",
    CurrentValue = 10,
    Flag         = "HitRange",
    Callback = function(v) S.HitRange = v end
})

-- ══════════════════════════════════════════════════════
--  FARM TAB
-- ══════════════════════════════════════════════════════

FarmTab:CreateSection("Enemy Auto Farm")

local enemyOptions = {
    -- First Sea
    "Bandits","Monkeys","Pirates","Marines",
    "Desert Bandits","Snow Bandits","Skylands Guards",
    "Prisoners","Gladiators","Magma Ninjas",
    "Fishmen","Raiders","Zombies","Vampires",
    "Snow Troops","Dragon Crew","Pirate Millionaires",
    "Rip Indra's Crew",
    -- Second Sea
    "Galley Pirates","Jungle Pirates","Forest Pirates",
    "Laboratory Subordinates","Penguins","Snow Demons",
    "Reef Pirates","Ship Engineers","Arctic Warriors",
    "Ice Cream Zombie","Cake Sea Bandits","Bon Clays",
    -- Third Sea
    "Ability Teachers","Longma's Crew","Wandering Pirates",
    "Yakuza","Cyborg Pirates","Eye Pirates",
    "Magma Pirates","Crystal Pirates","Tiki Outpost Pirates",
    "Wereravens","Cake Guards","Leviathan Pirates"
}

FarmTab:CreateDropdown({
    Name          = "Target Enemy",
    Options       = enemyOptions,
    CurrentOption = {"Bandits"},
    Flag          = "FarmTarget",
    Callback = function(opt)
        S.FarmTarget = type(opt) == "table" and opt[1] or opt
        invalidateCache()
        notify("Farm Target", "Now targeting: " .. tostring(S.FarmTarget))
    end
})

FarmTab:CreateSlider({
    Name         = "Farm Radius",
    Range        = {10, 500},
    Increment    = 5,
    Suffix       = " studs",
    CurrentValue = 40,
    Flag         = "FarmRadius",
    Callback = function(v) S.FarmRadius = v end
})

FarmTab:CreateSlider({
    Name         = "Fly Speed",
    Range        = {20, 300},
    Increment    = 5,
    Suffix       = " studs/s",
    CurrentValue = 80,
    Flag         = "FlySpeed",
    Callback = function(v) S.FlySpeed = v end
})

FarmTab:CreateSlider({
    Name         = "Attack Interval (ms)",
    Range        = {200, 2000},
    Increment    = 50,
    Suffix       = " ms",
    CurrentValue = 400,
    Flag         = "AttackInterval",
    Callback = function(v) S.AttackInterval = v / 1000 end
})

FarmTab:CreateToggle({
    Name         = "Auto Farm (Fly)",
    CurrentValue = false,
    Flag         = "AutoFarm",
    Callback = function(v)
        S.AutoFarm = v
        if v then
            invalidateCache()
            notify("Auto Farm", "Flying to: " .. tostring(S.FarmTarget), 4483345998)
            runFlyFarm(
                function() return S.FarmTarget end,
                function() return S.AutoFarm end,
                nil
            )
        else
            -- Body movers cleaned in runFlyFarm on exit
            notify("Auto Farm", "Stopped.")
        end
    end
})

FarmTab:CreateSection("Mastery Farm")

FarmTab:CreateToggle({
    Name         = "Auto Mastery Farm",
    CurrentValue = false,
    Flag         = "AutoMastery",
    Callback = function(v)
        S.AutoMastery = v
        if v then
            notify("Mastery Farm", "Enabled. Equip your weapon/fruit.", 4483345998)
            invalidateCache()
            runFlyFarm(
                function() return S.FarmTarget end,
                function() return S.AutoMastery end,
                nil
            )
        else
            notify("Mastery Farm", "Stopped.")
        end
    end
})

FarmTab:CreateSection("Boss Farm")

local bossOptions = {
    -- First Sea
    "Gorilla King","Bobby","Yeti","Vice Admiral","Greybeard",
    "Thunder God","Chief Warden","Swan","Magma Admiral",
    "Fishman Lord","Cyborg","Diamond","Jeremy","Fajita",
    "Darkbeard","Smoke Admiral","Ice Admiral","Tide Keeper",
    "Stone","Rip Indra",
    -- Second Sea
    "Island Empress","Kilo Admiral","Captain Elephant",
    "Soul Reaper","Cake Prince","Cursed Captain",
    "Awakened Ice Admiral","Dough King",
    -- Third Sea
    "Longma","Cake Queen","Golden Gladiator",
    "The Shark","Wandering Pirate","Leviathan",
    "Order","Bartilo","Chinjao","Don Swan"
}

FarmTab:CreateDropdown({
    Name          = "Boss Target",
    Options       = bossOptions,
    CurrentOption = {"Greybeard"},
    Flag          = "BossTarget",
    Callback = function(opt)
        S.BossTarget = type(opt) == "table" and opt[1] or opt
        invalidateCache()
        notify("Boss Target", "Set: " .. tostring(S.BossTarget))
    end
})

FarmTab:CreateToggle({
    Name         = "Auto Boss Farm",
    CurrentValue = false,
    Flag         = "AutoBossFarm",
    Callback = function(v)
        S.AutoFarmBoss = v
        if v then
            notify("Boss Farm", "Hunting: " .. tostring(S.BossTarget), 4483345998)
            invalidateCache()
            runFlyFarm(
                function() return S.BossTarget end,
                function() return S.AutoFarmBoss end,
                function() return 99999 end   -- unlimited radius for bosses
            )
        else
            notify("Boss Farm", "Stopped.")
        end
    end
})

-- ══════════════════════════════════════════════════════
--  TELEPORT TAB
-- ══════════════════════════════════════════════════════

local islands = {
    -- ── First Sea ──────────────────────────────────────
    ["Starter Island"]    = CFrame.new(-1324,  4,   -57),
    ["Middle Town"]       = CFrame.new(  314, 15,   553),
    ["Jungle"]            = CFrame.new( 1513,126,  1754),
    ["Pirate Village"]    = CFrame.new(-1000, 15,  1000),
    ["Desert"]            = CFrame.new(  936, 15,  4139),
    ["Frozen Village"]    = CFrame.new( 1356, 15, -3218),
    ["Marine Fortress"]   = CFrame.new(-3460, 15,  -570),
    ["Skylands"]          = CFrame.new(-5033,425, -2600),
    ["Prison"]            = CFrame.new( 4839, 15,   700),
    ["Colosseum"]         = CFrame.new(-2890,  8,  3441),
    ["Magma Village"]     = CFrame.new( 3118,167,  -479),
    ["Underwater City"]   = CFrame.new(-3000,-75, -3000),
    ["Fountain City"]     = CFrame.new( 3767, 60,  3882),
    -- ── Second Sea ─────────────────────────────────────
    ["Kingdom of Rose"]   = CFrame.new( -248, 15, -3049),
    ["Café"]              = CFrame.new( -630, 75, -3250),
    ["Green Zone"]        = CFrame.new( 4310, 15, -3849),
    ["Graveyard"]         = CFrame.new(-4474,  8, -3540),
    ["Snow Mountain"]     = CFrame.new(-1478,165, -6306),
    ["Hot and Cold"]      = CFrame.new(-5025, 15, -6300),
    ["Cursed Ship"]       = CFrame.new(-5000,  5, -4000),
    ["Ice Castle"]        = CFrame.new(-4540, 15, -8000),
    ["Forgotten Island"]  = CFrame.new( 2580,  8, -7000),
    ["Dark Arena"]        = CFrame.new( 6000,  8, -3060),
    ["Mansion"]           = CFrame.new(  490, 95, -3050),
    -- ── Third Sea ──────────────────────────────────────
    ["Port Town"]         = CFrame.new(-5755, 15,  -895),
    ["Hydra Island"]      = CFrame.new(-4370, 15,  4310),
    ["Great Tree"]        = CFrame.new(-8050, 75,  -540),
    ["Floating Turtle"]   = CFrame.new(-12245,305, -1500),
    ["Castle on Sea"]     = CFrame.new(-9000, 15,  3500),
    ["Haunted Castle"]    = CFrame.new(-14500, 8,  3900),
    ["Sea of Treats"]     = CFrame.new(-5500, 15,  8000),
    ["Tiki Outpost"]      = CFrame.new(-10000,15,  6500),
    ["Mirage Island"]     = CFrame.new(-14900,15,  -350),
    ["Longma Island"]     = CFrame.new(-8790, 20,  2760),
}

TeleportTab:CreateSection("First Sea")
for _, name in ipairs({
    "Starter Island","Middle Town","Jungle","Pirate Village","Desert",
    "Frozen Village","Marine Fortress","Skylands","Prison","Colosseum",
    "Magma Village","Underwater City","Fountain City"
}) do
    local n = name
    TeleportTab:CreateButton({
        Name = "-> " .. n,
        Callback = function()
            local cf = islands[n]
            if cf then
                tpTo(cf + Vector3.new(0, 5, 0), 0.6)
                notify("Teleported", "Arrived at " .. n)
            end
        end
    })
end

TeleportTab:CreateSection("Second Sea")
for _, name in ipairs({
    "Kingdom of Rose","Café","Mansion","Green Zone","Graveyard",
    "Snow Mountain","Hot and Cold","Cursed Ship","Ice Castle",
    "Forgotten Island","Dark Arena"
}) do
    local n = name
    TeleportTab:CreateButton({
        Name = "-> " .. n,
        Callback = function()
            local cf = islands[n]
            if cf then
                tpTo(cf + Vector3.new(0, 5, 0), 0.6)
                notify("Teleported", "Arrived at " .. n)
            end
        end
    })
end

TeleportTab:CreateSection("Third Sea")
for _, name in ipairs({
    "Port Town","Hydra Island","Great Tree","Floating Turtle",
    "Castle on Sea","Haunted Castle","Sea of Treats","Tiki Outpost",
    "Mirage Island","Longma Island"
}) do
    local n = name
    TeleportTab:CreateButton({
        Name = "-> " .. n,
        Callback = function()
            local cf = islands[n]
            if cf then
                tpTo(cf + Vector3.new(0, 5, 0), 0.6)
                notify("Teleported", "Arrived at " .. n)
            end
        end
    })
end

TeleportTab:CreateSection("Quick Actions")

TeleportTab:CreateButton({
    Name = "Teleport to Nearest NPC",
    Callback = function()
        local root = getRoot(); if not root then return end
        local nearest, nearestDist = nil, math.huge
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj ~= getChar() then
                local h = obj:FindFirstChildOfClass("Humanoid")
                local r = obj:FindFirstChild("HumanoidRootPart")
                if h and r then
                    local d = (root.Position - r.Position).Magnitude
                    if d < nearestDist then nearestDist = d; nearest = r end
                end
            end
        end
        if nearest then
            tpTo(nearest.CFrame * CFrame.new(0, 0, -4), 0.5)
            notify("Teleported", "Moved to nearest NPC.")
        else
            notify("Failed", "No NPC found nearby.")
        end
    end
})

TeleportTab:CreateButton({
    Name = "Teleport to Nearest Player",
    Callback = function()
        local root = getRoot(); if not root then return end
        local nearest, nearestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local r = p.Character:FindFirstChild("HumanoidRootPart")
                if r then
                    local d = (root.Position - r.Position).Magnitude
                    if d < nearestDist then nearestDist = d; nearest = r end
                end
            end
        end
        if nearest then
            tpTo(nearest.CFrame * CFrame.new(4, 0, 0), 0.5)
            notify("Teleported", "Moved to nearest player.")
        else
            notify("Failed", "No other player found.")
        end
    end
})

-- ══════════════════════════════════════════════════════
--  FRUIT ESP TAB
-- ══════════════════════════════════════════════════════

FruitTab:CreateSection("Wild Fruit ESP")

FruitTab:CreateToggle({
    Name         = "Wild Fruit ESP",
    CurrentValue = false,
    Flag         = "FruitESP",
    Callback = function(v)
        S.FruitESP = v
        clearESP("fruits")
        espObjects["fruits"] = {}

        if v then
            task.spawn(function()
                while S.FruitESP do
                    clearESP("fruits")
                    local myRoot = getRoot()
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if isWildFruit(obj) then
                            local part = obj:IsA("Model")
                                and (obj:FindFirstChild("Handle") or obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart"))
                                or obj
                            if part and part.Parent then
                                local dist = myRoot
                                    and math.floor((myRoot.Position - part.Position).Magnitude)
                                    or 0
                                local label = "[FRUIT] " .. obj.Name
                                if S.ESP_ShowDist then label = label .. "\n" .. dist .. " studs" end
                                local gui, _ = makeESPGui(part, label, S.ESP_FruitColor)
                                table.insert(espObjects["fruits"], gui)
                            end
                        end
                    end
                    task.wait(4)
                end
                clearESP("fruits")
            end)
            notify("Fruit ESP", "Scanning for wild fruits only.", 4483362458)
        else
            notify("Fruit ESP", "Disabled.")
        end
    end
})

FruitTab:CreateToggle({
    Name         = "Auto Collect Wild Fruit",
    CurrentValue = false,
    Flag         = "AutoCollect",
    Callback = function(v)
        S.AutoCollectFruit = v
        if v then
            task.spawn(function()
                while S.AutoCollectFruit do
                    local root = getRoot()
                    if root then
                        local found = {}
                        for _, obj in ipairs(Workspace:GetDescendants()) do
                            if isWildFruit(obj) then
                                local part = obj:IsA("Model")
                                    and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart"))
                                    or obj
                                if part and part.Parent then
                                    local dist = (root.Position - part.Position).Magnitude
                                    table.insert(found, { obj = obj, part = part, dist = dist })
                                end
                            end
                        end

                        -- Sort by closest first
                        table.sort(found, function(a, b) return a.dist < b.dist end)

                        for _, entry in ipairs(found) do
                            if not S.AutoCollectFruit then break end
                            local obj  = entry.obj
                            local part = entry.part
                            if part and part.Parent then
                                tpTo(part.CFrame + Vector3.new(0, 3, 0), 0)
                                task.wait(0.35)
                                local parentObj = obj:IsA("Model") and obj or obj.Parent
                                for _, d in ipairs(parentObj:GetDescendants()) do
                                    if d:IsA("ClickDetector") then pcall(fireclickdetector, d) end
                                    if d:IsA("ProximityPrompt") then pcall(fireproximityprompt, d) end
                                end
                                local remote = parentObj:FindFirstChildOfClass("RemoteEvent")
                                if remote then pcall(function() remote:FireServer() end) end
                                task.wait(0.5)
                            end
                        end
                    end
                    task.wait(3)
                end
            end)
            notify("Auto Collect", "Collecting wild fruits only.", 4483362458)
        else
            notify("Auto Collect", "Stopped.")
        end
    end
})

FruitTab:CreateSection("Player ESP")

local playerESPLabels = {}

local function removePlayerESP(p)
    if playerESPLabels[p] then
        pcall(function() playerESPLabels[p].gui:Destroy() end)
        playerESPLabels[p] = nil
    end
end

FruitTab:CreateToggle({
    Name         = "Player ESP",
    CurrentValue = false,
    Flag         = "PlayerESP",
    Callback = function(v)
        S.PlayerESP = v
        disconnectKey("playerESP")
        for p, _ in pairs(playerESPLabels) do removePlayerESP(p) end
        playerESPLabels = {}

        if v then
            task.spawn(function()
                while S.PlayerESP do
                    local myRoot = getRoot()
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= player and p.Character then
                            local root = p.Character:FindFirstChild("HumanoidRootPart")
                            local hum  = p.Character:FindFirstChildOfClass("Humanoid")
                            if root and hum then
                                local dist = myRoot
                                    and math.floor((myRoot.Position - root.Position).Magnitude)
                                    or 0
                                local text = "[" .. p.Name .. "]"
                                    .. "\nHP: " .. math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                                if S.ESP_ShowDist then text = text .. "\n" .. dist .. " studs" end

                                if playerESPLabels[p] then
                                    pcall(function()
                                        playerESPLabels[p].lbl.Text  = text
                                        playerESPLabels[p].gui.Adornee = root
                                    end)
                                else
                                    local gui, lbl = makeESPGui(root, text, S.ESP_PlayerColor)
                                    playerESPLabels[p] = { gui = gui, lbl = lbl }
                                end
                            else
                                removePlayerESP(p)
                            end
                        end
                    end
                    for p, _ in pairs(playerESPLabels) do
                        if not p.Character or not p.Parent then removePlayerESP(p) end
                    end
                    task.wait(0.5)
                end
                for p, _ in pairs(playerESPLabels) do removePlayerESP(p) end
                playerESPLabels = {}
            end)

            connections["playerESP"] = Players.PlayerRemoving:Connect(removePlayerESP)
            notify("Player ESP", "Tracking all players.")
        else
            notify("Player ESP", "Disabled.")
        end
    end
})

FruitTab:CreateSection("Chest ESP")

FruitTab:CreateToggle({
    Name         = "Chest ESP",
    CurrentValue = false,
    Flag         = "ChestESP",
    Callback = function(v)
        S.ChestESP = v
        clearESP("chests")
        espObjects["chests"] = {}

        if v then
            task.spawn(function()
                while S.ChestESP do
                    clearESP("chests")
                    local myRoot = getRoot()
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        local name = obj.Name:lower()
                        if name:find("chest") or name:find("treasure") or name:find("box") then
                            local part = obj:IsA("Model")
                                and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart"))
                                or (obj:IsA("BasePart") and obj)
                            if part and part.Parent then
                                local dist = myRoot
                                    and math.floor((myRoot.Position - part.Position).Magnitude)
                                    or 0
                                local label = "[CHEST] " .. obj.Name
                                if S.ESP_ShowDist then label = label .. "\n" .. dist .. " studs" end
                                local gui, _ = makeESPGui(part, label, S.ESP_ChestColor)
                                table.insert(espObjects["chests"], gui)
                            end
                        end
                    end
                    task.wait(5)
                end
                clearESP("chests")
            end)
            notify("Chest ESP", "Showing treasure chests.")
        else
            notify("Chest ESP", "Disabled.")
        end
    end
})

FruitTab:CreateButton({
    Name = "Clear All ESP",
    Callback = function()
        for key in pairs(espObjects) do clearESP(key) end
        for p in pairs(playerESPLabels) do removePlayerESP(p) end
        playerESPLabels = {}
        S.FruitESP  = false
        S.PlayerESP = false
        S.ChestESP  = false
        notify("ESP Cleared", "All ESP labels removed.")
    end
})

-- ══════════════════════════════════════════════════════
--  VISUALS TAB
-- ══════════════════════════════════════════════════════

VisualTab:CreateSection("Environment")

VisualTab:CreateToggle({
    Name         = "Full Bright",
    CurrentValue = false,
    Flag         = "FullBright",
    Callback = function(v)
        S.FullBright = v
        local L = game:GetService("Lighting")
        if v then
            S._oldBright = L.Brightness
            S._oldAmb    = L.Ambient
            S._oldOutAmb = L.OutdoorAmbient
            S._oldFog    = L.FogEnd
            L.Brightness     = 10
            L.Ambient        = Color3.fromRGB(178,178,178)
            L.OutdoorAmbient = Color3.fromRGB(178,178,178)
            L.FogEnd         = 1e9
        else
            L.Brightness     = S._oldBright or 2
            L.Ambient        = S._oldAmb    or Color3.fromRGB(70,70,70)
            L.OutdoorAmbient = S._oldOutAmb or Color3.fromRGB(70,70,70)
            L.FogEnd         = S._oldFog    or 100000
        end
        notify("Full Bright", v and "Enabled." or "Disabled.")
    end
})

VisualTab:CreateSlider({
    Name         = "Time of Day",
    Range        = {0, 24},
    Increment    = 1,
    Suffix       = ":00",
    CurrentValue = 14,
    Flag         = "TimeOfDay",
    Callback = function(v)
        game:GetService("Lighting").TimeOfDay = tostring(v) .. ":00:00"
    end
})

VisualTab:CreateSection("Camera")

VisualTab:CreateSlider({
    Name         = "Field of View",
    Range        = {50, 120},
    Increment    = 1,
    Suffix       = " deg",
    CurrentValue = 70,
    Flag         = "FOV",
    Callback = function(v) camera.FieldOfView = v end
})

VisualTab:CreateSlider({
    Name         = "Camera Zoom (Max)",
    Range        = {5, 500},
    Increment    = 5,
    Suffix       = " studs",
    CurrentValue = 128,
    Flag         = "CamZoom",
    Callback = function(v) player.CameraMaxZoomDistance = v end
})

VisualTab:CreateSection("Character")

VisualTab:CreateButton({
    Name = "Hide Character",
    Callback = function()
        local c = getChar(); if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("Decal") then p.Transparency = 1 end
        end
        notify("Character", "Hidden.")
    end
})

VisualTab:CreateButton({
    Name = "Show Character",
    Callback = function()
        local c = getChar(); if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.Transparency = 0 end
        end
        notify("Character", "Visible.")
    end
})

-- ══════════════════════════════════════════════════════
--  MISC TAB
-- ══════════════════════════════════════════════════════

MiscTab:CreateSection("ESP Customization")

-- Color pickers via dropdown (Rayfield doesn't have colorpicker natively
-- on all versions, so we use a dropdown of named colours)
local colorNames = {
    "Red","Orange","Yellow","Lime","Green","Teal",
    "Cyan","Blue","Purple","Pink","Rose","White","Grey"
}
local colorMap = {
    Red    = Color3.fromRGB(255, 70, 70),
    Orange = Color3.fromRGB(255,165,  0),
    Yellow = Color3.fromRGB(255,225, 50),
    Lime   = Color3.fromRGB(130,255, 60),
    Green  = Color3.fromRGB( 60,200, 90),
    Teal   = Color3.fromRGB( 50,200,180),
    Cyan   = Color3.fromRGB( 80,200,255),
    Blue   = Color3.fromRGB( 60,100,255),
    Purple = Color3.fromRGB(170, 80,255),
    Pink   = Color3.fromRGB(255,120,200),
    Rose   = Color3.fromRGB(255, 80,130),
    White  = Color3.fromRGB(255,255,255),
    Grey   = Color3.fromRGB(160,160,160),
}

MiscTab:CreateDropdown({
    Name          = "Fruit ESP Color",
    Options       = colorNames,
    CurrentOption = {"Red"},
    Flag          = "FruitESPColor",
    Callback = function(opt)
        local c = type(opt) == "table" and opt[1] or opt
        S.ESP_FruitColor = colorMap[c] or Color3.fromRGB(255,80,80)
        notify("ESP Color", "Fruit ESP color set to " .. tostring(c))
    end
})

MiscTab:CreateDropdown({
    Name          = "Player ESP Color",
    Options       = colorNames,
    CurrentOption = {"Cyan"},
    Flag          = "PlayerESPColor",
    Callback = function(opt)
        local c = type(opt) == "table" and opt[1] or opt
        S.ESP_PlayerColor = colorMap[c] or Color3.fromRGB(80,200,255)
        notify("ESP Color", "Player ESP color set to " .. tostring(c))
    end
})

MiscTab:CreateDropdown({
    Name          = "Chest ESP Color",
    Options       = colorNames,
    CurrentOption = {"Yellow"},
    Flag          = "ChestESPColor",
    Callback = function(opt)
        local c = type(opt) == "table" and opt[1] or opt
        S.ESP_ChestColor = colorMap[c] or Color3.fromRGB(255,215,0)
        notify("ESP Color", "Chest ESP color set to " .. tostring(c))
    end
})

MiscTab:CreateSlider({
    Name         = "ESP Text Size",
    Range        = {10, 28},
    Increment    = 1,
    Suffix       = " px",
    CurrentValue = 14,
    Flag         = "ESPTextSize",
    Callback = function(v)
        S.ESP_TextSize = v
        notify("ESP", "Text size set to " .. v .. "px. Restart ESP toggles to apply.")
    end
})

MiscTab:CreateSlider({
    Name         = "ESP Background Opacity",
    Range        = {0, 100},
    Increment    = 5,
    Suffix       = "%",
    CurrentValue = 55,
    Flag         = "ESPBgOpacity",
    Callback = function(v)
        -- Transparency = 1 - (opacity/100)
        S.ESP_BgTransp = 1 - (v / 100)
        notify("ESP", "Background opacity " .. v .. "%. Restart ESP toggles to apply.")
    end
})

MiscTab:CreateToggle({
    Name         = "Show Distance on ESP",
    CurrentValue = true,
    Flag         = "ESPShowDist",
    Callback = function(v)
        S.ESP_ShowDist = v
        notify("ESP", "Distance display " .. (v and "enabled" or "disabled") .. ".")
    end
})

MiscTab:CreateSection("Player Info")

MiscTab:CreateButton({
    Name = "Print Stats to Console",
    Callback = function()
        local h = getHum()
        print("====== EXTREME SOLUTIONS ======")
        print("Player:      ", player.Name)
        print("User ID:     ", player.UserId)
        print("Account Age: ", player.AccountAge, "days")
        if h then
            print("Health:      ", math.floor(h.Health), "/", math.floor(h.MaxHealth))
            print("WalkSpeed:   ", h.WalkSpeed)
            print("JumpPower:   ", h.JumpPower)
        end
        local root = getRoot()
        if root then print("Position:    ", tostring(root.Position)) end
        print("================================")
        notify("Stats", "Check the developer console (F9).")
    end
})

MiscTab:CreateButton({
    Name = "Copy Position to Clipboard",
    Callback = function()
        local root = getRoot()
        if root then
            local pos = root.Position
            local str = string.format("CFrame.new(%d, %d, %d)", pos.X, pos.Y, pos.Z)
            setclipboard(str)
            notify("Copied!", str)
        end
    end
})

MiscTab:CreateSection("Server")

MiscTab:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        TeleportService:Teleport(game.PlaceId, player)
    end
})

MiscTab:CreateButton({
    Name = "Hop to New Server",
    Callback = function()
        local ok, result = pcall(function()
            return game:HttpGet(
                "https://games.roblox.com/v1/games/"
                .. game.PlaceId
                .. "/servers/Public?limit=100"
            )
        end)
        local servers = {}
        if ok then
            local data = HttpService:JSONDecode(result)
            for _, s in ipairs(data.data or {}) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    table.insert(servers, s.id)
                end
            end
        end
        if #servers > 0 then
            TeleportService:TeleportToPlaceInstance(
                game.PlaceId, servers[math.random(1, #servers)], player
            )
            notify("Server Hop", "Jumping to new server...")
        else
            notify("Server Hop", "No available servers found.")
        end
    end
})

MiscTab:CreateSection("Anti-AFK")

MiscTab:CreateToggle({
    Name         = "Anti-AFK",
    CurrentValue = false,
    Flag         = "AntiAFK",
    Callback = function(v)
        S.AntiAFK = v
        disconnectKey("antiAFK")
        if v then
            local VR = game:GetService("VirtualUser")
            connections["antiAFK"] = player.Idled:Connect(function()
                VR:Button2Down(Vector2.new(0,0), camera.CFrame)
                task.wait(0.1)
                VR:Button2Up(Vector2.new(0,0), camera.CFrame)
            end)
            notify("Anti-AFK", "Won't be kicked for being idle.")
        else
            notify("Anti-AFK", "Disabled.")
        end
    end
})

MiscTab:CreateSection("Credits")

MiscTab:CreateParagraph({
    Title   = "Extreme Solutions  ·  Blox Fruits Hub",
    Content = "Developed by Extreme Solutions\nUI powered by Rayfield\n\nToggle Menu: K\n\n── Features ──\n• Player: Speed · Jump · Inf Jump · No Clip · God Mode · Anti-KB\n• Farm: Auto Farm · Boss Farm · Mastery Farm (fly locomotion)\n• Teleport: All 3 seas + Café · Mansion · Mirage Island\n• ESP: Fruit · Player · Chest  (fully customisable)\n• Visuals: Full Bright · Time of Day · FOV · Zoom · Character hide\n• Misc: Server hop · Anti-AFK · Clipboard tools\n\nJoin our Discord for updates and support."
})

-- ══════════════════════════════════════════════════════
--  RESPAWN HANDLER
-- ══════════════════════════════════════════════════════

player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local h = char:WaitForChild("Humanoid", 5)
    if h then
        h.WalkSpeed = S.SpeedValue
        h.JumpPower = S.JumpValue
    end
    if S.GodMode then applyGodMode(char) end
    if S.NoClip then
        disconnectKey("noClip")
        connections["noClip"] = RunService.Stepped:Connect(function()
            local c = getChar(); if not c then return end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end)
    end
    startSpeedEnforce()
    invalidateCache()
end)

if player.Character then
    local h = getHum()
    if h then h.WalkSpeed = S.SpeedValue; h.JumpPower = S.JumpValue end
end

-- ══════════════════════════════════════════════════════
--  LOAD CONFIG
-- ══════════════════════════════════════════════════════

Rayfield:LoadConfiguration()

notify("Extreme Solutions", "Blox Fruits Hub loaded!  Press K to toggle the menu.", 4483362458)