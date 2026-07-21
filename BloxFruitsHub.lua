-- ██████████████████████████████████████████████████████
--           Extreme Solutions | Blox Fruits Hub
--                      By Tzqy
--               ESLib UI — Full BF Edition (v4.1)
-- ██████████████████████████████████████████████████████

-- FIX (#4 lifecycle): the LocalPlayer guard MUST run before ESLib is
-- loaded, because ESLib immediately calls
-- Players.LocalPlayer:WaitForChild("PlayerGui") on init. If we injected
-- before the client player replicated, ESLib would index a nil
-- LocalPlayer and hard-error before our old (later) guard could help.
-- We therefore resolve LocalPlayer FIRST, then load ESLib.
do
    local Players = game:GetService("Players")
    if not Players.LocalPlayer then
        -- Wait until the client player object exists (bounded, non-blocking
        -- forever): either the property fires or we time out after ~10s.
        local ok = false
        task.spawn(function()
            Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
            ok = true
        end)
        local t0 = os.clock()
        while not Players.LocalPlayer and (os.clock() - t0) < 10 do
            task.wait(0.05)
        end
    end
    -- FIX (#5 runtime verification): fail loudly with a clear message if
    -- LocalPlayer still isn't available, rather than letting ESLib throw a
    -- cryptic "attempt to index nil" deeper in the stack.
    assert(Players.LocalPlayer,
        "[ES Hub] LocalPlayer unavailable after 10s — run this on the client, not the server.")
    -- Make sure PlayerGui exists before ESLib tries to mount into it.
    Players.LocalPlayer:WaitForChild("PlayerGui", 10)
end

-- FIX (#5 runtime verification): guard the remote fetch + compile of
-- ESLib so a network/HTTP failure produces a descriptive error instead
-- of a raw loadstring nil-call crash.
local ESLib
do
    local ok, srcOrErr = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/Extreme-Solutions-xyz/ES-HUB/main/ESLib.lua")
    end)
    assert(ok and type(srcOrErr) == "string" and #srcOrErr > 0,
        "[ES Hub] Failed to download ESLib.lua: " .. tostring(srcOrErr))
    local chunk, compileErr = loadstring(srcOrErr)
    assert(chunk, "[ES Hub] Failed to compile ESLib.lua: " .. tostring(compileErr))
    ESLib = chunk()
    assert(type(ESLib) == "table" and ESLib.CreateWindow,
        "[ES Hub] ESLib loaded but is missing CreateWindow — check the library version.")
end

-- ══════════════════════════════════════════════════════
--  WINDOW
-- ══════════════════════════════════════════════════════

local Window = ESLib:CreateWindow({
    Name            = "Extreme Solutions | Blox Fruits",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled     = true,
        SaveToggles = false,
        FolderName  = "ExtremeSolutions",
        FileName    = "BloxFruitsHub",
        SessionOnlyFlags = {
            "SpeedSlider",
            "JumpSlider",
            "TimeOfDay",
            "FOV",
            "CamZoom",
        },
    },
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

-- FIX (#4 lifecycle): LocalPlayer is already guaranteed by the guard at
-- the very top of the file (which runs BEFORE ESLib loads). We keep a
-- final assertion here as a cheap runtime sanity check (#5).
local player = Players.LocalPlayer
assert(player, "[ES Hub] LocalPlayer missing at services stage (should be impossible).")

-- FIX (#4 lifecycle): CurrentCamera can be nil for a frame on join.
-- Resolve it safely and keep a helper so any later consumer always
-- gets a live camera rather than a stale/nil reference.
local function getCamera()
    return Workspace.CurrentCamera
end
local camera = getCamera()
if not camera then
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
    camera = getCamera()
end

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
local runtimeId = HttpService:GenerateGUID(false)
S.RuntimeId = runtimeId

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
-- Combat (new v4.1)
S.KillAura         = false
S.KillAuraRange    = 40
S.FastAttack       = false
S.AutoQuest        = false
S.AutoQuestDelay   = 2
-- Fruit (new)
S.FruitSniper      = false
S.FruitSniperRange = 9999
-- Free Fly (new)
S.FreeFly          = false
S.FreeFlySpeed     = 120

-- Fruit
S.FruitESP         = false
S.AutoCollectFruit = false

-- ESP
S.PlayerESP        = false
S.ChestESP         = false

-- ESP Customisation (defaults)
S.ESP_FruitColor   = Color3.fromRGB(98, 210, 60)
S.ESP_PlayerColor  = Color3.fromRGB(80, 200, 255)
S.ESP_ChestColor   = Color3.fromRGB(255, 215, 0)
S.ESP_TextSize     = 14
S.ESP_BgTransp     = 0.45
S.ESP_ShowDist     = true
S.PlayerESPDistance = S.PlayerESPDistance or 2500
S.ChestESPDistance  = S.ChestESPDistance or 3000

-- Misc
S.FullBright       = false
S.AntiAFK          = false

local connections = {}
local espObjects  = {}

-- Re-execution guard: if the script is run again in the same session,
-- tear down the previous run's global signal connections so we don't
-- stack duplicate CharacterAdded / other handlers.
local GLOBAL_KEY = "_ESHub_BloxFruits_Globals"
if getgenv then
    local prev = getgenv()[GLOBAL_KEY]
    if type(prev) == "table" then
        for _, handle in pairs(prev) do
            pcall(function()
                if type(handle) == "function" then
                    handle()
                else
                    handle:Disconnect()
                end
            end)
        end
    end
    getgenv()[GLOBAL_KEY] = {}
end

-- Register a persistent global connection under the re-exec guard.
local function registerGlobal(name, conn)
    if getgenv and type(getgenv()[GLOBAL_KEY]) == "table" then
        getgenv()[GLOBAL_KEY][name] = conn
    end
    return conn
end

-- Remove markers left behind by an older execution before starting this runtime.
for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("BillboardGui") and obj.Name == "ESHubESP" then
        pcall(function() obj:Destroy() end)
    end
end

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

-- One cleanup handle owns every feature connection in this runtime. This
-- catches connections created later as toggles change, without requiring
-- each toggle to maintain a second global registry entry.
registerGlobal("featureConnectionsCleanup", function()
    for _, conn in pairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
end)

-- Background worker loops (task.spawn) are tracked here, NOT in
-- `connections`, because a coroutine has no :Disconnect() method.
-- Each worker also carries a generation token so a stale thread
-- self-terminates the instant a newer one starts or it is cancelled.
local taskThreads = {}
local taskTokens  = {}

local function cancelTask(key)
    -- Bump the token first so any in-flight loop iteration bails out,
    -- then cancel the coroutine itself.
    taskTokens[key] = (taskTokens[key] or 0) + 1
    if taskThreads[key] then
        pcall(task.cancel, taskThreads[key])
        taskThreads[key] = nil
    end
end

local function startTask(key, fn)
    cancelTask(key)
    local token = taskTokens[key]
    taskThreads[key] = task.spawn(function()
        fn(function() return taskTokens[key] == token end)
        -- Clear our own handle if we exit naturally and are still current.
        if taskTokens[key] == token then taskThreads[key] = nil end
    end)
end

registerGlobal("workerTasksCleanup", function()
    local keys = {}
    for key in pairs(taskThreads) do keys[#keys + 1] = key end
    for _, key in ipairs(keys) do cancelTask(key) end
end)

local loadingConfiguration = false

local function notify(title, content, _type)
    if loadingConfiguration then return end
    Window:Notify({
        Title    = title,
        Content  = content,
        Duration = 3,
        Type     = _type or "info",
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
    speedEnforceConn = registerGlobal("speedEnforce", RunService.Heartbeat:Connect(function()
        local h = getHum()
        if not h then return end
        -- Only write when mismatched to avoid unnecessary sets
        if h.WalkSpeed ~= S.SpeedValue then
            h.WalkSpeed = S.SpeedValue
        end
        if h.JumpPower ~= S.JumpValue then
            h.JumpPower = S.JumpValue
        end
    end))
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
--  COMBAT & UTILITY ENGINE
--  New v4.1 helpers: Kill Aura, Fast Attack, Auto Quest,
--  Fruit Sniper, Free Fly.  All reuse existing helpers
--  (getChar/getRoot/getHum, tpTo, isWildFruit, attackEnemy)
--  so the ES feel stays consistent and behaviour is
--  predictable across respawns.

-- ──────────────────────────────────────────────────────────
--  KILL AURA
--  Attacks EVERY living enemy within range on a tight loop.
--  Uses the same attackEnemy() routine as Auto Farm so the
--  damage path is identical; only the targeting is broader.
-- ──────────────────────────────────────────────────────────

local KILL_AURA_INTERVAL = 0.15   -- seconds between attack ticks
local KILL_AURA_MAX_TARGETS = 6   -- cap targets processed per tick

local function startKillAura()
    disconnectKey("killAura")
    local acc = 0
    connections["killAura"] = RunService.Heartbeat:Connect(function(dt)
        if not S.KillAura then return end
        -- Throttle: only do work a few times a second, not every frame.
        acc = acc + dt
        if acc < KILL_AURA_INTERVAL then return end
        acc = 0

        local myRoot = getRoot()
        if not myRoot then return end
        rebuildEnemyCache()

        -- Gather in-range living enemies, nearest first, then process a
        -- bounded batch so a crowded area can't stall the client.
        local inRange = {}
        for _, entry in ipairs(enemyCache) do
            if entry.hum and entry.hum.Health > 0 and entry.root and entry.root.Parent then
                local dist = (myRoot.Position - entry.root.Position).Magnitude
                if dist <= S.KillAuraRange then
                    inRange[#inRange + 1] = { entry = entry, dist = dist }
                end
            end
        end
        table.sort(inRange, function(a, b) return a.dist < b.dist end)

        for i = 1, math.min(#inRange, KILL_AURA_MAX_TARGETS) do
            local e = inRange[i].entry
            pcall(attackEnemy, e.model, e.root)
        end
    end)
end

-- ──────────────────────────────────────────────────────────
--  FAST ATTACK
--  Spams the equipped tool's Activate + combat remote at a
--  higher rate than the normal attack interval so melee
--  combos come out much faster.  Heartbeat-driven, pcall
--  guarded, degrades to a no-op if no tool is equipped.
-- ──────────────────────────────────────────────────────────

-- FIX (#2 Fast Attack): score every RemoteEvent on the tool and return
-- only the best genuine "attack" remote. The previous fallback grabbed
-- the FIRST RemoteEvent it found, which could be an unrelated remote
-- (e.g. an animation-sync, cooldown, or UI event) and fire garbage at
-- the server. We now:
--   * strongly reward attack/combat words,
--   * penalise clearly non-combat words (equip/reload/cooldown/etc.),
--   * cache the result per-tool so we don't re-scan every tick,
--   * and return nil (graceful skip) when nothing looks like an attack.

-- FIX (#3 Fast Attack): tightened keyword list. The generic terms
-- "use"/"click"/"hit" were removed from the strong-positive set because
-- they match far too many unrelated remotes ("UseItem", "ClickGui",
-- "HitboxSync", etc.). We now only strongly reward specific, unambiguous
-- attack identifiers, and require a HIGHER threshold to qualify (see
-- ATTACK_MIN_SCORE below), so an accidental single weak match can't win.
local ATTACK_POS = {
    -- Blox Fruits' real melee remote is literally named "weaponhit" /
    -- "MeleeHit"; these specific phrases are what we target.
    ["weaponhit"]=10, ["meleehit"]=10, ["basicattack"]=10,
    ["attackremote"]=9, ["m1hit"]=9,
    ["attack"]=6, ["combat"]=6, ["melee"]=6, ["swing"]=5, ["slash"]=5,
    ["damage"]=4,
}
local ATTACK_NEG = {
    ["equip"]=-8, ["unequip"]=-8, ["reload"]=-6, ["cooldown"]=-6,
    ["animation"]=-6, ["anim"]=-5, ["ui"]=-6, ["sound"]=-5,
    ["skill"]=-3, ["block"]=-3, ["charge"]=-3, ["reset"]=-4,
    ["sync"]=-5, ["replicate"]=-4, ["vfx"]=-5, ["effect"]=-4,
    ["client"]=-3, ["request"]=-2,
}

-- FIX (#3 Fast Attack): a remote must clear this threshold to be treated
-- as an attack. Set above any single weak keyword so a lone generic
-- match (e.g. only "damage"=4) is NOT enough on its own.
local ATTACK_MIN_SCORE = 5

local function scoreAttackRemote(name)
    local ln = name:lower()
    local score = 0
    for word, w in pairs(ATTACK_POS) do
        if ln:find(word, 1, true) then score = score + w end
    end
    for word, w in pairs(ATTACK_NEG) do
        if ln:find(word, 1, true) then score = score + w end
    end
    return score
end

-- Per-tool cache so scanning only happens once per equipped tool.
local combatRemoteCache = setmetatable({}, { __mode = "k" })

local function findToolCombatRemote(tool)
    local cached = combatRemoteCache[tool]
    if cached and cached.Parent then return cached end

    -- FIX (#3 Fast Attack): start the bar at the minimum qualifying score
    -- (not 0), so a remote must be a CONFIDENT attack match to be chosen.
    local best, bestScore = nil, (ATTACK_MIN_SCORE - 1)
    for _, r in ipairs(tool:GetDescendants()) do
        if r:IsA("RemoteEvent") then
            local s = scoreAttackRemote(r.Name)
            if s > bestScore then
                best, bestScore = r, s
            end
        end
    end

    -- Graceful skip: if nothing cleared ATTACK_MIN_SCORE, there is no
    -- remote we can confidently treat as an attack, so return nil and
    -- fire nothing (prevents spamming unrelated remotes).
    if best then combatRemoteCache[tool] = best end
    return best
end

local FAST_ATTACK_INTERVAL = 0.07   -- ~14 attacks/sec, not every frame

local function startFastAttack()
    disconnectKey("fastAttack")
    local acc = 0
    connections["fastAttack"] = RunService.Heartbeat:Connect(function(dt)
        if not S.FastAttack then return end
        acc = acc + dt
        if acc < FAST_ATTACK_INTERVAL then return end
        acc = 0

        local char = getChar(); if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then
            tool = player.Backpack:FindFirstChildOfClass("Tool")
            if tool then tool.Parent = char; task.wait(0.02) end
        end
        if not tool then return end

        pcall(function() tool:Activate() end)
        -- Fire ONLY the identified combat remote, once per tick.
        local remote = findToolCombatRemote(tool)
        if remote then
            -- FIX (#3 Fast Attack): validate arguments before invoking.
            -- We only fire when we have a real, alive HumanoidRootPart to
            -- pass as the target CFrame. Blox Fruits' weapon-hit remote
            -- expects a CFrame/position argument; firing with a nil/garbage
            -- argument can be rejected server-side or flagged as abnormal.
            local root = getRoot()
            if root and root:IsA("BasePart") and remote:IsA("RemoteEvent") then
                local targetCF = root.CFrame
                if typeof(targetCF) == "CFrame" then
                    pcall(function() remote:FireServer(targetCF) end)
                end
            end
        end
    end)
end

-- ──────────────────────────────────────────────────────────
--  AUTO QUEST
--  Periodically accepts the nearest quest and turns in the
--  current quest so Auto Farm can keep gaining XP without
--  manual interaction.  Defensive: every remote lookup is
--  pcall-wrapped and silently skipped if the game's remote
--  layout changes in a future update.
-- ──────────────────────────────────────────────────────────

-- Blox Fruits routes almost every gameplay request through a single
-- RemoteFunction named "CommF_" (occasionally a RemoteEvent "CommE_").
-- We resolve THAT specific handler rather than firing a shotgun of
-- guessed remotes. Returns the handler + whether it is a function.
local questCommCache = nil

local function getCommRemote()
    if questCommCache and questCommCache.Parent then return questCommCache end
    questCommCache = nil
    local RS = game:GetService("ReplicatedStorage")
    -- Preferred exact names, then a guarded fallback search.
    for _, nm in ipairs({ "CommF_", "CommE_", "CommF", "Comm" }) do
        local obj = RS:FindFirstChild(nm, true)
        if obj and (obj:IsA("RemoteFunction") or obj:IsA("RemoteEvent")) then
            questCommCache = obj
            return obj
        end
    end
    return nil
end

-- Known safe CommF_ commands. StartQuest expects (questGiverName, tier);
-- AbandonQuest takes no useful args and must ONLY fire when we actually
-- hold a quest, otherwise it needlessly spams the server.
local QUEST_COMMANDS = { "StartQuest", "AbandonQuest" }

-- FIX (#1 Auto Quest): read the player's real level so we can pick the
-- correct quest tier instead of guessing 1..3. Blox Fruits exposes the
-- level in a few known spots depending on build; we try each safely.
local function getPlayerLevel()
    -- 1) player.Data.Level.Value  (most common in current builds)
    local data = player:FindFirstChild("Data")
    if data then
        local lvl = data:FindFirstChild("Level")
        if lvl and typeof(lvl.Value) == "number" then return lvl.Value end
    end
    -- 2) leaderstats.Level.Value
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local lvl = ls:FindFirstChild("Level")
        if lvl and typeof(lvl.Value) == "number" then return lvl.Value end
    end
    -- 3) attribute fallback
    local attr = player:GetAttribute("Level")
    if typeof(attr) == "number" then return attr end
    return nil   -- unknown: caller must handle gracefully
end

-- FIX (#1 Auto Quest): map a level to the correct quest-giver + tier.
-- Each entry = { name = <StartQuest giver id>, min, max, tier }.
-- `tier` is the 1-based quest index at that giver appropriate for the
-- level band, so StartQuest is called with a VALID, level-matched tier
-- rather than looping 1..3 blindly. Bands cover the main story islands.
local QUEST_TABLE = {
    { name = "BoneMerchant2",   min = 1,    max = 9,    tier = 1 },
    { name = "ColosseumQuestGiver1", min = 10,   max = 14,   tier = 1 },
    { name = "ColosseumQuestGiver1", min = 15,   max = 29,   tier = 2 },
    { name = "JungleQuestGiver1",    min = 30,   max = 39,   tier = 1 },
    { name = "JungleQuestGiver1",    min = 40,   max = 59,   tier = 2 },
    { name = "PirateQuestGiver1",    min = 60,   max = 89,   tier = 1 },
    { name = "PirateQuestGiver1",    min = 90,   max = 99,   tier = 2 },
    { name = "DesertQuestGiver",     min = 100,  max = 119,  tier = 1 },
    { name = "DesertQuestGiver",     min = 120,  max = 149,  tier = 2 },
    { name = "SnowQuestGiver",       min = 150,  max = 174,  tier = 1 },
    { name = "SnowQuestGiver",       min = 175,  max = 224,  tier = 2 },
    { name = "MarineQuestGiver",     min = 225,  max = 274,  tier = 1 },
    { name = "SkyQuestGiver1",       min = 275,  max = 324,  tier = 1 },
    { name = "SkyQuestGiver1",       min = 325,  max = 449,  tier = 2 },
    { name = "PrisonQuestGiver",     min = 450,  max = 624,  tier = 1 },
    { name = "ColosseumQuestGiver2", min = 625,  max = 699,  tier = 1 },
    { name = "MagmaQuestGiver",      min = 700,  max = 824,  tier = 1 },
    { name = "MagmaQuestGiver",      min = 825,  max = 949,  tier = 2 },
    { name = "FishmanQuestGiver1",   min = 950,  max = 1049, tier = 1 },
    { name = "SkyExp1QuestGiver",    min = 1050, max = 1424, tier = 1 },

    -- FIX (#1 Auto Quest): the entries ABOVE already cover levels 1..1424
    -- (First Sea + early Second Sea givers). The bands BELOW add the
    -- previously-missing coverage: late Second Sea (1425-1499) and the
    -- entire Third Sea (1500-9999). Names are the in-game quest-giver
    -- identifiers; where a giver's exact internal id is uncertain, the
    -- Auto Quest loop safely falls back to the NEAREST quest-giver NPC
    -- (see startAutoQuest), so a mismatched name can never fire a bad
    -- command. Bands are ordered by ascending level and never overlap.
    -- ── Second Sea (final island) ─────────────────────────────────
    { name = "ForgottenQuestGiver",  min = 1425, max = 1499, tier = 1 },
    -- ── Third Sea ─────────────────────────────────────────────────
    { name = "PiratePortQuestGiver", min = 1500, max = 1574, tier = 1 },
    { name = "AmazonQuestGiver1",    min = 1575, max = 1624, tier = 1 },
    { name = "AmazonQuestGiver2",    min = 1625, max = 1699, tier = 1 },
    { name = "MarineTreeQuestGiver", min = 1700, max = 1774, tier = 1 },
    { name = "DeepForestQuestGiver", min = 1775, max = 1824, tier = 1 },
    { name = "DeepForest2QuestGiver", min = 1825, max = 1899, tier = 1 },
    { name = "DeepForest3QuestGiver", min = 1900, max = 1974, tier = 1 },
    { name = "HauntedQuestGiver1",   min = 1975, max = 2024, tier = 1 },
    { name = "HauntedQuestGiver2",   min = 2025, max = 2074, tier = 1 },
    { name = "SeaOfTreatsQuestGiver", min = 2075, max = 2124, tier = 1 },
    { name = "IceCreamQuestGiver",   min = 2125, max = 2174, tier = 1 },
    { name = "CakeQuestGiver1",      min = 2175, max = 2224, tier = 1 },
    { name = "CakeQuestGiver2",      min = 2225, max = 2274, tier = 1 },
    { name = "ChocQuestGiver1",      min = 2275, max = 2324, tier = 1 },
    { name = "ChocQuestGiver2",      min = 2325, max = 2374, tier = 1 },
    { name = "CandyQuestGiver",      min = 2375, max = 2449, tier = 1 },
    { name = "TikiQuestGiver1",      min = 2450, max = 2499, tier = 1 },
    { name = "TikiQuestGiver2",      min = 2500, max = 2549, tier = 1 },
    { name = "TikiQuestGiver3",      min = 2550, max = 2599, tier = 1 },
    { name = "SubmergedQuestGiver1", min = 2600, max = 2649, tier = 1 },
    { name = "SubmergedQuestGiver2", min = 2650, max = 2674, tier = 1 },
    { name = "SubmergedQuestGiver3", min = 2675, max = 9999, tier = 1 },
}

-- Return { name, tier } appropriate for `level`, or nil if unknown.
local function questForLevel(level)
    if not level then return nil end
    for _, q in ipairs(QUEST_TABLE) do
        if level >= q.min and level <= q.max then
            return q
        end
    end
    return nil
end

-- FIX (#1 Auto Quest): detect whether the player is CURRENTLY on a quest
-- so we only StartQuest when idle and only AbandonQuest when we hold one.
-- Blox Fruits mirrors the active quest into the player's Data folder.
local function hasActiveQuest()
    local data = player:FindFirstChild("Data")
    if not data then return false end

    local q = data:FindFirstChild("Quest") or data:FindFirstChild("CurrentQuest")
    if not q then return false end

    -- FIX (#2 crash-safety): `q` might be a Folder (or any non-value
    -- Instance), which has NO `.Value` property. Reading q.Value on such
    -- an instance throws and would kill the Auto Quest worker. We only
    -- touch `.Value` after confirming `q` is a ValueBase-derived object.
    -- (ValueBase is the shared base class of StringValue/BoolValue/
    -- ObjectValue/etc., so this one check covers every value type.)
    local okIsValue, isValue = pcall(function() return q:IsA("ValueBase") end)
    if okIsValue and isValue then
        local v = q.Value
        if typeof(v) == "string"  then return v ~= "" end
        if typeof(v) == "boolean" then return v end
        if typeof(v) == "Instance" then return v ~= nil end  -- ObjectValue
        -- Any other populated value type counts as "on a quest".
        if v ~= nil then return true end
        return false
    end

    -- `q` is a container (e.g. a Folder of quest fields): treat the
    -- presence of any child as "a quest is active".
    return q:GetChildren()[1] ~= nil
end

local function fireComm(remote, ...)
    if not remote then return end
    local args = table.pack(...)
    if remote:IsA("RemoteFunction") then
        pcall(function() remote:InvokeServer(table.unpack(args, 1, args.n)) end)
    elseif remote:IsA("RemoteEvent") then
        pcall(function() remote:FireServer(table.unpack(args, 1, args.n)) end)
    end
end

-- Find the quest-giver NPC nearest the player so we can pass a valid
-- quest name/level to StartQuest, instead of firing blind arguments.
local function nearestQuestGiver(root)
    local questFolder = Workspace:FindFirstChild("_WorldOrigin")
        and Workspace._WorldOrigin:FindFirstChild("Quest")
    local best, bestDist
    if questFolder then
        for _, npc in ipairs(questFolder:GetChildren()) do
            local part = npc:FindFirstChild("HumanoidRootPart")
                or npc:FindFirstChildWhichIsA("BasePart")
            if part then
                local d = (root.Position - part.Position).Magnitude
                if not bestDist or d < bestDist then
                    best, bestDist = npc, d
                end
            end
        end
    end
    return best, bestDist
end

local function startAutoQuest()
    startTask("autoQuest", function(isCurrent)
        while S.AutoQuest and isCurrent() do
            local root   = getRoot()
            local remote = getCommRemote()

            if root and remote then
                -- FIX (#1 Auto Quest): only touch quests when we can act
                -- meaningfully. If we already hold a quest, do NOTHING —
                -- the old code fired StartQuest x3 and AbandonQuest every
                -- cycle, which could abandon an in-progress quest or start
                -- the wrong tier.
                if not hasActiveQuest() then
                    -- Prefer a precise, level-matched quest tier.
                    local level = getPlayerLevel()
                    local q = questForLevel(level)

                    if q then
                        -- Start EXACTLY the level-appropriate quest & tier.
                        fireComm(remote, "StartQuest", q.name, q.tier)
                    else
                        -- Level unknown (build without a readable Data.Level):
                        -- fall back to the nearest quest-giver's FIRST tier
                        -- only. We never sweep tiers 1..3 blindly anymore.
                        local npc = nearestQuestGiver(root)
                        if npc then
                            fireComm(remote, "StartQuest", npc.Name, 1)
                        end
                    end
                end
                -- NOTE: AbandonQuest is intentionally NOT fired here. It is
                -- destructive and is only exposed via the explicit
                -- "Abandon Quest" button so the user stays in control.
            end

            task.wait(math.max(1, S.AutoQuestDelay or 2))
        end
    end)
end

-- ──────────────────────────────────────────────────────────
--  FRUIT SNIPER
--  Instantly teleports to the nearest wild fruit (rare fruits
--  prioritised) and collects it, faster than the slow
--  Auto-Collect loop.  Honours a per-snipe distance limit so
--  you only chase fruits you actually want.
-- ──────────────────────────────────────────────────────────

local RARE_FRUIT_WORDS = {
    "dragon","leopard","kitsune","dough","shadow","mammoth",
    "t-rex","gas","portal","venom","spirit","control",
    "buddha","phoenix","blizzard","rumble","gravity",
}

local function fruitRarityScore(name)
    local low = name:lower()
    for _, w in ipairs(RARE_FRUIT_WORDS) do
        if low:find(w) then return 2 end   -- rare
    end
    if isFruitName(name) then return 1 end  -- common
    return 0
end

local function startFruitSniper()
    startTask("fruitSniper", function(isCurrent)
        while S.FruitSniper and isCurrent() do
            local root = getRoot()
            if root then
                local best, bestScore, bestPart, bestDist
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if isWildFruit(obj) then
                        local part = obj:IsA("Model")
                            and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart"))
                            or obj
                        if part and part.Parent then
                            local dist = (root.Position - part.Position).Magnitude
                            if dist <= S.FruitSniperRange then
                                local score = fruitRarityScore(obj.Name)
                                if not bestScore
                                or score > bestScore
                                or (score == bestScore and dist < bestDist) then
                                    best, bestScore, bestPart, bestDist
                                        = obj, score, part, dist
                                end
                            end
                        end
                    end
                end
                if best and bestPart and bestPart.Parent then
                    tpTo(bestPart.CFrame + Vector3.new(0, 3, 0), 0)
                    task.wait(0.2)
                    local parentObj = best:IsA("Model") and best or best.Parent
                    for _, d in ipairs(parentObj:GetDescendants()) do
                        if d:IsA("ClickDetector") then pcall(fireclickdetector, d) end
                        if d:IsA("ProximityPrompt") then pcall(fireproximityprompt, d) end
                    end
                    local remote = parentObj:FindFirstChildOfClass("RemoteEvent")
                    if remote then pcall(function() remote:FireServer() end) end
                    task.wait(0.3)
                end
            end
            task.wait(0.5)
        end
    end)
end

-- ──────────────────────────────────────────────────────────
--  FREE FLY  (manual WASD + camera fly)
--  Smooth, controller-style free flight bound to a toggle.
--  BodyVelocity + BodyGyro, cleaned up on disable / respawn.
-- ──────────────────────────────────────────────────────────

local function startFreeFly()
    disconnectKey("freeFly")
    local root = getRoot()
    if not root then return end

    -- Remove old body movers we may have left.
    for _, v in ipairs(root:GetChildren()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end
    end

    local bv = Instance.new("BodyVelocity")
    bv.Name = "ESFreeFlyBV"
    bv.MaxForce = Vector3.new(9e4, 9e4, 9e4)
    bv.Velocity = Vector3.zero
    bv.Parent = root

    local bg = Instance.new("BodyGyro")
    bg.Name = "ESFreeFlyBG"
    bg.MaxTorque = Vector3.new(9e4, 9e4, 9e4)
    bg.P = 9e4
    bg.CFrame = root.CFrame
    bg.Parent = root

    local function stopFly()
        for _, v in ipairs(root:GetChildren()) do
            if v.Name == "ESFreeFlyBV" or v.Name == "ESFreeFlyBG" then
                pcall(function() v:Destroy() end)
            end
        end
    end

    connections["freeFly"] = RunService.RenderStepped:Connect(function()
        if not S.FreeFly then
            stopFly()
            disconnectKey("freeFly")
            return
        end
        local r = getRoot()
        if not r then stopFly(); disconnectKey("freeFly"); return end
        if bv.Parent ~= r then
            bv.Parent = r
            bg.Parent = r
        end
        -- Align body to camera look direction.
        -- FIX (#4 lifecycle): re-fetch the camera each frame so a camera
        -- swap (respawn/spectate) never leaves us steering off a dead ref.
        local cam = getCamera()
        if not cam then return end
        bg.CFrame = CFrame.new(r.Position, cam.CFrame.LookVector + r.Position)

        local move = Vector3.zero
        local fwd = cam.CFrame.LookVector
        local right = cam.CFrame.RightVector

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + fwd end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - fwd end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end

        if move.Magnitude > 0 then
            bv.Velocity = move.Unit * S.FreeFlySpeed
        else
            bv.Velocity = Vector3.zero
        end
    end)
end
--  ESP HELPERS
-- ══════════════════════════════════════════════════════

local ESP_THEME = {
    bg       = Color3.fromRGB(8, 12, 8),
    border   = Color3.fromRGB(40, 70, 40),
    text     = Color3.fromRGB(228, 242, 228),
    textDim  = Color3.fromRGB(110, 145, 110),
    track    = Color3.fromRGB(5, 9, 5),
    health   = Color3.fromRGB(98, 210, 60),
    danger   = Color3.fromRGB(220, 75, 70),
}

local function espCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

local function espStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Name = "Border"
    s.Color = color
    s.Thickness = thickness
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function espLabel(parent, props)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Font = props.Font or Enum.Font.Gotham
    lbl.TextSize = props.TextSize or 11
    lbl.TextColor3 = props.TextColor3 or ESP_THEME.text
    lbl.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    lbl.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Text = props.Text or ""
    lbl.Size = props.Size
    lbl.Position = props.Position
    lbl.ZIndex = props.ZIndex or 4
    lbl.Parent = parent
    return lbl
end

local function makeESPBase(adornee, width, height, offsetY, maxDistance, color)
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESHubESP"
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = maxDistance
    bb.Size = UDim2.new(0, width, 0, height)
    bb.StudsOffset = Vector3.new(0, offsetY, 0)
    bb.Adornee = adornee
    bb.Parent = adornee

    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 0, 1, 0)
    shadow.Position = UDim2.new(0, 2, 0, 3)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.68
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 1
    shadow.Parent = bb
    espCorner(shadow, 10)

    local glow = Instance.new("Frame")
    glow.Name = "Glow"
    glow.Size = UDim2.new(1, 4, 1, 4)
    glow.Position = UDim2.new(0, -2, 0, -2)
    glow.BackgroundTransparency = 1
    glow.BorderSizePixel = 0
    glow.ZIndex = 1
    glow.Parent = bb
    espCorner(glow, 11)
    local glowStroke = espStroke(glow, color, 2, 0.7)
    glowStroke.Name = "GlowStroke"

    local frame = Instance.new("Frame")
    frame.Name = "Card"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = ESP_THEME.bg
    frame.BackgroundTransparency = S.ESP_BgTransp
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.ZIndex = 2
    frame.Parent = bb
    espCorner(frame, 9)
    local border = espStroke(frame, ESP_THEME.border, 1, 0.08)

    return bb, frame, glowStroke, border
end

local function makeObjectESPGui(adornee, title, category, distance, color, maxDistance)
    local bb, frame, glow, border = makeESPBase(adornee, 150, 46, 3.2, maxDistance, color)
    local titleLabel = espLabel(frame, {
        Size = UDim2.new(1, -16, 0, 17),
        Position = UDim2.new(0, 8, 0, 6),
        Text = title,
        TextSize = math.clamp(S.ESP_TextSize, 10, 16),
        Font = Enum.Font.GothamBold,
        TextColor3 = ESP_THEME.text,
    })
    titleLabel.Name = "Title"
    local detail = category
    if S.ESP_ShowDist then detail = detail .. "  |  " .. distance .. " studs" end
    local detailLabel = espLabel(frame, {
        Size = UDim2.new(1, -16, 0, 14),
        Position = UDim2.new(0, 8, 0, 25),
        Text = detail,
        TextSize = math.clamp(S.ESP_TextSize - 2, 9, 13),
        Font = Enum.Font.GothamSemibold,
        TextColor3 = color,
    })
    detailLabel.Name = "Detail"
    return bb, {
        gui = bb,
        frame = frame,
        glow = glow,
        border = border,
        title = titleLabel,
        detail = detailLabel,
    }
end

local function makePlayerESPGui(adornee, color, maxDistance)
    local bb, frame, glow, border = makeESPBase(adornee, 176, 58, 3.8, maxDistance, color)
    local titleLabel = espLabel(frame, {
        Size = UDim2.new(1, -16, 0, 17),
        Position = UDim2.new(0, 8, 0, 6),
        TextSize = math.clamp(S.ESP_TextSize, 10, 16),
        Font = Enum.Font.GothamBold,
        TextColor3 = color,
    })
    titleLabel.Name = "Title"
    local detailLabel = espLabel(frame, {
        Size = UDim2.new(1, -16, 0, 14),
        Position = UDim2.new(0, 8, 0, 24),
        TextSize = math.clamp(S.ESP_TextSize - 2, 9, 13),
        Font = Enum.Font.GothamSemibold,
        TextColor3 = ESP_THEME.textDim,
    })
    detailLabel.Name = "Detail"

    local healthTrack = Instance.new("Frame")
    healthTrack.Name = "HealthTrack"
    healthTrack.Size = UDim2.new(1, -16, 0, 4)
    healthTrack.Position = UDim2.new(0, 8, 1, -10)
    healthTrack.BackgroundColor3 = ESP_THEME.track
    healthTrack.BorderSizePixel = 0
    healthTrack.ZIndex = 3
    healthTrack.Parent = frame
    espCorner(healthTrack, 2)

    local healthFill = Instance.new("Frame")
    healthFill.Name = "HealthFill"
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.BackgroundColor3 = ESP_THEME.health
    healthFill.BorderSizePixel = 0
    healthFill.ZIndex = 4
    healthFill.Parent = healthTrack
    espCorner(healthFill, 2)

    return {
        gui = bb,
        frame = frame,
        glow = glow,
        border = border,
        title = titleLabel,
        detail = detailLabel,
        healthFill = healthFill,
    }
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
        notify("God Mode", v and "Invincible." or "Mortal.", v and "success" or "info")
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
--  FREE FLY (v4.1)
PlayerTab:CreateSection("Free Fly")

PlayerTab:CreateToggle({
    Name         = "Free Fly (WASD)",
    CurrentValue = false,
    Flag         = "FreeFly",
    Callback = function(v)
        S.FreeFly = v
        if v then
            startFreeFly()
            notify("Free Fly", "WASD to fly, Space/Shift for up/down.", "success")
        else
            local r = getRoot()
            if r then
                for _, x in ipairs(r:GetChildren()) do
                    if x.Name == "ESFreeFlyBV" or x.Name == "ESFreeFlyBG" then
                        pcall(function() x:Destroy() end)
                    end
                end
            end
            disconnectKey("freeFly")
            notify("Free Fly", "Disabled.")
        end
    end
})

PlayerTab:CreateSlider({
    Name         = "Fly Speed",
    Range        = {20, 500},
    Increment    = 5,
    Suffix       = " studs/s",
    CurrentValue = 120,
    Flag         = "FreeFlySpeed",
    Callback = function(v) S.FreeFlySpeed = v end
})
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
            notify("Auto Farm", "Flying to: " .. tostring(S.FarmTarget), "success")
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
            notify("Mastery Farm", "Enabled. Equip your weapon/fruit.", "success")
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
            notify("Boss Farm", "Hunting: " .. tostring(S.BossTarget), "success")
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
--  COMBAT TAB ADDITIONS (v4.1)
FarmTab:CreateSection("Combat")

FarmTab:CreateToggle({
    Name         = "Kill Aura",
    CurrentValue = false,
    Flag         = "KillAura",
    Callback = function(v)
        S.KillAura = v
        if v then
            startKillAura()
            notify("Kill Aura", "Attacking all enemies within range.", "success")
        else
            disconnectKey("killAura")
            notify("Kill Aura", "Disabled.")
        end
    end
})

FarmTab:CreateSlider({
    Name         = "Kill Aura Range",
    Range        = {10, 200},
    Increment    = 5,
    Suffix       = " studs",
    CurrentValue = 40,
    Flag         = "KillAuraRange",
    Callback = function(v) S.KillAuraRange = v end
})

FarmTab:CreateToggle({
    Name         = "Fast Attack",
    CurrentValue = false,
    Flag         = "FastAttack",
    Callback = function(v)
        S.FastAttack = v
        if v then
            startFastAttack()
            notify("Fast Attack", "Attack speed boosted.", "success")
        else
            disconnectKey("fastAttack")
            notify("Fast Attack", "Disabled.")
        end
    end
})

FarmTab:CreateSection("Auto Quest")

FarmTab:CreateToggle({
    Name         = "Auto Quest",
    CurrentValue = false,
    Flag         = "AutoQuest",
    Callback = function(v)
        S.AutoQuest = v
        if v then
            startAutoQuest()
            notify("Auto Quest", "Accepting & turning in quests automatically.", "success")
        else
            cancelTask("autoQuest")
            notify("Auto Quest", "Disabled.")
        end
    end
})

FarmTab:CreateSlider({
    Name         = "Quest Check Interval",
    Range        = {1, 10},
    Increment    = 1,
    Suffix       = " s",
    CurrentValue = 2,
    Flag         = "AutoQuestDelay",
    Callback = function(v) S.AutoQuestDelay = v end
})

-- FIX (#1 Auto Quest): AbandonQuest is destructive, so expose it as an
-- explicit, user-triggered button instead of firing it automatically
-- every cycle like the old loop did. It only fires when the player
-- actually holds a quest.
FarmTab:CreateButton({
    Name = "Abandon Current Quest",
    Callback = function()
        local remote = getCommRemote()
        if not remote then
            notify("Auto Quest", "Quest remote not found.", "warning")
            return
        end
        if hasActiveQuest() then
            fireComm(remote, "AbandonQuest")
            notify("Auto Quest", "Abandoned current quest.", "success")
        else
            notify("Auto Quest", "No active quest to abandon.")
        end
    end
})
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

local FruitESPToggle = FruitTab:CreateToggle({
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
                                local gui = makeObjectESPGui(
                                    part,
                                    obj.Name:gsub("_", " "),
                                    "WILD FRUIT",
                                    dist,
                                    S.ESP_FruitColor,
                                    100000
                                )
                                table.insert(espObjects["fruits"], gui)
                            end
                        end
                    end
                    task.wait(4)
                end
                clearESP("fruits")
            end)
            notify("Fruit ESP", "Scanning for wild fruits only.", "info")
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
            notify("Auto Collect", "Collecting wild fruits only.", "info")
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

local function updatePlayerESP(entry, p, hum, dist)
    local health = math.max(0, math.floor(hum.Health))
    local maxHealth = math.max(1, math.floor(hum.MaxHealth))
    local ratio = math.clamp(health / maxHealth, 0, 1)
    local displayName = p.DisplayName ~= p.Name
        and (p.DisplayName .. "  @" .. p.Name)
        or p.Name

    entry.title.Text = displayName
    entry.title.TextColor3 = S.ESP_PlayerColor
    entry.glow.Color = S.ESP_PlayerColor
    entry.detail.Text = "HP " .. health .. " / " .. maxHealth
        .. (S.ESP_ShowDist and ("  |  " .. dist .. " studs") or "")
    entry.healthFill.Size = UDim2.new(ratio, 0, 1, 0)
    entry.healthFill.BackgroundColor3 = ESP_THEME.danger:Lerp(ESP_THEME.health, ratio)
    entry.frame.BackgroundTransparency = S.ESP_BgTransp
    entry.gui.MaxDistance = S.PlayerESPDistance
end

local PlayerESPToggle = FruitTab:CreateToggle({
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
                            if root and hum and myRoot then
                                local dist = myRoot
                                    and math.floor((myRoot.Position - root.Position).Magnitude)
                                    or 0

                                if dist <= S.PlayerESPDistance then
                                    local entry = playerESPLabels[p]
                                    if not entry or not entry.gui.Parent then
                                        removePlayerESP(p)
                                        entry = makePlayerESPGui(root, S.ESP_PlayerColor, S.PlayerESPDistance)
                                        playerESPLabels[p] = entry
                                    end
                                    pcall(function()
                                        entry.gui.Adornee = root
                                        updatePlayerESP(entry, p, hum, dist)
                                    end)
                                else
                                    removePlayerESP(p)
                                end
                            else
                                removePlayerESP(p)
                            end
                        end
                    end
                    for p, _ in pairs(playerESPLabels) do
                        if not p.Character or not p.Parent then removePlayerESP(p) end
                    end
                    task.wait(0.25)
                end
                for p, _ in pairs(playerESPLabels) do removePlayerESP(p) end
                playerESPLabels = {}
            end)

            connections["playerESP"] = Players.PlayerRemoving:Connect(removePlayerESP)
            notify("Player ESP", "Tracking players within the selected range.")
        else
            notify("Player ESP", "Disabled.")
        end
    end
})

FruitTab:CreateSlider({
    Name         = "Player ESP Range",
    Range        = {250, 12000},
    Increment    = 250,
    Suffix       = " studs",
    CurrentValue = S.PlayerESPDistance,
    Flag         = "PlayerESPDistance",
    Callback = function(v)
        S.PlayerESPDistance = v
        for _, entry in pairs(playerESPLabels) do
            if entry.gui and entry.gui.Parent then entry.gui.MaxDistance = v end
        end
    end
})

FruitTab:CreateSection("Chest ESP")

local CHEST_TYPES = {
    chest1        = { label = "Silver Chest",   priority = 2 },
    chest2        = { label = "Gold Chest",     priority = 2 },
    chest3        = { label = "Diamond Chest",  priority = 2 },
    silverchest   = { label = "Silver Chest",   priority = 3 },
    goldchest     = { label = "Gold Chest",     priority = 3 },
    diamondchest  = { label = "Diamond Chest",  priority = 3 },
    treasurechest = { label = "Treasure Chest", priority = 3 },
}

local function normaliseChestName(name)
    return name:lower():gsub("[%s_%-]", "")
end

local function getChestInfo(obj)
    if not (obj:IsA("Model") or obj:IsA("BasePart")) then return nil end

    local normalised = normaliseChestName(obj.Name)
    local known = CHEST_TYPES[normalised]
    if known then return known end
    if not normalised:find("chest", 1, true)
    and not normalised:find("treasure", 1, true) then
        return nil
    end

    local label = obj.Name:gsub("_", " "):gsub("(%l)(%u)", "%1 %2")
    return { label = label, priority = 1 }
end

local function resolveChestOwner(obj)
    local owner = obj
    local ancestor = obj.Parent
    while ancestor and ancestor ~= Workspace do
        if (ancestor:IsA("Model") or ancestor:IsA("BasePart"))
        and CHEST_TYPES[normaliseChestName(ancestor.Name)] then
            owner = ancestor
        end
        ancestor = ancestor.Parent
    end
    return owner
end

local function isVisibleChestPart(part)
    return part
        and part:IsA("BasePart")
        and part:IsDescendantOf(Workspace)
        and part.Transparency < 0.95
        and part.LocalTransparencyModifier < 0.95
        and part.Size.Magnitude > 0.1
end

local function resolveChestPart(obj)
    if obj:IsA("BasePart") and isVisibleChestPart(obj) then return obj end
    if obj:IsA("Model") and isVisibleChestPart(obj.PrimaryPart) then
        return obj.PrimaryPart
    end
    for _, descendant in ipairs(obj:GetDescendants()) do
        if isVisibleChestPart(descendant) then return descendant end
    end
    return nil
end

local function scanChests(myRoot)
    local candidates = {}
    local seenOwners = {}

    for _, obj in ipairs(Workspace:GetDescendants()) do
        local info = getChestInfo(obj)
        if info then
            local owner = resolveChestOwner(obj)
            local part = resolveChestPart(owner)
            if part and part.Parent and not seenOwners[owner] then
                seenOwners[owner] = true
                local dist = math.floor((myRoot.Position - part.Position).Magnitude)
                if dist <= S.ChestESPDistance then
                    local ownerInfo = getChestInfo(owner) or info
                    table.insert(candidates, {
                        owner = owner,
                        part = part,
                        label = ownerInfo.label,
                        priority = math.max(info.priority, ownerInfo.priority),
                        distance = dist,
                    })
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.distance < b.distance
    end)

    local unique = {}
    for _, candidate in ipairs(candidates) do
        local duplicate = false
        for _, accepted in ipairs(unique) do
            local sameHierarchy = candidate.owner:IsDescendantOf(accepted.owner)
                or accepted.owner:IsDescendantOf(candidate.owner)
            local samePosition = (candidate.part.Position - accepted.part.Position).Magnitude <= 4
            if sameHierarchy or samePosition then
                duplicate = true
                break
            end
        end
        if not duplicate then table.insert(unique, candidate) end
    end

    return unique
end

local ChestESPToggle = FruitTab:CreateToggle({
    Name         = "Chest ESP",
    CurrentValue = false,
    Flag         = "ChestESP",
    Callback = function(v)
        S.ChestESP = v
        clearESP("chests")
        espObjects["chests"] = {}

        if v then
            task.spawn(function()
                while S.ChestESP and S.RuntimeId == runtimeId do
                    clearESP("chests")
                    local myRoot = getRoot()
                    if myRoot then
                        for _, chest in ipairs(scanChests(myRoot)) do
                            local gui = makeObjectESPGui(
                                chest.part,
                                chest.label,
                                "CHEST",
                                chest.distance,
                                S.ESP_ChestColor,
                                S.ChestESPDistance
                            )
                            local ownerRef = Instance.new("ObjectValue")
                            ownerRef.Name = "ChestOwner"
                            ownerRef.Value = chest.owner
                            ownerRef.Parent = gui
                            table.insert(espObjects["chests"], gui)
                        end
                    end
                    -- Visibility changes are cheap to monitor and should feel immediate.
                    for _ = 1, 20 do
                        if not S.ChestESP or S.RuntimeId ~= runtimeId then break end
                        task.wait(0.25)
                        for _, gui in ipairs(espObjects["chests"] or {}) do
                            if gui and gui.Parent then
                                local ownerRef = gui:FindFirstChild("ChestOwner")
                                local owner = ownerRef and ownerRef.Value
                                local visiblePart = owner and owner.Parent
                                    and resolveChestPart(owner)
                                    or nil
                                gui.Enabled = visiblePart ~= nil
                                if visiblePart then gui.Adornee = visiblePart end
                            end
                        end
                    end
                end
                clearESP("chests")
            end)
            notify("Chest ESP", "Showing chests within the selected range.")
        else
            notify("Chest ESP", "Disabled.")
        end
    end
})

FruitTab:CreateSlider({
    Name         = "Chest ESP Range",
    Range        = {250, 12000},
    Increment    = 250,
    Suffix       = " studs",
    CurrentValue = S.ChestESPDistance,
    Flag         = "ChestESPDistance",
    Callback = function(v)
        S.ChestESPDistance = v
        for _, gui in ipairs(espObjects["chests"] or {}) do
            if gui and gui.Parent then gui.MaxDistance = v end
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
        FruitESPToggle:Set(false)
        PlayerESPToggle:Set(false)
        ChestESPToggle:Set(false)
        notify("ESP Cleared", "All ESP labels removed.")
    end
})

-- ══════════════════════════════════════════════════════
FruitTab:CreateToggle({
    Name         = "Fruit Sniper",
    CurrentValue = false,
    Flag         = "FruitSniper",
    Callback = function(v)
        S.FruitSniper = v
        if v then
            startFruitSniper()
            notify("Fruit Sniper", "Sniping nearest wild fruit (rare first).", "success")
        else
            cancelTask("fruitSniper")
            notify("Fruit Sniper", "Disabled.")
        end
    end
})

FruitTab:CreateSlider({
    Name         = "Sniper Range",
    Range        = {500, 30000},
    Increment    = 500,
    Suffix       = " studs",
    CurrentValue = 9999,
    Flag         = "FruitSniperRange",
    Callback = function(v) S.FruitSniperRange = v end
})
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
    Callback = function(v)
        -- FIX (#4 lifecycle): apply to the current camera, not a stale local.
        local cam = getCamera()
        if cam then cam.FieldOfView = v end
    end
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

-- Color pickers via dropdown of named colours
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
        for _, gui in ipairs(espObjects["fruits"] or {}) do
            local card = gui and gui:FindFirstChild("Card")
            local glow = gui and gui:FindFirstChild("Glow")
            if card then
                local detail = card:FindFirstChild("Detail")
                if detail then detail.TextColor3 = S.ESP_FruitColor end
            end
            local glowStroke = glow and glow:FindFirstChild("GlowStroke")
            if glowStroke then glowStroke.Color = S.ESP_FruitColor end
        end
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
        for _, entry in pairs(playerESPLabels) do
            entry.title.TextColor3 = S.ESP_PlayerColor
            entry.glow.Color = S.ESP_PlayerColor
        end
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
        for _, gui in ipairs(espObjects["chests"] or {}) do
            local card = gui and gui:FindFirstChild("Card")
            local glow = gui and gui:FindFirstChild("Glow")
            if card then
                local detail = card:FindFirstChild("Detail")
                if detail then detail.TextColor3 = S.ESP_ChestColor end
            end
            local glowStroke = glow and glow:FindFirstChild("GlowStroke")
            if glowStroke then glowStroke.Color = S.ESP_ChestColor end
        end
        notify("ESP Color", "Chest ESP color set to " .. tostring(c))
    end
})

MiscTab:CreateSlider({
    Name         = "ESP Text Size",
    Range        = {10, 16},
    Increment    = 1,
    Suffix       = " px",
    CurrentValue = 14,
    Flag         = "ESPTextSize",
    Callback = function(v)
        S.ESP_TextSize = v
        local titleSize = math.clamp(v, 10, 16)
        local detailSize = math.clamp(v - 2, 9, 13)
        for _, list in pairs(espObjects) do
            for _, gui in ipairs(list) do
                local card = gui and gui:FindFirstChild("Card")
                if card then
                    local title = card:FindFirstChild("Title")
                    local detail = card:FindFirstChild("Detail")
                    if title then title.TextSize = titleSize end
                    if detail then detail.TextSize = detailSize end
                end
            end
        end
        for _, entry in pairs(playerESPLabels) do
            entry.title.TextSize = titleSize
            entry.detail.TextSize = detailSize
        end
    end,
    FinishedCallback = function(v)
        notify("ESP", "Text size updated to " .. v .. "px.")
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
        for _, list in pairs(espObjects) do
            for _, gui in ipairs(list) do
                local card = gui and gui:FindFirstChild("Card")
                if card then card.BackgroundTransparency = S.ESP_BgTransp end
            end
        end
        for _, entry in pairs(playerESPLabels) do
            entry.frame.BackgroundTransparency = S.ESP_BgTransp
        end
    end,
    FinishedCallback = function(v)
        notify("ESP", "Background opacity updated to " .. v .. "%.")
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
                -- FIX (#4 lifecycle): fetch a live camera CFrame each idle.
                local cam = getCamera()
                local cf = cam and cam.CFrame or CFrame.new()
                VR:Button2Down(Vector2.new(0,0), cf)
                task.wait(0.1)
                VR:Button2Up(Vector2.new(0,0), cf)
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
    Content = "Developed by Extreme Solutions\nUI powered by ESLib (custom)\n\nToggle Menu: K\n\n── Features ──\n• Player: Speed · Jump · Inf Jump · No Clip · God Mode · Anti-KB · Free Fly\n• Farm: Auto Farm · Boss Farm · Mastery Farm · Kill Aura · Fast Attack · Auto Quest\n• Teleport: All 3 seas + Café · Mansion · Mirage Island\n• Fruit: Fruit ESP · Auto Collect · Fruit Sniper\n• Visuals: Full Bright · Time of Day · FOV · Zoom · Character hide\n• Misc: Server hop · Anti-AFK · Clipboard tools\n\nJoin our Discord for updates and support."
})

-- ══════════════════════════════════════════════════════
--  RESPAWN HANDLER
-- ══════════════════════════════════════════════════════

registerGlobal("characterAdded", player.CharacterAdded:Connect(function(char)
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
    -- Re-start persistent combat/utility loops on respawn.
    if S.KillAura then startKillAura() end
    if S.FastAttack then startFastAttack() end
    if S.AutoQuest then startAutoQuest() end
    if S.FruitSniper then startFruitSniper() end
    if S.FreeFly then startFreeFly() end
    invalidateCache()
end))

if player.Character then
    local h = getHum()
    if h then h.WalkSpeed = S.SpeedValue; h.JumpPower = S.JumpValue end
end

-- ══════════════════════════════════════════════════════
--  LOAD CONFIG
-- ══════════════════════════════════════════════════════

loadingConfiguration = true
Window:LoadConfiguration()
loadingConfiguration = false

notify("Extreme Solutions", "Blox Fruits Hub loaded!  Press K to toggle the menu.", "success")
