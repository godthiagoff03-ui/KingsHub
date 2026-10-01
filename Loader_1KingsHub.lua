if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait(1.2)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

task.wait(0.3)

local ScriptVersion = "5"
local ScriptName = "Kings Hub"
local LastUpdated = "01-10-2026"

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library, ThemeManager, SaveManager

local function safeHttpGet(url)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(result) == "string" and #result > 100 then
        return result
    end
    return nil
end

local function safeLoad(url)
    local src = safeHttpGet(url)
    if not src then return nil end
    local ok, res = pcall(function()
        return loadstring(src)()
    end)
    if ok then return res end
    return nil
end

Library = safeLoad(repo .. "Library.lua")
task.wait(0.25)
if Library then
    ThemeManager = safeLoad(repo .. "addons/ThemeManager.lua")
    task.wait(0.15)
    SaveManager = safeLoad(repo .. "addons/SaveManager.lua")
end

if not Library then
    warn("[Kings Hub] Failed to load UI library on Delta Mobile")
    return
end

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true
Library.ShowCustomCursor = false
pcall(function() Library:SetNotifySide("Left") end)

local function notify(message, lifetime)
    pcall(function()
        Library:Notify({
            Title = ScriptName,
            Description = tostring(message),
            Time = lifetime or 10,
        })
    end)
end

-- Delayed light hooks (safer on mobile)
task.defer(function()
    task.wait(0.8)
    pcall(function()
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", function(self, key)
            if self == workspace and key == "GetServerTimeNow" then
                return DateTime.now().UnixTimestamp
            end
            return oldIndex(self, key)
        end)
    end)
end)

local function pressKey(keyCode)
    local VIM = game:GetService("VirtualInputManager")
    VIM:SendKeyEvent(true, keyCode, false, game)
    wait(0.05)
    VIM:SendKeyEvent(false, keyCode, false, game)
end

local HitboxEnabled = false
local HitboxSize = 10
local HitboxColor = Color3.fromRGB(0, 255, 0)
local HitboxTransparency = 0.8

local JumpESPEnabled = false
local JumpESPColor = Color3.fromRGB(255, 0, 0)

local PredictAimEnabled = false
local PredictAimColor = Color3.fromRGB(255, 255, 0)
local PredictAimLength = 0

local AutoStrongServeEnabled = false
local AutoStrongServeEveryServeEnabled = false
local ServeBoostPower = 1
local AutoSpikeEnabled = false
local AutoFarmEnabled = false
local autoClicking = false
local AutoSetEnabled = false
local AutoJumpSetEnabled = false
local AutoReceiveEnabled = false
local StreamerModeEnabled = false
local DirectionalHitEnabled = false
local CameraJumpEnabled = false
local AimbotCornerEnabled = false
local AimbotCornerMode = "Auto"
local MaxPowerSpikeEnabled = false
local JumpBoostEnabled = false
local JumpBoostMult = 1.35
local SpikeBoostEnabled = false
local SpikeBoostCharge = 1
local SilentSpikeEnabled = false
local AnimDesyncEnabled = false
local PerfectSpikeAssistEnabled = true
local OfficialPathEnabled = true
local AutoAbilityEnabled = false
local lastSilentSpike = 0
local lastAutoAbility = 0
local ballJumpRemote = nil
local ballInteractRemote = nil
local abilityUseRemote = nil
local registerMovedRemote = nil
local animDesyncConn = nil
local lastAutoSpikeClick = 0
local lastAutoJumpSetPress = 0
local lastAutoReceivePress = 0
local jumpSetPhase = 0
local jumpSetPhaseTime = 0
local streamerOriginalDisplay = {}

-- Auto Spin System
local AutoSpinEnabled = false
local AutoSpinType = "Style"
local AutoSpinSlot = 1
local AutoSpinTargetName = ""
local AutoSpinStopOnTarget = true
local AutoSpinStopOnRarity = ""
local AutoSpinUseLucky = true
local AutoSpinSpeed = 0.35
local AutoSpinBusy = false
local lastAutoSpin = 0
local styleRollRemote, abilityRollRemote = nil, nil
local styleSelectSlot, abilitySelectSlot = nil, nil

local autoFarmDiedConn = nil
local autoFarmRejoining = false
local lastAutoFarmRejoin = 0

local function resetAutoFarmCycle()
    autoClicking = false
    lockedTeamPosition = nil
    lockedTeamCFrame = nil
    yPositionHistory = {}
end

local function attachAutoFarmDeathListener(character)
    if autoFarmDiedConn then
        autoFarmDiedConn:Disconnect()
        autoFarmDiedConn = nil
    end
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    autoFarmDiedConn = humanoid.Died:Connect(function()
        if not AutoFarmEnabled then return end
        if autoFarmRejoining then return end
        if tick() - lastAutoFarmRejoin < 5 then return end
        lastAutoFarmRejoin = tick()
        autoFarmRejoining = true
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end)
end

if LocalPlayer.Character then
    attachAutoFarmDeathListener(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(character)
    attachAutoFarmDeathListener(character)
end)

local SpeedEnabled = false
local SpeedValue = 0

local function speedControl()
    while SpeedEnabled do
        RunService.RenderStepped:Wait()
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local moveDirection = character.Humanoid.MoveDirection
            if moveDirection.Magnitude > 0 then
                character.HumanoidRootPart.CFrame = character.HumanoidRootPart.CFrame + moveDirection * SpeedValue / 10
            end
        end
    end
end

-- ═══════════════════════════════════════
-- IMPROVED AIMBOT CORNER (COURT-MAPPED)
-- ═══════════════════════════════════════
local courtBounds = nil

local function detectCourtBounds()
    if courtBounds then return courtBounds end
    local minX, maxX = math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge
    local netZ = nil

    pcall(function()
        local map = workspace:FindFirstChild("Map")
        if not map then
            local lobby = workspace:FindFirstChild("Volleyball Lobby")
            map = lobby and lobby:FindFirstChild("Map")
        end
        if not map then return end
        for _, part in pairs(map:GetDescendants()) do
            if part:IsA("BasePart") then
                local name = string.lower(part.Name or "")
                if name:find("court") or name:find("floor") or name:find("outer") then
                    local pos = part.Position
                    local size = part.Size
                    minX = math.min(minX, pos.X - size.X / 2)
                    maxX = math.max(maxX, pos.X + size.X / 2)
                    minZ = math.min(minZ, pos.Z - size.Z / 2)
                    maxZ = math.max(maxZ, pos.Z + size.Z / 2)
                end
                if name == "net" or name:find("volleyballnet") or name:find("net") then
                    if part.Size.X < 2 and part.Size.Z > 10 then
                        netZ = part.Position.Z
                    end
                end
            end
        end
    end)

    if maxX - minX < 5 or maxZ - minZ < 5 then
        minX, maxX = -25, 25
        minZ, maxZ = -40, 40
        for _, plr in pairs(Players:GetPlayers()) do
            local c = plr.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local p = hrp.Position
                minX = math.min(minX, p.X - 25)
                maxX = math.max(maxX, p.X + 25)
                minZ = math.min(minZ, p.Z - 35)
                maxZ = math.max(maxZ, p.Z + 35)
            end
        end
    end

    courtBounds = {
        minX = minX, maxX = maxX,
        minZ = minZ, maxZ = maxZ,
        netZ = netZ,
        centerX = (minX + maxX) / 2,
        centerZ = netZ or (minZ + maxZ) / 2,
        halfWidth = (maxX - minX) / 2,
        courtLength = math.abs(maxZ - minZ),
    }
    return courtBounds
end

task.spawn(function()
    while true do
        task.wait(30)
        courtBounds = nil
    end
end)

local function getRankedCorners(playerPos)
    local court = detectCourtBounds()
    if not court then
        return Vector3.new(playerPos.X - 18, playerPos.Y, playerPos.Z + 36),
               Vector3.new(playerPos.X + 18, playerPos.Y, playerPos.Z + 36),
               playerPos.X
    end

    local myZ = playerPos.Z
    local netZ = court.netZ or court.centerZ
    local facingPositiveZ = myZ < netZ
    local oppZ
    if facingPositiveZ then
        oppZ = court.maxZ - 3
    else
        oppZ = court.minZ + 3
    end

    local courtLeft = court.minX + 2
    local courtRight = court.maxX - 2

    local leftCorner = Vector3.new(courtLeft, playerPos.Y, oppZ)
    local rightCorner = Vector3.new(courtRight, playerPos.Y, oppZ)

    local toOppZ = oppZ - myZ
    if toOppZ < 0 then
        leftCorner = Vector3.new(courtRight, playerPos.Y, oppZ)
        rightCorner = Vector3.new(courtLeft, playerPos.Y, oppZ)
    end

    return leftCorner, rightCorner, court.centerX
end

local function getAimbotTargetCorner(playerPos)
    local leftCorner, rightCorner, centerX = getRankedCorners(playerPos)

    if AimbotCornerMode == "Left" then
        return leftCorner
    elseif AimbotCornerMode == "Right" then
        return rightCorner
    end

    local nearestEnemy, nearestDist = nil, math.huge
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (plr.Character.HumanoidRootPart.Position - playerPos).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearestEnemy = plr
            end
        end
    end

    if nearestEnemy and nearestEnemy.Character and nearestEnemy.Character:FindFirstChild("HumanoidRootPart") then
        local enemyPos = nearestEnemy.Character.HumanoidRootPart.Position
        local distLeft = (leftCorner - enemyPos).Magnitude
        local distRight = (rightCorner - enemyPos).Magnitude
        local ballBonus = 0
        for _, v in pairs(workspace:GetChildren()) do
            if v.Name:find("CLIENT_BALL") and v:IsA("Model") then
                local ball = v:FindFirstChildWhichIsA("BasePart")
                if ball then
                    if (ball.Position - leftCorner).Magnitude < (ball.Position - rightCorner).Magnitude then
                        ballBonus = -2
                    else
                        ballBonus = 2
                    end
                end
                break
            end
        end
        distLeft = distLeft + ballBonus
        distRight = distRight - ballBonus
        return (distLeft > distRight) and leftCorner or rightCorner
    end

    return (playerPos.X < centerX) and rightCorner or leftCorner
end

UserInputService.JumpRequest:Connect(function()
    local character = LocalPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    if AimbotCornerEnabled then
        local playerPos = rootPart.Position
        local targetCorner = getAimbotTargetCorner(playerPos)
        local flatDir = Vector3.new(targetCorner.X - playerPos.X, 0, targetCorner.Z - playerPos.Z)
        if flatDir.Magnitude > 0.5 then
            local currentLook = rootPart.CFrame.LookVector
            local currentFlat = Vector3.new(currentLook.X, 0, currentLook.Z)
            if currentFlat.Magnitude > 0.1 then
                currentFlat = currentFlat.Unit
            else
                currentFlat = flatDir.Unit
            end
            local blended = (currentFlat * 0.15 + flatDir.Unit * 0.85).Unit
            rootPart.CFrame = CFrame.lookAt(playerPos, playerPos + blended)
        end
        return
    end

    if not CameraJumpEnabled then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local look = cam.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude > 0 then
        rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flat.Unit)
    end
end)

spawn(function()
    while true do
        if SpeedEnabled then
            speedControl()
        else
            wait(0.1)
        end
    end
end)

local maxPowerPhase = 0
RunService.Heartbeat:Connect(function()
    if not MaxPowerSpikeEnabled then return end
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end
    local state = humanoid:GetState()
    if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then return end
    if humanoid.MoveDirection.Magnitude > 0.05 then return end
    maxPowerPhase = maxPowerPhase + 0.22
    local dir = Vector3.new(math.sin(maxPowerPhase), 0, math.cos(maxPowerPhase))
    humanoid:Move(dir, true)
end)

local yPositionHistory = {}
local lastYCheck = 0

local function isInGameStable()
    local currentTime = tick()
    if currentTime - lastYCheck < 0.5 then
        return #yPositionHistory >= 20
    end
    lastYCheck = currentTime
    local character = LocalPlayer.Character
    if not character then yPositionHistory = {} return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then yPositionHistory = {} return false end
    local yPosition = rootPart.Position.Y
    table.insert(yPositionHistory, yPosition)
    if #yPositionHistory > 20 then
        table.remove(yPositionHistory, 1)
    end
    if #yPositionHistory >= 20 then
        local allDifferentFromLobby = true
        for _, y in pairs(yPositionHistory) do
            if math.abs(y - (-1.813598871231079)) < 0.1 then
                allDifferentFromLobby = false
                break
            end
        end
        return allDifferentFromLobby
    end
    return false
end

local lastAutoSetPress = 0
local function autoSet()
    local character = LocalPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local state = humanoid:GetState()
    if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then return end
    for _, v in pairs(workspace:GetChildren()) do
        if v.Name:find("CLIENT_BALL") and v:IsA("Model") then
            local ball = v:FindFirstChildWhichIsA("BasePart")
            if ball then
                local extendedHitbox = v:FindFirstChild("ExtendedHitbox")
                if extendedHitbox and extendedHitbox.Color == Color3.fromRGB(0, 255, 0) then
                    local distance = (rootPart.Position - extendedHitbox.Position).Magnitude
                    local playerRadius = 2
                    local hitboxRadius = extendedHitbox.Size.X / 2
                    local isTouching = distance <= (playerRadius + hitboxRadius)
                    if isTouching then
                        if tick() - lastAutoSetPress < 0.35 then break end
                        lastAutoSetPress = tick()
                        local VIM = game:GetService("VirtualInputManager")
                        VIM:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                        wait(0.05)
                        VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
                        break
                    end
                end
            end
        end
    end
end

spawn(function()
    while true do
        if AutoSetEnabled then pcall(function() autoSet() end) end
        wait(0.1)
    end
end)

local lockedTeamPosition = nil
local lockedTeamCFrame = nil
local serveRemoteFired = false
local serveRemote

local function detectAndLockTeam()
    if not AutoFarmEnabled or lockedTeamPosition then return end
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local rootPart = character.HumanoidRootPart
        local currentPos = rootPart.Position
        local currentCFrame = rootPart.CFrame
        local currentZ = currentPos.Z
        if math.abs(currentZ - (-11.018206596374512)) < 0.5 then
            wait(5)
            if character and character:FindFirstChild("HumanoidRootPart") then
                local newPos = character.HumanoidRootPart.Position
                local newZ = newPos.Z
                if math.abs(newZ - (-11.018206596374512)) < 0.5 then
                    lockedTeamPosition = newPos
                    lockedTeamCFrame = character.HumanoidRootPart.CFrame
                end
            end
        elseif math.abs(currentZ - 12.981904029846191) < 0.5 then
            wait(5)
            if character and character:FindFirstChild("HumanoidRootPart") then
                local newPos = character.HumanoidRootPart.Position
                local newZ = newPos.Z
                if math.abs(newZ - 12.981904029846191) < 0.5 then
                    lockedTeamPosition = newPos
                    lockedTeamCFrame = character.HumanoidRootPart.CFrame
                end
            end
        end
    end
end

local function resetToTeamPosition()
    if not lockedTeamPosition or not lockedTeamCFrame then return end
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = lockedTeamCFrame
    end
end

spawn(function()
    while true do
        if AutoFarmEnabled and not lockedTeamPosition then
            detectAndLockTeam()
        end
        wait(0.5)
    end
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local success, knitServices = pcall(function()
    return ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services")
end)

if success and knitServices then
    local gameService = knitServices:WaitForChild("GameService", 10)
    if gameService then
        local rf = gameService:WaitForChild("RF", 5)
        if rf then
            serveRemote = rf:WaitForChild("Serve", 5)
        end
    end
else
    local success2, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("GameService"):WaitForChild("RF"):WaitForChild("Serve")
    end)
    if success2 and remote then
        serveRemote = remote
    end
end

pcall(function()
    local services = knitServices
    if not services then
        services = game:GetService("ReplicatedStorage")
            :WaitForChild("Packages"):WaitForChild("_Index")
            :WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit")
            :WaitForChild("Services")
    end
    local bs = services:FindFirstChild("BallService")
    local rf = bs and bs:FindFirstChild("RF")
    if rf then
        ballJumpRemote = rf:FindFirstChild("Jump")
        ballInteractRemote = rf:FindFirstChild("Interact")
    end
    local abs = services:FindFirstChild("AbilityService")
    local arf = abs and abs:FindFirstChild("RF")
    if arf then
        abilityUseRemote = arf:FindFirstChild("UseAbility")
    end
    local gs = services:FindFirstChild("GameService")
    local grf = gs and gs:FindFirstChild("RF")
    if grf then
        registerMovedRemote = grf:FindFirstChild("RegisterMoved")
    end
end)

-- ═══════════════════════════════════════
-- ACTION BYPASS SYSTEM
-- ═══════════════════════════════════════
local actionBypassModule = nil
local cachedBypassParams = nil

local function loadActionBypass()
    if actionBypassModule then return actionBypassModule end
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local ab = rs:FindFirstChild("Content")
        if ab then
            ab = ab:FindFirstChild("ActionBypass")
            if ab and ab:IsA("ModuleScript") then
                actionBypassModule = require(ab)
            end
        end
    end)
    return actionBypassModule
end

local function computeBypass(actionType, context)
    local mod = loadActionBypass()
    if not mod then return nil end
    local ok, params = pcall(function()
        if mod.computeBypassParams then
            return mod.computeBypassParams(actionType, context)
        end
        return nil
    end)
    if ok and params then
        cachedBypassParams = params
        return params
    end
    pcall(function()
        if mod._buildClientParams then
            local built = mod._buildClientParams(actionType, context)
            if built then
                cachedBypassParams = built
                return built
            end
        end
    end)
    return cachedBypassParams
end

local function getBallIdFromModel(model)
    if not model then return nil end
    local id = tonumber(tostring(model.Name):match("(%d+)"))
    if id then return id end
    local attr = model:GetAttribute("BallId") or model:GetAttribute("Id")
    return tonumber(attr)
end

local function computeBallDepthFactor(playerPos, ballPos, hitbox)
    local radius = 3
    if hitbox and hitbox:IsA("BasePart") then
        radius = math.max(hitbox.Size.X, hitbox.Size.Y, hitbox.Size.Z) * 0.5
    elseif HitboxEnabled and HitboxSize and HitboxSize > 0 then
        radius = math.max(HitboxSize * 0.5, 2)
    end
    local dist = (playerPos - ballPos).Magnitude
    if dist >= radius then return 0 end
    local depth = 1 - (dist / math.max(radius, 0.01))
    return math.clamp(depth, 0, 1)
end

local function getAimLookAndTilt(rootPart)
    local look = rootPart.CFrame.LookVector
    local cam = workspace.CurrentCamera
    if DirectionalHitEnabled and cam then
        look = cam.CFrame.LookVector
    end
    if AimbotCornerEnabled then
        local target = getAimbotTargetCorner(rootPart.Position)
        local flat = Vector3.new(target.X - rootPart.Position.X, 0, target.Z - rootPart.Position.Z)
        if flat.Magnitude > 0.2 then
            look = flat.Unit
        end
    end
    local flatLook = Vector3.new(look.X, 0, look.Z)
    if flatLook.Magnitude < 0.05 then
        flatLook = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
    end
    if flatLook.Magnitude > 0.05 then
        flatLook = flatLook.Unit
    else
        flatLook = Vector3.new(0, 0, -1)
    end
    return look.Unit, flatLook
end

local function buildInteractPayload(action, rootPart, ballModel, ballPart, hitbox)
    local look, tilt = getAimLookAndTilt(rootPart)
    local charge = 1
    if action == "Spike" or action == "spike" then
        if SpikeBoostEnabled then
            charge = math.clamp(tonumber(SpikeBoostCharge) or 1, 0, 1)
        end
        if PerfectSpikeAssistEnabled and ballPart then
            local depth = computeBallDepthFactor(rootPart.Position, (hitbox or ballPart).Position, hitbox)
            if depth >= 0.35 then
                charge = 1
            elseif depth > 0 then
                charge = math.max(charge, 0.7 + depth * 0.3)
            end
        end
    end
    local payload = {
        Action = action,
        Charge = charge,
        LookVector = look,
        TiltDirection = tilt,
        MoveDirection = tilt,
        From = "Client",
        SpecialCharge = 0.000001,
    }
    local id = getBallIdFromModel(ballModel)
    if id then
        payload.BallId = id
    end
    if cachedBypassParams then
        for k, v in pairs(cachedBypassParams) do
            if payload[k] == nil then
                payload[k] = v
            end
        end
    end
    task.spawn(function()
        computeBypass(action, {
            Player = LocalPlayer,
            Action = action,
            BallId = id,
        })
    end)
    return payload
end

local function fireOfficialMove(action, rootPart, ballModel, ballPart, hitbox)
    if not OfficialPathEnabled or not ballInteractRemote then
        return false
    end
    local ok = pcall(function()
        local payload = buildInteractPayload(action, rootPart, ballModel, ballPart, hitbox)
        if ballInteractRemote:IsA("RemoteFunction") then
            ballInteractRemote:InvokeServer(payload)
        else
            ballInteractRemote:FireServer(payload)
        end
    end)
    return ok
end

local function fireOfficialJump()
    pcall(function()
        if ballJumpRemote then
            if ballJumpRemote:IsA("RemoteFunction") then
                ballJumpRemote:InvokeServer()
            else
                ballJumpRemote:FireServer()
            end
        end
        if registerMovedRemote then
            pcall(function()
                if registerMovedRemote:IsA("RemoteFunction") then
                    registerMovedRemote:InvokeServer("Jump")
                else
                    registerMovedRemote:FireServer("Jump")
                end
            end)
        end
    end)
end

local function tryAutoAbility()
    if not AutoAbilityEnabled then return end
    if tick() - lastAutoAbility < 1.5 then return end
    if not abilityUseRemote then return end
    lastAutoAbility = tick()
    pcall(function()
        if abilityUseRemote:IsA("RemoteFunction") then
            abilityUseRemote:InvokeServer()
        else
            abilityUseRemote:FireServer()
        end
    end)
end

local BlockedRemotes = {
    ["RequestBan"] = true,
    ["SetFlag"] = true,
    ["ProccessActionBypasses"] = true,
    ["ProcessActionBypasses"] = true,
    ["PlayerBanned"] = true,
    ["RequestPartyKick"] = true,
}

local originalNamecall
local namecallHandler = function(self, ...)
    local method = getnamecallmethod()
    local n = select("#", ...)
    local args = { ... }

    if method == "InvokeServer" or method == "FireServer" then
        local name = ""
        pcall(function() name = tostring(self.Name or "") end)
        if BlockedRemotes[name] then return end

        pcall(function()
            if DirectionalHitEnabled and name == "Interact" and type(args[1]) == "table" then
                local data = args[1]
                local cam = workspace.CurrentCamera
                if cam and data.LookVector ~= nil then
                    local look = cam.CFrame.LookVector
                    local y = (typeof(data.LookVector) == "Vector3") and data.LookVector.Y or 0
                    local lv = Vector3.new(look.X, y, look.Z)
                    if lv.Magnitude > 0.001 then
                        data.LookVector = lv.Unit
                    end
                end
            end
        end)

        pcall(function()
            if name == "Interact" and type(args[1]) == "table" then
                local data = args[1]
                local act = tostring(data.Action or "")
                if act == "Spike" or act == "spike" then
                    if SpikeBoostEnabled then
                        local c = tonumber(SpikeBoostCharge) or 1
                        if c < 0 then c = 0 end
                        if c > 1 then c = 1 end
                        data.Charge = c
                    end
                    if PerfectSpikeAssistEnabled then
                        data.Charge = 1
                        if data.SpecialCharge == nil or (tonumber(data.SpecialCharge) or 0) < 0.000001 then
                            data.SpecialCharge = 0.000001
                        end
                    end
                end
            end
        end)

        pcall(function()
            if AutoStrongServeEveryServeEnabled and name == "Serve" and args[2] ~= nil then
                args[2] = ServeBoostPower
            end
        end)

        pcall(function()
            if serveRemote and AutoFarmEnabled and lockedTeamPosition and self == serveRemote then
                serveRemoteFired = true
                task.spawn(function()
                    task.wait(2)
                    if serveRemoteFired then
                        resetToTeamPosition()
                        serveRemoteFired = false
                    end
                end)
            end
        end)
    end

    return originalNamecall(self, unpack(args, 1, n))
end

task.defer(function()
    task.wait(1.5)
    pcall(function()
        if type(newcclosure) == "function" then
            originalNamecall = hookmetamethod(game, "__namecall", newcclosure(namecallHandler))
        else
            originalNamecall = hookmetamethod(game, "__namecall", namecallHandler)
        end
    end)
end)

local AntiModEnabled = false
local ModeratorList = {
    "ask_snapaple", "llotiiee", "Vezire123", "astratoka", "SneakyTiki1",
    "StarlightStarbrighht", "7Stxqr3", "xToruz", "koalacoco345",
    "Chrisdaman1122", "LebronjamesEl7a2e2ee", "PineCrumb", "HeyCrafted",
    "Dondred02", "Place_Reboot", "noahrepublic", "KumagawasFiction",
    "T0tallyN0tATr0ll", "Protori", "BarDowned", "GoodSirVolleyball"
}

local function isModerator(playerName)
    for _, modName in pairs(ModeratorList) do
        if playerName:lower() == modName:lower() then return true end
    end
    return false
end

local function checkForModerators()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isModerator(player.Name) then
            LocalPlayer:Kick("Kings Hub: Moderator detected. Safety kick activated.")
            return true
        end
    end
    return false
end

spawn(function()
    while true do
        if AntiModEnabled then checkForModerators() end
        wait(2)
    end
end)

Players.PlayerAdded:Connect(function(player)
    if AntiModEnabled and isModerator(player.Name) then
        LocalPlayer:Kick("Kings Hub: Moderator " .. player.Name .. " joined. Safety kick activated.")
    end
end)

local styleSelectChance, abilitySelectChance = nil, nil

local function cacheSelectChanceRemotes()
    pcall(function()
        local services = game:GetService("ReplicatedStorage")
            :WaitForChild("Packages", 4)
            :WaitForChild("_Index", 4)
            :WaitForChild("sleitnick_knit@1.7.0", 4)
            :WaitForChild("knit", 4)
            :WaitForChild("Services", 4)
        local st = services:FindFirstChild("StyleService")
        local ab = services:FindFirstChild("AbilityService")
        if st and st:FindFirstChild("RF") then
            styleSelectChance = st.RF:FindFirstChild("SelectChance")
        end
        if ab and ab:FindFirstChild("RF") then
            abilitySelectChance = ab.RF:FindFirstChild("SelectChance")
        end
        for _, svcName in ipairs({ "StyleService", "AbilityService" }) do
            local svc = services:FindFirstChild(svcName)
            local re = svc and svc:FindFirstChild("RE")
            if re then
                local cut = re:FindFirstChild("PlayRollCutscene")
                if cut and cut:IsA("RemoteEvent") then
                    cut.OnClientEvent:Connect(function()
                    end)
                end
                local ultra = re:FindFirstChild("UltraRolled")
                if ultra and ultra:IsA("RemoteEvent") then
                    ultra.OnClientEvent:Connect(function()
                    end)
                end
            end
        end
    end)
end

spawn(function() cacheSelectChanceRemotes() end)

-- ═══════════════════════════════════════
-- ADVANCED AUTO SPIN SYSTEM
-- ═══════════════════════════════════════
local function cacheSpinRemotes()
    pcall(function()
        local services = game:GetService("ReplicatedStorage")
            .Packages._Index["sleitnick_knit@1.7.0"].knit.Services
        local st = services:FindFirstChild("StyleService")
        local ab = services:FindFirstChild("AbilityService")
        if st and st:FindFirstChild("RF") then
            styleRollRemote = st.RF:FindFirstChild("Roll")
            styleSelectSlot = st.RF:FindFirstChild("SelectSlot")
            if not styleSelectChance then
                styleSelectChance = st.RF:FindFirstChild("SelectChance")
            end
        end
        if ab and ab:FindFirstChild("RF") then
            abilityRollRemote = ab.RF:FindFirstChild("Roll")
            abilitySelectSlot = ab.RF:FindFirstChild("SelectSlot")
            if not abilitySelectChance then
                abilitySelectChance = ab.RF:FindFirstChild("SelectChance")
            end
        end
    end)
end

spawn(function()
    task.wait(2)
    cacheSpinRemotes()
end)

local function readLastRollResult()
    local result = { name = "", rarity = "" }
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        local targetLower = string.lower(AutoSpinTargetName or "")
        for _, gui in pairs(pg:GetDescendants()) do
            if gui:IsA("TextLabel") or gui:IsA("TextButton") then
                local t = string.lower(tostring(gui.Text or ""))
                if t:find("secret", 1, true) then result.rarity = "Secret"
                elseif t:find("godly", 1, true) then result.rarity = "Godly"
                elseif t:find("legendary", 1, true) then result.rarity = "Legendary"
                elseif t:find("ultra", 1, true) then result.rarity = "Ultra"
                elseif t:find("evo", 1, true) then result.rarity = "Evo"
                end
                if targetLower ~= "" and t:find(targetLower, 1, true) then
                    result.name = AutoSpinTargetName
                end
            end
        end
    end)
    return result
end

local function doAutoSpinOnce()
    if AutoSpinBusy then return end
    if tick() - lastAutoSpin < AutoSpinSpeed then return end
    lastAutoSpin = tick()
    AutoSpinBusy = true
    cacheSpinRemotes()

    pcall(function()
        if AutoSpinType == "Style" and styleSelectSlot then
            styleSelectSlot:InvokeServer(AutoSpinSlot)
        elseif AutoSpinType == "Ability" and abilitySelectSlot then
            abilitySelectSlot:InvokeServer(AutoSpinSlot)
        end
    end)

    pcall(function()
        if AutoSpinTargetName ~= "" then
            if AutoSpinType == "Style" and styleSelectChance then
                pcall(function() styleSelectChance:InvokeServer(AutoSpinTargetName) end)
                pcall(function() styleSelectChance:InvokeServer() end)
            elseif AutoSpinType == "Ability" and abilitySelectChance then
                pcall(function() abilitySelectChance:InvokeServer(AutoSpinTargetName) end)
                pcall(function() abilitySelectChance:InvokeServer() end)
            end
        end
    end)

    local ok = false
    pcall(function()
        if AutoSpinType == "Style" and styleRollRemote then
            if AutoSpinUseLucky then
                styleRollRemote:InvokeServer(true)
            else
                styleRollRemote:InvokeServer()
            end
            ok = true
        elseif AutoSpinType == "Ability" and abilityRollRemote then
            if AutoSpinUseLucky then
                abilityRollRemote:InvokeServer(true)
            else
                abilityRollRemote:InvokeServer()
            end
            ok = true
        end
    end)

    task.delay(0.12, function()
    end)

    task.delay(0.55, function()
        local res = readLastRollResult()
        if AutoSpinStopOnTarget and AutoSpinTargetName ~= "" and res.name ~= "" then
            AutoSpinEnabled = false
            notify("Auto Spin stopped — got target: " .. tostring(res.name), 6)
        end
        if AutoSpinStopOnRarity ~= "" and res.rarity ~= "" then
            if string.lower(res.rarity) == string.lower(AutoSpinStopOnRarity) then
                AutoSpinEnabled = false
                notify("Auto Spin stopped — rarity: " .. tostring(res.rarity), 6)
            end
        end
        AutoSpinBusy = false
    end)

    if not ok then
        AutoSpinBusy = false
    end
end

spawn(function()
    while true do
        if AutoSpinEnabled then
            pcall(doAutoSpinOnce)
            task.wait(math.max(0.12, AutoSpinSpeed))
        else
            task.wait(0.4)
        end
    end
end)

local function isMasteryOrPurchaseUI(gui)
    local node = gui
    for _ = 1, 12 do
        if not node then break end
        local n = string.lower(tostring(node.Name or ""))
        if n:find("mastery", 1, true) or n:find("challenge", 1, true)
            or n:find("purchase", 1, true) or n:find("product", 1, true)
            or n:find("robux", 1, true) or n:find("prompt", 1, true)
            or n:find("shop", 1, true) or n:find("gamepass", 1, true)
            or n:find("devproduct", 1, true) or n:find("marketplace", 1, true) then
            return true
        end
        node = node.Parent
    end
    return false
end

local function clickSkipButtons()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    local VIM = game:GetService("VirtualInputManager")
    local function tryClick(gui)
        if isMasteryOrPurchaseUI(gui) then return end
        pcall(function()
            if firesignal then
                pcall(function() firesignal(gui.Activated) end)
                pcall(function() firesignal(gui.MouseButton1Click) end)
            end
        end)
        pcall(function()
            local pos = gui.AbsolutePosition
            local size = gui.AbsoluteSize
            local cx, cy = pos.X + size.X / 2, pos.Y + size.Y / 2
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.01)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        end)
    end
    for _, gui in pairs(pg:GetDescendants()) do
        if gui:IsA("GuiButton") and gui.Visible and gui.AbsoluteSize.X > 2 then
            if not isMasteryOrPurchaseUI(gui) then
                local name = string.lower(tostring(gui.Name or ""))
                local text = ""
                pcall(function()
                    if gui:IsA("TextButton") then text = string.lower(tostring(gui.Text or "")) end
                    local tl = gui:FindFirstChildWhichIsA("TextLabel", true)
                    if tl then text = text .. " " .. string.lower(tostring(tl.Text or "")) end
                end)
                local blob = name .. " " .. text
                local looksSkip = blob:find("skip", 1, true) or blob:find("continue", 1, true) or blob:find("claim", 1, true)
                if looksSkip and not blob:find("skip all", 1, true) and not blob:find("skipall", 1, true) then
                    tryClick(gui)
                end
            end
        end
    end
end



local function getSeasonRF(childName)
    local ok, remote = pcall(function()
        local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages", 5)
        local index = packages:WaitForChild("_Index", 5)
        local knitPkg = index:WaitForChild("sleitnick_knit@1.7.0", 5)
        local knit = knitPkg:WaitForChild("knit", 5)
        local services = knit:WaitForChild("Services", 5)
        local season = services:WaitForChild("SeasonService", 5)
        local rf = season:WaitForChild("RF", 5)
        return rf:WaitForChild(childName, 5)
    end)
    if ok then return remote end
    return nil
end

local function applyJumpBoost()
    if not JumpBoostEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local targetH = 7.2 * JumpBoostMult
    local targetP = 50 * JumpBoostMult
    pcall(function()
        if hum.UseJumpPower then
            hum.JumpPower = targetP
        else
            hum.JumpHeight = targetH
            if hum.JumpHeight == 0 then
                hum.JumpPower = targetP
            end
        end
    end)
end

spawn(function()
    while true do
        if JumpBoostEnabled then pcall(applyJumpBoost) wait(0.2)
        else wait(0.4) end
    end
end)

local JumpESPObjects = {}
local PredictAimObjects = {}

local function simpleAutoFarm()
    if not AutoFarmEnabled then return end
    local innerCylinder = workspace:FindFirstChild("Volleyball Lobby")
    if innerCylinder then
        local interactables = innerCylinder:FindFirstChild("Interactables")
        if interactables then
            local portal = interactables:FindFirstChild("Portal")
            if portal then
                local innerCyl = portal:FindFirstChild("InnerCylinder")
                if innerCyl then
                    LocalPlayer.Character:SetPrimaryPartCFrame(innerCyl.CFrame)
                    local maxWait = 10
                    local waitTime = 0
                    while waitTime < maxWait do
                        local teamSelectionUI = LocalPlayer.PlayerGui:FindFirstChild("Interface")
                        if teamSelectionUI then
                            local teamSelection = teamSelectionUI:FindFirstChild("TeamSelection")
                            if teamSelection and teamSelection.Visible then
                                local positionsToCheck = {
                                    {team = 1, position = 1}, {team = 1, position = 2},
                                    {team = 1, position = 3}, {team = 2, position = 1},
                                    {team = 2, position = 2}, {team = 2, position = 3}
                                }
                                local joinedAnyPosition = false
                                for _, posData in pairs(positionsToCheck) do
                                    local team = teamSelection:FindFirstChild(tostring(posData.team))
                                    if team then
                                        local teamHolder = team:FindFirstChild("TeamHolder")
                                        if teamHolder then
                                            local positionFrame = teamHolder:FindFirstChild(tostring(posData.position))
                                            if positionFrame then
                                                local headshot = positionFrame:FindFirstChild("Headshot")
                                                if not headshot or not headshot.Image or headshot.Image == "" or headshot.Image == "rbxasset://textures/ui/GuiImagePlaceholder.png" then
                                                    local absolutePos = positionFrame.AbsolutePosition
                                                    local absoluteSize = positionFrame.AbsoluteSize
                                                    local centerX = absolutePos.X + absoluteSize.X / 2
                                                    local centerY = absolutePos.Y + absoluteSize.Y / 2
                                                    local VIM = game:GetService("VirtualInputManager")
                                                    VIM:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
                                                    wait(0.1)
                                                    VIM:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
                                                    joinedAnyPosition = true
                                                    wait(3)
                                                    local VIM2 = game:GetService("VirtualInputManager")
                                                    VIM2:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
                                                    wait(0.05)
                                                    VIM2:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
                                                    autoClicking = true
                                                    spawn(function()
                                                        while autoClicking and AutoFarmEnabled do
                                                            local VIM = game:GetService("VirtualInputManager")
                                                            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                                                            wait(0.05)
                                                            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                                                            wait(0.05)
                                                            local ballPart = nil
                                                            for _, v in pairs(workspace:GetChildren()) do
                                                                if v.Name:find("CLIENT_BALL") and v:IsA("Model") then
                                                                    ballPart = v:FindFirstChildWhichIsA("BasePart")
                                                                    break
                                                                end
                                                            end
                                                            if ballPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                                                local playerRoot = LocalPlayer.Character.HumanoidRootPart
                                                                local ballPos = ballPart.Position
                                                                local currentPos = playerRoot.Position
                                                                local newCFrame = CFrame.new(ballPos.X, currentPos.Y, currentPos.Z) * playerRoot.CFrame - playerRoot.Position
                                                                LocalPlayer.Character:SetPrimaryPartCFrame(newCFrame)
                                                            end
                                                            wait(0.05)
                                                        end
                                                    end)
                                                    return
                                                end
                                            end
                                        end
                                    end
                                end
                                if not joinedAnyPosition then
                                    LocalPlayer:Kick("Kings Hub: All positions occupied. Finding new server...")
                                    return
                                end
                            end
                        end
                        wait(0.5)
                        waitTime = waitTime + 0.5
                    end
                end
            end
        end
    end
end

spawn(function()
    while true do
        if AutoFarmEnabled then
            local wasInGame = isInGameStable()
            wait(1)
            local isInGameNow = isInGameStable()
            if wasInGame and not isInGameNow then
                autoClicking = false
                lockedTeamPosition = nil
                lockedTeamCFrame = nil
                wait(2)
            end
        end
        wait(0.5)
    end
end)

spawn(function()
    local lastRoundOverHandle = 0
    while true do
        if AutoFarmEnabled then
            local playerGui = game:GetService("Players").LocalPlayer.PlayerGui
            if playerGui then
                local interface = playerGui:FindFirstChild("Interface")
                if interface then
                    local roundOverStats = interface:FindFirstChild("RoundOverStats")
                    if roundOverStats and roundOverStats.Visible then
                        if tick() - lastRoundOverHandle > 1 then
                            lastRoundOverHandle = tick()
                            pcall(function() roundOverStats.Visible = false end)
                            resetAutoFarmCycle()
                            spawn(function()
                                wait(0.5)
                                if AutoFarmEnabled and not autoClicking then simpleAutoFarm() end
                            end)
                        end
                    end
                end
            end
        end
        wait(1)
    end
end)

spawn(function()
    while true do
        if AutoFarmEnabled and not autoClicking then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not character or not humanoid or humanoid.Health <= 0 then
                autoClicking = false
                LocalPlayer.CharacterAdded:Wait()
                wait(1)
            else
                simpleAutoFarm()
            end
        end
        wait(3)
    end
end)

local function getPlayerTeam(player)
    if player.Team then return player.Team end
    return nil
end

local function isEnemy(player)
    if player == LocalPlayer then return false end
    local localTeam = getPlayerTeam(LocalPlayer)
    local playerTeam = getPlayerTeam(player)
    if localTeam and playerTeam then return localTeam ~= playerTeam end
    return true
end

local function isJumping(player)
    local character = player.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if humanoid and rootPart then
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then return true end
        if rootPart.AssemblyLinearVelocity.Y > 5 then return true end
    end
    return false
end

local function createJumpESP(player)
    local character = player.Character
    if not character then return end
    if JumpESPObjects[player] then JumpESPObjects[player]:Destroy() JumpESPObjects[player] = nil end
    local highlight = Instance.new("Highlight")
    highlight.Name = "JumpESP"
    highlight.Adornee = character
    highlight.FillColor = JumpESPColor
    highlight.OutlineColor = JumpESPColor
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = character
    JumpESPObjects[player] = highlight
end

local function removeJumpESP(player)
    if JumpESPObjects[player] then JumpESPObjects[player]:Destroy() JumpESPObjects[player] = nil end
end

local function createPredictLine(player)
    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    if not rootPart or not head then return end
    if PredictAimObjects[player] then
        if PredictAimObjects[player].Line then PredictAimObjects[player].Line:Destroy() end
        if PredictAimObjects[player].Point then PredictAimObjects[player].Point:Destroy() end
        PredictAimObjects[player] = nil
    end
    local lookVector = rootPart.CFrame.LookVector
    local spikeDirection = lookVector.Unit
    local line = Instance.new("Part")
    line.Name = "PredictLine"
    line.Anchored = true
    line.CanCollide = false
    line.Material = Enum.Material.Neon
    line.Color = PredictAimColor
    line.Size = Vector3.new(0.2, 0.2, PredictAimLength)
    line.Transparency = 0.3
    local startPos = head.Position + Vector3.new(0, 1, 0)
    local endPos = startPos + (spikeDirection * PredictAimLength)
    local midPoint = (startPos + endPos) / 2
    line.CFrame = CFrame.lookAt(midPoint, endPos)
    line.Parent = workspace
    local point = Instance.new("Part")
    point.Name = "PredictPoint"
    point.Anchored = true
    point.CanCollide = false
    point.Material = Enum.Material.Neon
    point.Color = PredictAimColor
    point.Size = Vector3.new(1, 1, 1)
    point.Shape = Enum.PartType.Ball
    point.Transparency = 0.3
    point.Position = endPos
    PredictAimObjects[player] = { Line = line, Point = point }
end

local function updatePredictLine(player)
    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    if not rootPart or not head then return end
    if PredictAimObjects[player] then
        local lookVector = rootPart.CFrame.LookVector
        local spikeDirection = lookVector.Unit
        local startPos = head.Position + Vector3.new(0, 1, 0)
        local endPos = startPos + (spikeDirection * PredictAimLength)
        local midPoint = (startPos + endPos) / 2
        if PredictAimObjects[player].Line then
            PredictAimObjects[player].Line.Size = Vector3.new(0.2, 0.2, PredictAimLength)
            PredictAimObjects[player].Line.CFrame = CFrame.lookAt(midPoint, endPos)
            PredictAimObjects[player].Line.Color = PredictAimColor
        end
        if PredictAimObjects[player].Point then
            PredictAimObjects[player].Point.Position = endPos
            PredictAimObjects[player].Point.Color = PredictAimColor
        end
    end
end

local function removePredictLine(player)
    if PredictAimObjects[player] then
        if PredictAimObjects[player].Line then PredictAimObjects[player].Line:Destroy() end
        if PredictAimObjects[player].Point then PredictAimObjects[player].Point:Destroy() end
        PredictAimObjects[player] = nil
    end
end

local function clearAllJumpESP()
    for player, obj in pairs(JumpESPObjects) do if obj then obj:Destroy() end end
    JumpESPObjects = {}
end

local function clearAllPredictAim()
    for player, obj in pairs(PredictAimObjects) do
        if obj then
            if obj.Line then obj.Line:Destroy() end
            if obj.Point then obj.Point:Destroy() end
        end
    end
    PredictAimObjects = {}
end

local function modifyBallHitbox()
    local size = HitboxSize or 0
    -- Force usable hitbox when auto combat features are on
    if size < 4 and (AutoSpikeEnabled or AutoReceiveEnabled or AutoSetEnabled or AutoJumpSetEnabled or SilentSpikeEnabled) then
        size = 10
    end
    if size <= 0 then return end
    for _, v in pairs(workspace:GetChildren()) do
        local n = tostring(v.Name or "")
        if (n:find("CLIENT_BALL") or n:find("BALL")) and v:IsA("Model") then
            local ballPart = v:FindFirstChildWhichIsA("BasePart")
            if not ballPart then
                for _, part in pairs(v:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "ExtendedHitbox" then
                        ballPart = part
                        break
                    end
                end
            end
            if ballPart then
                local existingHitbox = v:FindFirstChild("ExtendedHitbox")
                if existingHitbox and existingHitbox:IsA("BasePart") then
                    existingHitbox.Size = Vector3.new(size, size, size)
                    existingHitbox.Color = HitboxColor
                    existingHitbox.Transparency = HitboxTransparency
                    existingHitbox.Material = Enum.Material.ForceField
                    existingHitbox.CanCollide = false
                    existingHitbox.CanTouch = true
                    existingHitbox.CFrame = ballPart.CFrame
                else
                    local hitbox = Instance.new("Part")
                    hitbox.Name = "ExtendedHitbox"
                    hitbox.Size = Vector3.new(size, size, size)
                    hitbox.Transparency = HitboxTransparency
                    hitbox.Color = HitboxColor
                    hitbox.Material = Enum.Material.ForceField
                    hitbox.CanCollide = false
                    hitbox.CanTouch = true
                    hitbox.Massless = true
                    hitbox.Anchored = false
                    hitbox.Shape = Enum.PartType.Ball
                    hitbox.CFrame = ballPart.CFrame
                    hitbox.Parent = v
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = ballPart
                    weld.Part1 = hitbox
                    weld.Parent = hitbox
                end
            end
        end
    end
end

local function removeHitboxes()
    for _, v in pairs(workspace:GetChildren()) do
        if v.Name:find("CLIENT_BALL") and v:IsA("Model") then
            local hitbox = v:FindFirstChild("ExtendedHitbox")
            if hitbox then hitbox:Destroy() end
        end
    end
end

local function autoStrongServe()
    local playerGui = LocalPlayer.PlayerGui
    if not playerGui then return end
    local interface = playerGui:FindFirstChild("Interface")
    if not interface then return end
    local gameUI = interface:FindFirstChild("Game")
    if not gameUI then return end
    local power = gameUI:FindFirstChild("Power")
    if not power or not power.Visible then return end
    local arrow = power:FindFirstChild("Arrow")
    local extraPower = power:FindFirstChild("ExtraPower")
    if not arrow or not extraPower then return end
    local arrowPos = arrow.AbsolutePosition
    local arrowSize = arrow.AbsoluteSize
    local extraPowerPos = extraPower.AbsolutePosition
    local extraPowerSize = extraPower.AbsoluteSize
    local arrowCenterX = arrowPos.X + (arrowSize.X / 2)
    local extraPowerLeftX = extraPowerPos.X
    local extraPowerRightX = extraPowerPos.X + extraPowerSize.X
    local xAligned = arrowCenterX >= extraPowerLeftX and arrowCenterX <= extraPowerRightX
    local overlapsY = (arrowPos.Y < extraPowerPos.Y + extraPowerSize.Y) and (arrowPos.Y + arrowSize.Y > extraPowerPos.Y)
    if xAligned and overlapsY then
        local VIM = game:GetService("VirtualInputManager")
        local cx = arrowCenterX
        local cy = arrowPos.Y + (arrowSize.Y / 2)
        VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
        wait(0.05)
        VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
    end
end

local SPIKE_SET_KEYWORDS = {
    "spike", "set", "bump", "dive", "attack", "hit", "smash", "receive", "toss", "kill",
}

local function trackLooksSpikeOrSet(track)
    if not track then return false end
    local n = ""
    pcall(function()
        local anim = track.Animation
        if anim then
            n = string.lower(tostring(anim.Name or "") .. " " .. tostring(anim.AnimationId or ""))
        end
        n = n .. " " .. string.lower(tostring(track.Name or ""))
    end)
    for _, k in ipairs(SPIKE_SET_KEYWORDS) do
        if n:find(k, 1, true) then return true end
    end
    if n:find("jump", 1, true) or n:find("fall", 1, true) or n:find("run", 1, true)
        or n:find("walk", 1, true) or n:find("idle", 1, true) then
        return false
    end
    return false
end

local function stopSpikeSetTracks(character)
    if not character then return end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    pcall(function()
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            if trackLooksSpikeOrSet(track) then
                pcall(function() track:Stop(0) track:Destroy() end)
            end
        end
    end)
end

local function bindAnimDesync(character)
    if animDesyncConn then pcall(function() animDesyncConn:Disconnect() end) animDesyncConn = nil end
    if not character then return end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then animator = hum:WaitForChild("Animator", 3) end
    if not animator then return end
    animDesyncConn = animator.AnimationPlayed:Connect(function(track)
        if not AnimDesyncEnabled then return end
        if trackLooksSpikeOrSet(track) then
            pcall(function() track:Stop(0) end)
        end
    end)
end

local function enableAnimDesync()
    local char = LocalPlayer.Character
    if char then bindAnimDesync(char) end
end

local function disableAnimDesync()
    if animDesyncConn then pcall(function() animDesyncConn:Disconnect() end) animDesyncConn = nil end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    if AnimDesyncEnabled then task.defer(function() bindAnimDesync(char) end) end
end)

spawn(function()
    while true do
        if AnimDesyncEnabled then
            pcall(function() stopSpikeSetTracks(LocalPlayer.Character) end)
            wait(0.08)
        else
            wait(0.35)
        end
    end
end)

local function doSilentSpike()
    if tick() - lastSilentSpike < 0.22 then return end
    local character = LocalPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid then return end
    lastSilentSpike = tick()
    local playerPos = rootPart.Position
    local cam = workspace.CurrentCamera
    fireOfficialJump()
    pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Freefall) end)
    local best, bestDist, bestModel, bestBall, bestHb = nil, 14, nil, nil, nil
    for _, v in pairs(workspace:GetChildren()) do
        if v.Name:find("CLIENT_BALL") and v:IsA("Model") then
            local ball = v:FindFirstChildWhichIsA("BasePart")
            if ball then
                local hb = v:FindFirstChild("ExtendedHitbox")
                local aim = hb or ball
                local d = (playerPos - aim.Position).Magnitude
                local reach = hb and (2 + hb.Size.X / 2 + 4) or 9
                if d <= reach and d < bestDist then
                    bestDist = d
                    best = aim
                    bestModel = v
                    bestBall = ball
                    bestHb = hb
                end
            end
        end
    end
    if best then
        local usedOfficial = fireOfficialMove("Spike", rootPart, bestModel, bestBall, bestHb)
        if not usedOfficial then
            local VIM = game:GetService("VirtualInputManager")
            local cx, cy = 0, 0
            if cam then
                local sp, on = cam:WorldToScreenPoint(best.Position)
                if on then cx, cy = sp.X, sp.Y end
            end
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.015)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        end
        tryAutoAbility()
    end
    task.delay(0.02, function()
        if AnimDesyncEnabled or SilentSpikeEnabled then
            pcall(function() stopSpikeSetTracks(LocalPlayer.Character) end)
        end
    end)
end

local function autoSpike()
    local character = LocalPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local state = humanoid:GetState()
    local inAir = (state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall)
    -- Also allow if vertical velocity suggests airborne
    if not inAir then
        local vy = rootPart.AssemblyLinearVelocity.Y
        if vy > 2 or vy < -2 then
            inAir = true
        end
    end
    -- if not inAir then return end
    if tick() - lastAutoSpikeClick < 0.005 then return end

    local camera = workspace.CurrentCamera
    local playerPos = rootPart.Position
    local bestDist, bestModel, bestBall, bestHb, bestAim = math.huge, nil, nil, nil, nil

    -- Scan CLIENT_BALL models
    for _, v in pairs(workspace:GetChildren()) do
        local name = tostring(v.Name or "")
        if (name:find("CLIENT_BALL") or name:find("Ball") or name:find("BALL")) and (v:IsA("Model") or v:IsA("BasePart")) then
            local ball = nil
            local model = nil
            if v:IsA("Model") then
                model = v
                ball = v:FindFirstChildWhichIsA("BasePart")
            elseif v:IsA("BasePart") then
                ball = v
                model = v
            end
            if ball then
                local extendedHitbox = nil
                if model:IsA("Model") then
                    extendedHitbox = model:FindFirstChild("ExtendedHitbox")
                end
                local aimPart = extendedHitbox or ball
                local aimPos = aimPart.Position
                local hbRadius = 3
                if extendedHitbox and extendedHitbox:IsA("BasePart") then
                    hbRadius = math.max(extendedHitbox.Size.X, extendedHitbox.Size.Y, extendedHitbox.Size.Z) * 0.5
                elseif HitboxEnabled and HitboxSize and HitboxSize > 0 then
                    hbRadius = math.max(HitboxSize * 0.5, 3)
                end
                -- Generous reach for spike/counter
                local reach = 2.5 + hbRadius + 12.0
                local dist = (playerPos - aimPos).Magnitude
                local velocity = Vector3.zero
                pcall(function() velocity = ball.AssemblyLinearVelocity end)
                local spd = velocity.Magnitude

                local shouldHit = dist <= reach
                -- Counter: ball coming toward player
                if not shouldHit and spd >= 8 then
                    local toPlayer = playerPos - ball.Position
                    if toPlayer.Magnitude > 0.1 and velocity.Magnitude > 0.1 then
                        local closing = velocity.Unit:Dot(toPlayer.Unit) < -0.15
                        if closing and dist <= reach + 8 then
                            shouldHit = true
                        end
                    end
                    if dist <= reach + 5 and spd >= 15 then
                        shouldHit = true
                    end
                end
                -- Height check: ball roughly near player height window
                if shouldHit then
                    local dy = math.abs(aimPos.Y - playerPos.Y)
                    -- if dy > 18 then shouldHit = false end
                end
                if shouldHit and dist < bestDist then
                    bestDist = dist
                    bestModel = model
                    bestBall = ball
                    bestHb = extendedHitbox
                    bestAim = aimPos
                end
            end
        end
    end

    if not bestBall then return end

    lastAutoSpikeClick = tick()

    -- 1) Official Interact path
    local used = false
    if bestModel then
        used = fireOfficialMove("Spike", rootPart, bestModel, bestBall, bestHb)
    end

    -- 2) Always also send mouse click as backup (more reliable in practice)
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        local cx, cy = 0, 0
        if camera and bestAim then
            local sp, on = camera:WorldToScreenPoint(bestAim)
            if on then
                cx, cy = sp.X, sp.Y
            else
                -- center of screen fallback
                cx = camera.ViewportSize.X / 2
                cy = camera.ViewportSize.Y / 2
            end
        end
        VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
        task.wait(0.01)
        VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
    end)

    -- 3) Also try Jump remote + spike combo for silent reliability
    pcall(function()
        fireOfficialJump()
    end)

    if AnimDesyncEnabled then
        task.defer(function() pcall(function() stopSpikeSetTracks(LocalPlayer.Character) end) end)
    end
    tryAutoAbility()
end

local function autoJumpSet()
    if not AutoJumpSetEnabled then jumpSetPhase = 0 return end
    local character = LocalPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local state = humanoid:GetState()
    local inAir = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
    local playerPos = rootPart.Position
    local now = tick()
    local bestDist, bestReach, bestModel, bestBall, bestHb = math.huge, 4, nil, nil, nil
    for _, v in pairs(workspace:GetChildren()) do
        if v.Name:find("CLIENT_BALL") and v:IsA("Model") then
            local hb = v:FindFirstChild("ExtendedHitbox")
            local ball = v:FindFirstChildWhichIsA("BasePart")
            local target = hb or ball
            if target then
                local d = (playerPos - target.Position).Magnitude
                local reach = hb and (2 + hb.Size.X / 2) or 4
                if d < bestDist then
                    bestDist = d
                    bestReach = reach
                    bestModel = v
                    bestBall = ball
                    bestHb = hb
                end
            end
        end
    end
    if bestDist == math.huge then
        if now - jumpSetPhaseTime > 1.2 then jumpSetPhase = 0 end
        return
    end
    if jumpSetPhase > 0 and now - jumpSetPhaseTime > 2 then jumpSetPhase = 0 end
    if jumpSetPhase == 0 and not inAir then
        if bestDist <= bestReach + 1.5 and now - lastAutoJumpSetPress > 0.5 then
            lastAutoJumpSetPress = now
            jumpSetPhase = 1
            jumpSetPhaseTime = now
            fireOfficialJump()
            local VIM = game:GetService("VirtualInputManager")
            VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            wait(0.04)
            VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end
        return
    end
    if jumpSetPhase == 1 then
        if inAir and bestDist <= bestReach + 2.5 then
            local used = fireOfficialMove("JumpSet", rootPart, bestModel, bestBall, bestHb)
            if not used then used = fireOfficialMove("Set", rootPart, bestModel, bestBall, bestHb) end
            if not used then
                local VIM = game:GetService("VirtualInputManager")
                VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                wait(0.03)
                VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end
            if AnimDesyncEnabled then
                task.defer(function() pcall(function() stopSpikeSetTracks(LocalPlayer.Character) end) end)
            end
            jumpSetPhase = 0
            jumpSetPhaseTime = now
        elseif now - jumpSetPhaseTime > 0.85 then
            jumpSetPhase = 0
        end
    end
end

-- ═══════════════════════════════════════
-- AUTO RECEIVE (TOUCH-BASED + POLLING)
-- ═══════════════════════════════════════
local autoReceiveConnections = {}
local autoReceiveActive = false

local function disconnectAutoReceive()
    for _, conn in pairs(autoReceiveConnections) do
        pcall(function() conn:Disconnect() end)
    end
    autoReceiveConnections = {}
    autoReceiveActive = false
end

local function fireReceiveAction(ballModel, ballPart, hitbox)
    if tick() - lastAutoReceivePress < 0.01 then return end
    lastAutoReceivePress = tick()
    local character = LocalPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    -- Face the hitbox / ball
    pcall(function()
        local aim = (hitbox and hitbox.Position) or ballPart.Position
        local flat = Vector3.new(aim.X - rootPart.Position.X, 0, aim.Z - rootPart.Position.Z)
        if flat.Magnitude > 0.12 then
            rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flat.Unit)
        end
    end)
    -- Prefer ExtendedHitbox in official path
    local used = fireOfficialMove("Set", rootPart, ballModel, ballPart, hitbox)
    if not used then used = fireOfficialMove("Bump", rootPart, ballModel, ballPart, hitbox) end
    if not used then used = fireOfficialMove("Receive", rootPart, ballModel, ballPart, hitbox) end
    if not used then
        local VIM = game:GetService("VirtualInputManager")
        VIM:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
        task.wait(0.03)
        VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
    end
    tryAutoAbility()
    if AnimDesyncEnabled then
        task.defer(function() pcall(function() stopSpikeSetTracks(LocalPlayer.Character) end) end)
    end
end

local function scanAndBindBallTouch()
    if not AutoReceiveEnabled then return end
    disconnectAutoReceive()
    autoReceiveActive = true
    local character = LocalPlayer.Character
    if not character then return end
    local characterParts = {}
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then table.insert(characterParts, part) end
    end
    if #characterParts == 0 then return end
    for _, v in pairs(workspace:GetChildren()) do
        if v.Name:find("CLIENT_BALL") and v:IsA("Model") then
            local ball = v:FindFirstChildWhichIsA("BasePart")
            if ball then
                local hitbox = v:FindFirstChild("ExtendedHitbox")
                local target = hitbox or ball
                local conn = target.Touched:Connect(function(hit)
                    if not AutoReceiveEnabled then return end
                    if tick() - lastAutoReceivePress < 0.08 then return end
                    local ourChar = LocalPlayer.Character
                    if not ourChar then return end
                    local isOurPart = false
                    for _, cp in pairs(characterParts) do
                        if cp == hit or hit:IsDescendantOf(ourChar) then
                            isOurPart = true
                            break
                        end
                    end
                    if isOurPart then
                        fireReceiveAction(v, ball, hitbox)
                    end
                end)
                table.insert(autoReceiveConnections, conn)
            end
        end
    end
    for _, part in pairs(characterParts) do
        local conn = part.Touched:Connect(function(hit)
            if not AutoReceiveEnabled then return end
            if tick() - lastAutoReceivePress < 0.08 then return end
            local ballModel = hit and hit:FindFirstAncestorWhichIsA("Model")
            if ballModel and ballModel.Name:find("CLIENT_BALL") then
                local ball = ballModel:FindFirstChildWhichIsA("BasePart")
                local hb = ballModel:FindFirstChild("ExtendedHitbox")
                if ball then fireReceiveAction(ballModel, ball, hb) end
            end
        end)
        table.insert(autoReceiveConnections, conn)
    end
end

local autoSpikeTouchConnections = {}

local function disconnectAutoSpikeTouch()
    for _, conn in pairs(autoSpikeTouchConnections) do
        pcall(function() conn:Disconnect() end)
    end
    autoSpikeTouchConnections = {}
end

local function bindAutoSpikeTouch()
    if not AutoSpikeEnabled then return end
    disconnectAutoSpikeTouch()
    local character = LocalPlayer.Character
    if not character then return end
    local characterParts = {}
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then table.insert(characterParts, part) end
    end
    if #characterParts == 0 then return end
    for _, v in pairs(workspace:GetChildren()) do
        if v.Name:find("CLIENT_BALL") and v:IsA("Model") then
            local ball = v:FindFirstChildWhichIsA("BasePart")
            if ball then
                local hitbox = v:FindFirstChild("ExtendedHitbox")
                local target = hitbox or ball
                local conn = target.Touched:Connect(function(hit)
                    if not AutoSpikeEnabled then return end
                    if tick() - lastAutoSpikeClick < 0.005 then return end
                    local ourChar = LocalPlayer.Character
                    if not ourChar then return end
                    local isOurPart = false
                    for _, cp in pairs(characterParts) do
                        if cp == hit or hit:IsDescendantOf(ourChar) then
                            isOurPart = true
                            break
                        end
                    end
                    if isOurPart then
                        lastAutoSpikeClick = tick()
                        pcall(function() autoSpike() end)
                    end
                end)
                table.insert(autoSpikeTouchConnections, conn)
            end
        end
    end
end

local function autoReceivePolling()
    if not AutoReceiveEnabled then return end
    if tick() - lastAutoReceivePress < 0.05 then return end
    local character = LocalPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local state = humanoid:GetState()
    -- Receive is ground-based; skip only pure jump apex if needed
    local playerPos = rootPart.Position
    local bestDist, bestModel, bestBall, bestHb = math.huge, nil, nil, nil

    for _, v in pairs(workspace:GetChildren()) do
        local name = tostring(v.Name or "")
        if (name:find("CLIENT_BALL") or name:find("Ball") or name:find("BALL")) and (v:IsA("Model") or v:IsA("BasePart")) then
            local ball, model = nil, nil
            if v:IsA("Model") then
                model = v
                ball = v:FindFirstChildWhichIsA("BasePart")
            else
                ball = v
                model = v
            end
            if ball then
                local hb = model:IsA("Model") and model:FindFirstChild("ExtendedHitbox") or nil
                local aimPart = hb or ball
                local aimPos = aimPart.Position
                local hbRadius = 3
                if hb and hb:IsA("BasePart") then
                    hbRadius = math.max(hb.Size.X, hb.Size.Y, hb.Size.Z) * 0.5
                elseif HitboxEnabled and HitboxSize and HitboxSize > 0 then
                    hbRadius = math.max(HitboxSize * 0.5, 3)
                end
                local reach = 2.8 + hbRadius + 10.0
                local dist = (playerPos - aimPos).Magnitude
                local dy = math.abs(aimPos.Y - playerPos.Y)
                -- Prefer balls near body height for receive
                if dist <= reach and dy < 25 and dist < bestDist then
                    bestDist = dist
                    bestModel = model
                    bestBall = ball
                    bestHb = hb
                end
            end
        end
    end
    if bestModel and bestBall then
        fireReceiveAction(bestModel, bestBall, bestHb)
    end
end

local function refreshAutoReceiveBinding()
    if AutoReceiveEnabled then
        task.defer(scanAndBindBallTouch)
    else
        disconnectAutoReceive()
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    if AutoReceiveEnabled then
        task.defer(function() task.wait(1) scanAndBindBallTouch() end)
    end
    if AutoSpikeEnabled then
        task.defer(function() task.wait(1) bindAutoSpikeTouch() end)
    end
end)

spawn(function()
    while true do
        if AutoReceiveEnabled then pcall(autoReceivePolling) end
        task.wait(0.05)
    end
end)

local function hidePlayerName(p)
    if not p then return end
    local char = p.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if streamerOriginalDisplay[p] == nil then
            streamerOriginalDisplay[p] = {
                NameDisplayDistance = hum.NameDisplayDistance,
                DisplayDistanceType = hum.DisplayDistanceType,
            }
        end
        pcall(function()
            hum.NameDisplayDistance = 0
            hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end)
    end
    for _, obj in pairs(char:GetDescendants()) do
        if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
            local n = (obj.Name or ""):lower()
            if n:find("name") or n:find("tag") or n:find("overhead") or n:find("rank") then
                obj.Enabled = false
            end
        end
    end
end

local function restorePlayerName(p)
    if not p then return end
    local data = streamerOriginalDisplay[p]
    local char = p.Character
    if char and data then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum.NameDisplayDistance = data.NameDisplayDistance or 100
                hum.DisplayDistanceType = data.DisplayDistanceType or Enum.HumanoidDisplayDistanceType.Viewer
            end)
        end
        for _, obj in pairs(char:GetDescendants()) do
            if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                local n = (obj.Name or ""):lower()
                if n:find("name") or n:find("tag") or n:find("overhead") or n:find("rank") then
                    obj.Enabled = true
                end
            end
        end
    end
    streamerOriginalDisplay[p] = nil
end

local function applyStreamerMode()
    for _, p in pairs(Players:GetPlayers()) do hidePlayerName(p) end
end
local function disableStreamerMode()
    for _, p in pairs(Players:GetPlayers()) do restorePlayerName(p) end
    streamerOriginalDisplay = {}
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        if StreamerModeEnabled then task.defer(function() hidePlayerName(p) end) end
    end)
end)
for _, p in pairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function()
        if StreamerModeEnabled then task.defer(function() hidePlayerName(p) end) end
    end)
end
spawn(function()
    while true do
        if StreamerModeEnabled then pcall(applyStreamerMode) end
        wait(1.5)
    end
end)

local function isInLobby()
    local teamSelectionUI = LocalPlayer.PlayerGui:FindFirstChild("Interface")
    if teamSelectionUI then
        local teamSelection = teamSelectionUI:FindFirstChild("TeamSelection")
        if teamSelection and teamSelection.Visible then return true end
    end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return true end
    return false
end

local _rsCounter = 0
RunService.RenderStepped:Connect(function()
    _rsCounter = _rsCounter + 1
    -- Always build ExtendedHitbox when combat features need it (throttled)
    if (_rsCounter % 2 == 0) and (HitboxEnabled or AutoSpikeEnabled or AutoReceiveEnabled or AutoSetEnabled or AutoJumpSetEnabled or SilentSpikeEnabled) then
        pcall(function()
            local saved = HitboxSize
            if (not HitboxSize or HitboxSize < 4) and (AutoSpikeEnabled or AutoReceiveEnabled) then
                HitboxSize = 10
            end
            modifyBallHitbox()
            HitboxSize = saved
        end)
    end
    if JumpESPEnabled then
        pcall(function()
            for _, player in pairs(Players:GetPlayers()) do
                if isEnemy(player) then
                    if isJumping(player) then
                        if not JumpESPObjects[player] then
                            createJumpESP(player)
                        else
                            JumpESPObjects[player].FillColor = JumpESPColor
                            JumpESPObjects[player].OutlineColor = JumpESPColor
                        end
                    else
                        removeJumpESP(player)
                    end
                end
            end
        end)
    end
    if PredictAimEnabled then
        pcall(function()
            for _, player in pairs(Players:GetPlayers()) do
                if isEnemy(player) then
                    if not PredictAimObjects[player] then
                        createPredictLine(player)
                    else
                        updatePredictLine(player)
                    end
                end
            end
        end)
    end
    if AutoStrongServeEnabled then pcall(function() autoStrongServe() end) end
    if AutoSpikeEnabled and (_rsCounter % 2 == 0) then pcall(function() autoSpike() end) end
end)

Players.PlayerRemoving:Connect(function(player)
    removeJumpESP(player)
    removePredictLine(player)
end)

-- ═══════════════════════════════════════
-- OBSIDIAN UI (mobile-safe)
-- ═══════════════════════════════════════
task.wait(0.4)
local Window = Library:CreateWindow({
    Title = ScriptName,
    Center = true,
    AutoShow = false,
    Resizable = true,
    ShowCustomCursor = false,
    UnlockMouseWhileOpen = true,
    NotifySide = "Left",
    TabPadding = 8,
    MenuFadeTime = 0.15
})

local Tabs = {
    Main = Window:AddTab("Main", "activity"),
    Boost = Window:AddTab("Boost", "zap"),
    Character = Window:AddTab("Character", "user"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Misc = Window:AddTab("Misc", "layers"),
    GameJoin = Window:AddTab("Game Join", "play"),
    Spins = Window:AddTab("Spins", "star"),
    Settings = Window:AddTab("Settings", "settings"),
}

local MainLeft = Tabs.Main:AddLeftGroupbox("Features", "box")
local MainRight = Tabs.Main:AddRightGroupbox("Visual Features", "eye")
local BoostLeft = Tabs.Boost:AddLeftGroupbox("Jump", "arrow-up")
local BoostRight = Tabs.Boost:AddRightGroupbox("Spike", "sword")
local CharLeft = Tabs.Character:AddLeftGroupbox("Attributes", "sliders")
local CharRight = Tabs.Character:AddRightGroupbox("Movement", "move")
local VisualsLeft = Tabs.Visuals:AddLeftGroupbox("Effects", "sparkles")
local VisualsRight = Tabs.Visuals:AddRightGroupbox("Ball & Prediction", "target")
local MiscLeft = Tabs.Misc:AddLeftGroupbox("Shop & Claims", "shopping-cart")
local MiscRight = Tabs.Misc:AddRightGroupbox("Utility", "wrench")
local GameJoinLeft = Tabs.GameJoin:AddLeftGroupbox("Modes", "gamepad")
local SpinsBox = Tabs.Spins:AddLeftGroupbox("Lucky Spins", "star")
local SettingsLeft = Tabs.Settings:AddLeftGroupbox("Information", "info")
local SettingsRight = Tabs.Settings:AddRightGroupbox("UI Settings", "settings")

BoostLeft:AddToggle("JumpBoostToggle", {
    Text = "Jump Boost",
    Default = false,
    Tooltip = "Raises JumpHeight / JumpPower",
    Callback = function(Value)
        JumpBoostEnabled = Value
        if Value then pcall(applyJumpBoost) end
        notify(Value and "Jump Boost ON" or "Jump Boost OFF", 5)
    end
})
BoostLeft:AddSlider("JumpBoostSlider", {
    Text = "Jump Multiplier",
    Default = 1.35,
    Min = 1,
    Max = 2,
    Rounding = 2,
    Suffix = "x",
    Callback = function(Value)
        JumpBoostMult = Value
        if JumpBoostEnabled then pcall(applyJumpBoost) end
    end
})
BoostRight:AddToggle("SpikeBoostToggle", {
    Text = "Spike Boost",
    Default = false,
    Tooltip = "Boost Charge only when Action is Spike",
    Callback = function(Value)
        SpikeBoostEnabled = Value
        notify(Value and "Spike Boost ON" or "Spike Boost OFF", 5)
    end
})
BoostRight:AddSlider("SpikeBoostSlider", {
    Text = "Spike Charge",
    Default = 1,
    Min = 0.5,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        SpikeBoostCharge = Value
    end
})


SpinsBox:AddDivider()
SpinsBox:AddLabel("Infinity spins will come soon")
SpinsBox:AddDivider()
SpinsBox:AddLabel("Auto Spin System")

SpinsBox:AddToggle("AutoSpinToggle", {
    Text = "Auto Spin",
    Default = false,
    Tooltip = "Auto roll Style/Ability with stop conditions",
    Callback = function(Value)
        AutoSpinEnabled = Value
        if Value then cacheSpinRemotes() end
        notify(Value and "Auto Spin ON" or "Auto Spin OFF", 5)
    end
})

SpinsBox:AddDropdown("AutoSpinTypeDrop", {
    Text = "Spin Type",
    Values = {"Style", "Ability"},
    Default = "Style",
    Callback = function(Value)
        AutoSpinType = Value
        notify("Spin Type: " .. Value, 3)
    end
})

SpinsBox:AddSlider("AutoSpinSlotSlider", {
    Text = "Slot",
    Default = 1,
    Min = 1,
    Max = 5,
    Rounding = 0,
    Callback = function(Value)
        AutoSpinSlot = Value
    end
})

SpinsBox:AddToggle("AutoSpinStopTarget", {
    Text = "Stop On Target Name",
    Default = true,
    Tooltip = "Stops when target name is detected in UI",
    Callback = function(Value)
        AutoSpinStopOnTarget = Value
    end
})

SpinsBox:AddDropdown("AutoSpinStopRarityDrop", {
    Text = "Stop On Rarity",
    Values = {"None", "Secret", "Godly", "Legendary", "Ultra", "Evo"},
    Default = "None",
    Callback = function(Value)
        if Value == "None" then
            AutoSpinStopOnRarity = ""
        else
            AutoSpinStopOnRarity = Value
        end
    end
})

SpinsBox:AddToggle("AutoSpinLuckyToggle", {
    Text = "Use Lucky Spin",
    Default = true,
    Callback = function(Value)
        AutoSpinUseLucky = Value
    end
})

SpinsBox:AddSlider("AutoSpinSpeedSlider", {
    Text = "Spin Speed",
    Default = 0.35,
    Min = 0.15,
    Max = 1.5,
    Rounding = 2,
    Suffix = "s",
    Callback = function(Value)
        AutoSpinSpeed = Value
    end
})

-- Set target via notify helper (Obsidian may lack text input on some forks)
SpinsBox:AddButton({
    Text = "Set Target: Clear",
    Func = function()
        AutoSpinTargetName = ""
        notify("Target cleared (any)", 3)
    end,
    Tooltip = "Clear target name"
})
SpinsBox:AddButton({
    Text = "Target: Hidari",
    Func = function()
        AutoSpinTargetName = "Hidari"
        notify("Target = Hidari", 3)
    end
})
SpinsBox:AddButton({
    Text = "Target: Timeskip Hinto",
    Func = function()
        AutoSpinTargetName = "Timeskip Hinto"
        notify("Target = Timeskip Hinto", 3)
    end
})
SpinsBox:AddButton({
    Text = "Target: Shield Breaker",
    Func = function()
        AutoSpinTargetName = "Shield Breaker"
        notify("Target = Shield Breaker", 3)
    end
})
SpinsBox:AddButton({
    Text = "Target: Curve Spike",
    Func = function()
        AutoSpinTargetName = "Curve Spike"
        notify("Target = Curve Spike", 3)
    end
})
SpinsBox:AddButton({
    Text = "Target: Lead Feet",
    Func = function()
        AutoSpinTargetName = "Lead Feet"
        AutoSpinType = "Ability"
        notify("Target = Lead Feet (Ability)", 3)
    end
})
SpinsBox:AddButton({
    Text = "Target: Magnetic Pull",
    Func = function()
        AutoSpinTargetName = "Magnetic Pull"
        AutoSpinType = "Ability"
        notify("Target = Magnetic Pull (Ability)", 3)
    end
})
SpinsBox:AddButton({
    Text = "Target: Shield Breaker",
    Func = function()
        AutoSpinTargetName = "Shield Breaker"
        AutoSpinType = "Ability"
        notify("Target = Shield Breaker (Ability)", 3)
    end
})

MainLeft:AddToggle("HitboxToggle", {
    Text = "Enable Ball Hitbox",
    Default = HitboxEnabled,
    Tooltip = "Expand the ball hitbox for easier hitting",
    Callback = function(Value)
        HitboxEnabled = Value
        if HitboxEnabled then notify("Hitbox Enabled", 10)
        else removeHitboxes() notify("Hitbox Disabled", 10) end
    end
})
MainLeft:AddSlider("HitboxSize", {
    Text = "Hitbox Size",
    Default = 10,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Suffix = " studs",
    Callback = function(Value) HitboxSize = Value end
})
MainLeft:AddLabel("Hitbox Color"):AddColorPicker("HitboxColor", {
    Default = HitboxColor,
    Title = "Hitbox Color",
    Callback = function(Value) HitboxColor = Value end
})
MainLeft:AddSlider("HitboxTransparency", {
    Text = "Hitbox Transparency",
    Default = 80,
    Min = 40,
    Max = 95,
    Rounding = 0,
    Suffix = "%",
    Callback = function(Value) HitboxTransparency = Value / 100 end
})

MainLeft:AddDivider()
MainLeft:AddToggle("AutoStrongServeToggle", {
    Text = "Auto Strong Serve (UI Based)",
    Default = AutoStrongServeEnabled,
    Tooltip = "Auto-hit the purple zone for strong serves",
    Callback = function(Value)
        AutoStrongServeEnabled = Value
        notify(Value and "Auto Strong Serve Enabled" or "Auto Strong Serve Disabled", 10)
    end
})
MainLeft:AddToggle("AutoStrongServeEveryServeToggle", {
    Text = "Auto Strong Serve",
    Default = AutoStrongServeEveryServeEnabled,
    Tooltip = "Forces max power boost on every serve",
    Callback = function(Value)
        AutoStrongServeEveryServeEnabled = Value
        notify(Value and "Auto Strong Serve Enabled" or "Auto Strong Serve Disabled", 10)
    end
})
MainLeft:AddSlider("ServeBoostPower", {
    Text = "Serve Boost Power",
    Default = ServeBoostPower,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value) ServeBoostPower = Value end
})
MainLeft:AddToggle("AutoSpikeToggle", {
    Text = "Auto Spike + Counter",
    Default = AutoSpikeEnabled,
    Tooltip = "Spike any speed + counter. Keybind supported.",
    Callback = function(Value)
        AutoSpikeEnabled = Value
        if Value then bindAutoSpikeTouch() else disconnectAutoSpikeTouch() end
        notify(Value and "Auto Spike Enabled" or "Auto Spike Disabled", 10)
    end

}):AddKeyPicker("AutoSpikeKeybind", {
    Default = "E",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Auto Spike Key",
    Callback = function() end,
    ChangedCallback = function() end
})
MainLeft:AddToggle("SilentSpikeToggle", {
    Text = "Silent Spike",
    Default = false,
    Tooltip = "Keybind: Jump remote + Spike near ball (keeps jump anim)",
    Callback = function(Value)
        SilentSpikeEnabled = Value
        notify(Value and "Silent Spike ON — hold key near ball" or "Silent Spike OFF", 6)
    end
}):AddKeyPicker("SilentSpikeKeybind", {
    Default = "F",
    Text = "Silent Spike Key",
    Mode = "Hold",
    Callback = function() end,
    ChangedCallback = function() end
})
MainLeft:AddToggle("AnimDesyncToggle", {
    Text = "Anim Desync (No Spike/Set)",
    Default = false,
    Tooltip = "Keeps Jump anim — hides Spike / Set / Bump animations locally",
    Callback = function(Value)
        AnimDesyncEnabled = Value
        if Value then enableAnimDesync() notify("Anim Desync ON — Jump stays, Spike/Set hidden", 6)
        else disableAnimDesync() notify("Anim Desync OFF", 4) end
    end
})
MainLeft:AddToggle("OfficialPathToggle", {
    Text = "Official Move Path",
    Default = true,
    Tooltip = "Uses Interact remote (DoMove-style) for Spike/Set — more natural",
    Callback = function(Value)
        OfficialPathEnabled = Value
        notify(Value and "Official Path ON" or "Official Path OFF (keys only)", 5)
    end
})
MainLeft:AddToggle("PerfectSpikeAssistToggle", {
    Text = "Perfect Spike Assist",
    Default = true,
    Tooltip = "Samurai-style: max Charge when ball is deep in hitbox",
    Callback = function(Value)
        PerfectSpikeAssistEnabled = Value
        notify(Value and "Perfect Spike Assist ON" or "Perfect Spike Assist OFF", 5)
    end
})
MainLeft:AddToggle("AutoAbilityToggle", {
    Text = "Auto Ability / Ultimate",
    Default = false,
    Tooltip = "Fires UseAbility when spiking (if charge ready on server)",
    Callback = function(Value)
        AutoAbilityEnabled = Value
        notify(Value and "Auto Ability ON" or "Auto Ability OFF", 5)
    end
})
MainLeft:AddToggle("AutoJumpSetToggle", {
    Text = "Auto Jump Set",
    Default = false,
    Tooltip = "Jump + JumpSet (E) with hitbox reach",
    Callback = function(Value)
        AutoJumpSetEnabled = Value
        jumpSetPhase = 0
        notify(Value and "Auto Jump Set ON" or "Auto Jump Set OFF", 10)
    end
}):AddKeyPicker("AutoJumpSetKeybind", {
    Default = "V",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Jump Set Key",
    Callback = function() end,
    ChangedCallback = function() end
})
MainLeft:AddToggle("AutoReceiveToggle", {
    Text = "Auto Receive (Touch)",
    Default = false,
    Tooltip = "Touch-based: ball hitbox touches you -> Set/Bump instantly. Dual system: .Touched + polling.",
    Callback = function(Value)
        AutoReceiveEnabled = Value
        refreshAutoReceiveBinding()
        notify(Value and "Auto Receive ON (touch-based)" or "Auto Receive OFF", 6)
    end
})
MainLeft:AddToggle("DirectionalHitToggle", {
    Text = "Directional Hit",
    Default = DirectionalHitEnabled,
    Tooltip = "Redirect hits to camera direction",
    Callback = function(Value)
        DirectionalHitEnabled = Value
        notify(Value and "Directional Hit Enabled" or "Directional Hit Disabled", 10)
    end
})
MainLeft:AddToggle("AimbotCornerToggle", {
    Text = "Aimbot Corner (Ranked)",
    Default = AimbotCornerEnabled,
    Tooltip = "On jump, aim to opposite court corner — works in Ranked (dynamic corners)",
    Callback = function(Value)
        AimbotCornerEnabled = Value
        courtBounds = nil
        notify(Value and "Aimbot Corner Enabled" or "Aimbot Corner Disabled", 10)
    end
}):AddKeyPicker("AimbotCornerKeybind", {
    Default = "C",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Aimbot Corner Key",
    Callback = function() end,
    ChangedCallback = function() end
})
MainLeft:AddDropdown("AimbotCornerMode", {
    Text = "Corner Mode",
    Values = {"Left", "Right", "Auto"},
    Default = "Auto",
    Tooltip = "Left / Right fixed corner, or Auto = farthest from nearest enemy",
    Callback = function(Value)
        AimbotCornerMode = Value
        notify("Corner Mode: " .. Value, 5)
    end
})
MainLeft:AddToggle("MaxPowerSpikeToggle", {
    Text = "Max Power Spike (TSH)",
    Default = MaxPowerSpikeEnabled,
    Tooltip = "When standing still, tiny move keeps Spike Meter full (TSH Super Spike).",
    Callback = function(Value)
        MaxPowerSpikeEnabled = Value
        notify(Value and "Max Power Spike ON" or "Max Power Spike OFF", 10)
    end
}):AddKeyPicker("MaxPowerSpikeKeybind", {
    Default = "T",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Max Power Spike Key",
    Callback = function() end,
    ChangedCallback = function() end
})
MainLeft:AddToggle("CameraJumpToggle", {
    Text = "Camera Jump",
    Default = CameraJumpEnabled,
    Tooltip = "Rotate to camera direction when jumping",
    Callback = function(Value)
        CameraJumpEnabled = Value
        notify(Value and "Camera Jump Enabled" or "Camera Jump Disabled", 10)
    end
})
MainLeft:AddToggle("AutoSetToggle", {
    Text = "Auto Set",
    Default = AutoSetEnabled,
    Tooltip = "Automatically press Q to set when ball is coming towards you",
    Callback = function(Value)
        AutoSetEnabled = Value
        notify(Value and "Auto Set Enabled" or "Auto Set Disabled", 10)
    end
})

MainLeft:AddDivider()
MainLeft:AddToggle("AntiModToggle", {
    Text = "Anti-Moderator Protection",
    Default = AntiModEnabled,
    Tooltip = "Automatically kick when moderators join the server",
    Callback = function(Value)
        AntiModEnabled = Value
        if AntiModEnabled then notify("Anti-Mod Enabled", 10) checkForModerators()
        else notify("Anti-Mod Disabled", 10) end
    end
})
MainLeft:AddDivider()
MainLeft:AddToggle("SpeedToggle", {
    Text = "CFrame Speed",
    Default = SpeedEnabled,
    Tooltip = "Increase movement speed using CFrame manipulation",
    Callback = function(Value)
        SpeedEnabled = Value
        notify(Value and "Speed Enabled" or "Speed Disabled", 10)
    end
})
MainLeft:AddSlider("SpeedSlider", {
    Text = "Speed Value",
    Default = SpeedValue,
    Min = 0,
    Max = 10,
    Rounding = 1,
    Suffix = " speed",
    Callback = function(Value) SpeedValue = Value end
})

MainRight:AddToggle("StreamerModeToggle", {
    Text = "Streamer Mode",
    Default = false,
    Tooltip = "Hide usernames for recording",
    Callback = function(Value)
        StreamerModeEnabled = Value
        if Value then applyStreamerMode() notify("Streamer Mode ON", 4)
        else disableStreamerMode() notify("Streamer Mode OFF", 3) end
    end
})
MainRight:AddDivider()
MainRight:AddToggle("JumpESPToggle", {
    Text = "Enable Jump ESP",
    Default = JumpESPEnabled,
    Tooltip = "Highlight enemy jumps",
    Callback = function(Value)
        JumpESPEnabled = Value
        if JumpESPEnabled then notify("Jump ESP Enabled", 10)
        else clearAllJumpESP() notify("Jump ESP Disabled", 10) end
    end
})
MainRight:AddLabel("Jump ESP Color"):AddColorPicker("JumpESPColor", {
    Default = JumpESPColor,
    Title = "Jump ESP Color",
    Callback = function(Value) JumpESPColor = Value end
})
MainRight:AddDivider()
MainRight:AddToggle("PredictAimToggle", {
    Text = "Enable Predict Aim",
    Default = PredictAimEnabled,
    Tooltip = "Show spike prediction lines",
    Callback = function(Value)
        PredictAimEnabled = Value
        if PredictAimEnabled then notify("Predict Aim Enabled", 10)
        else clearAllPredictAim() notify("Predict Aim Disabled", 10) end
    end
})
MainRight:AddSlider("PredictAimLength", {
    Text = "Prediction Length",
    Default = PredictAimLength,
    Min = 0,
    Max = 50,
    Rounding = 0,
    Suffix = " studs",
    Callback = function(Value) PredictAimLength = Value end
})
MainRight:AddLabel("Predict Aim Color"):AddColorPicker("PredictAimColor", {
    Default = PredictAimColor,
    Title = "Predict Aim Color",
    Callback = function(Value) PredictAimColor = Value end
})

-- ═══════════════════════════════════════
-- ADVANCED FEATURES (ported clean)
-- ═══════════════════════════════════════

-- Character Attributes
local DiveSpeedMult = 1
local JumpPowerMult = 1
local SpeedMult = 1
local AirMoveEnabled = false
local AirMoveSpeed = 16
local AutoShiftLockEnabled = false
local bodyVelocity = nil

CharLeft:AddInput("DiveSpeedInput", {
    Default = "1",
    Numeric = true,
    Finished = true,
    Text = "Dive Speed Multiplier",
    Placeholder = "0.95",
    Callback = function(Value)
        local n = tonumber(Value)
        if n then
            DiveSpeedMult = n
            pcall(function() LocalPlayer:SetAttribute("Multiplier_DiveSpeed", n) end)
        end
    end
})
CharLeft:AddInput("JumpPowerInput", {
    Default = "1",
    Numeric = true,
    Finished = true,
    Text = "Jump Power Multiplier",
    Placeholder = "1.1",
    Callback = function(Value)
        local n = tonumber(Value)
        if n then
            JumpPowerMult = n
            pcall(function() LocalPlayer:SetAttribute("Multiplier_JumpPower", n) end)
        end
    end
})
CharLeft:AddInput("SpeedMultInput", {
    Default = "1",
    Numeric = true,
    Finished = true,
    Text = "Speed Multiplier",
    Placeholder = "0.85",
    Callback = function(Value)
        local n = tonumber(Value)
        if n then
            SpeedMult = n
            pcall(function() LocalPlayer:SetAttribute("Multiplier_Speed", n) end)
        end
    end
})

CharRight:AddToggle("AirMoveToggle", {
    Text = "Air Movement",
    Default = false,
    Tooltip = "Move freely while in the air",
    Callback = function(Value)
        AirMoveEnabled = Value
        if not Value and bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
        notify(Value and "Air Movement ON" or "Air Movement OFF", 4)
    end
})
CharRight:AddSlider("AirMoveSpeedSlider", {
    Text = "Air Move Speed",
    Default = 16,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(Value) AirMoveSpeed = Value end
})
CharRight:AddToggle("AutoShiftLockToggle", {
    Text = "Auto Shift Lock",
    Default = false,
    Tooltip = "Auto rotate to camera when jumping",
    Callback = function(Value)
        AutoShiftLockEnabled = Value
        notify(Value and "Auto Shift Lock ON" or "Auto Shift Lock OFF", 4)
    end
})

-- Air Movement loop
spawn(function()
    while true do
        if AirMoveEnabled then
            pcall(function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if root and hum then
                    local state = hum:GetState()
                    if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
                        if not bodyVelocity or not bodyVelocity.Parent then
                            bodyVelocity = Instance.new("BodyVelocity")
                            bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
                            bodyVelocity.Parent = root
                        end
                        local move = hum.MoveDirection
                        bodyVelocity.Velocity = Vector3.new(move.X * AirMoveSpeed, root.AssemblyLinearVelocity.Y, move.Z * AirMoveSpeed)
                    else
                        if bodyVelocity then
                            bodyVelocity:Destroy()
                            bodyVelocity = nil
                        end
                    end
                end
            end)
            task.wait(0.03)
        else
            task.wait(0.25)
        end
    end
end)

-- Auto Shift Lock
UserInputService.JumpRequest:Connect(function()
    if not AutoShiftLockEnabled then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local cam = workspace.CurrentCamera
    if cam then
        local look = cam.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude > 0.1 then
            root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
        end
    end
end)

-- Auto Counter (advanced)
local AutoCounterEnabled = false
local AutoCounterMove = "Auto"
local AutoCounterNetRange = 9
local AutoCounterLateral = 14
local AutoCounterDelay = 0.05
local AutoCounterJump = true
local lastAutoCounter = 0

MainLeft:AddToggle("AutoCounterToggle", {
    Text = "Auto Counter",
    Default = false,
    Tooltip = "Counters enemy spike near the net",
    Callback = function(Value)
        AutoCounterEnabled = Value
        notify(Value and "Auto Counter ON" or "Auto Counter OFF", 5)
    end
}):AddKeyPicker("AutoCounterKeybind", {
    Default = "N",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Auto Counter Key",
})
MainLeft:AddDropdown("AutoCounterMoveDrop", {
    Text = "Counter Move",
    Values = {"Auto", "Block", "Spike"},
    Default = "Auto",
    Callback = function(Value) AutoCounterMove = Value end
})
MainLeft:AddSlider("AutoCounterNetRange", {
    Text = "Counter Net Range",
    Default = 9,
    Min = 3,
    Max = 20,
    Rounding = 1,
    Callback = function(Value) AutoCounterNetRange = Value end
})
MainLeft:AddSlider("AutoCounterLateral", {
    Text = "Counter Width",
    Default = 14,
    Min = 4,
    Max = 30,
    Rounding = 1,
    Callback = function(Value) AutoCounterLateral = Value end
})
MainLeft:AddSlider("AutoCounterDelay", {
    Text = "Counter Delay",
    Default = 0.05,
    Min = 0,
    Max = 0.5,
    Rounding = 2,
    Callback = function(Value) AutoCounterDelay = Value end
})
MainLeft:AddToggle("AutoCounterJumpToggle", {
    Text = "Counter Auto Jump",
    Default = true,
    Callback = function(Value) AutoCounterJump = Value end
})

-- Fake Spike
local FakeSpikeEnabled = false
MainLeft:AddToggle("FakeSpikeToggle", {
    Text = "Fake Spike",
    Default = false,
    Tooltip = "Play spike animation on jump without hitting",
    Callback = function(Value)
        FakeSpikeEnabled = Value
        notify(Value and "Fake Spike ON" or "Fake Spike OFF", 4)
    end
})

-- Max Charge Special
local MaxChargeSpecialEnabled = false
MainLeft:AddToggle("MaxChargeSpecialToggle", {
    Text = "Max Charge Special",
    Default = false,
    Tooltip = "Force maximum special charge",
    Callback = function(Value)
        MaxChargeSpecialEnabled = Value
        notify(Value and "Max Charge Special ON" or "Max Charge Special OFF", 4)
    end
})

-- Sanju Tilt
local SanjuTiltEnabled = false
MainLeft:AddToggle("SanjuTiltToggle", {
    Text = "Sanju Tilt",
    Default = false,
    Tooltip = "Sanju tilt effect on hits",
    Callback = function(Value)
        SanjuTiltEnabled = Value
        notify(Value and "Sanju Tilt ON" or "Sanju Tilt OFF", 4)
    end
})

-- Ball Prediction Marker
local BallMarkerEnabled = false
local ballMarkerPart = nil
local ballMarkerLabel = nil

VisualsRight:AddToggle("BallMarkerToggle", {
    Text = "Landing Marker",
    Default = false,
    Tooltip = "Predict ball landing and show IN / OUT / NET",
    Callback = function(Value)
        BallMarkerEnabled = Value
        if not Value and ballMarkerPart then
            ballMarkerPart:Destroy()
            ballMarkerPart = nil
        end
        notify(Value and "Landing Marker ON" or "Landing Marker OFF", 4)
    end
})

local function updateBallMarker()
    if not BallMarkerEnabled then return end
    local ball = nil
    for _, v in pairs(workspace:GetChildren()) do
        if tostring(v.Name):find("CLIENT_BALL") and v:IsA("Model") then
            ball = v:FindFirstChildWhichIsA("BasePart")
            break
        end
    end
    if not ball then
        if ballMarkerPart then ballMarkerPart.Transparency = 1 end
        return
    end
    local vel = ball.AssemblyLinearVelocity
    local pos = ball.Position
    local gravity = workspace.Gravity
    local t = 0
    local landY = pos.Y
    for i = 1, 120 do
        t = t + 0.05
        local y = pos.Y + vel.Y * t - 0.5 * gravity * t * t
        if y <= 0.5 then
            landY = 0.5
            break
        end
    end
    local landPos = Vector3.new(pos.X + vel.X * t, landY, pos.Z + vel.Z * t)
    if not ballMarkerPart then
        ballMarkerPart = Instance.new("Part")
        ballMarkerPart.Name = "BallLandMarker"
        ballMarkerPart.Anchored = true
        ballMarkerPart.CanCollide = false
        ballMarkerPart.Material = Enum.Material.Neon
        ballMarkerPart.Size = Vector3.new(0.3, 8, 8)
        ballMarkerPart.Shape = Enum.PartType.Cylinder
        ballMarkerPart.Parent = workspace
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.fromOffset(80, 30)
        bb.AlwaysOnTop = true
        bb.Parent = ballMarkerPart
        ballMarkerLabel = Instance.new("TextLabel")
        ballMarkerLabel.Size = UDim2.fromScale(1, 1)
        ballMarkerLabel.BackgroundTransparency = 1
        ballMarkerLabel.Font = Enum.Font.GothamBold
        ballMarkerLabel.TextSize = 14
        ballMarkerLabel.TextColor3 = Color3.new(1, 1, 1)
        ballMarkerLabel.Parent = bb
    end
    ballMarkerPart.CFrame = CFrame.new(landPos) * CFrame.Angles(0, 0, math.rad(90))
    ballMarkerPart.Transparency = 0.4
    local inCourt = math.abs(landPos.X) < 22 and math.abs(landPos.Z) < 38
    if inCourt then
        ballMarkerPart.Color = Color3.fromRGB(60, 220, 90)
        ballMarkerLabel.Text = "IN"
        ballMarkerLabel.TextColor3 = Color3.fromRGB(60, 220, 90)
    else
        ballMarkerPart.Color = Color3.fromRGB(235, 60, 60)
        ballMarkerLabel.Text = "OUT"
        ballMarkerLabel.TextColor3 = Color3.fromRGB(235, 60, 60)
    end
end

RunService.RenderStepped:Connect(function()
    if BallMarkerEnabled then pcall(updateBallMarker) end
end)

-- Score Effect / Visual Changers (basic)
local ScoreEffectEnabled = false
VisualsLeft:AddToggle("ScoreEffectToggle", {
    Text = "Score Effect Changer",
    Default = false,
    Callback = function(Value)
        ScoreEffectEnabled = Value
        notify(Value and "Score Effect ON" or "Score Effect OFF", 4)
    end
})

-- Game Join buttons
local gameModes = {
    {"Chaos Mode", "ChaosMode"},
    {"1v1 Mini Map", "OnesMini"},
    {"2v2 Ranked", "Twos"},
    {"3v3 Ranked", "Threes"},
    {"4v4 Ranked", "Fours"},
    {"6v6 Ranked", "Sixes"},
    {"Training", "Training"},
}
for _, mode in ipairs(gameModes) do
    GameJoinLeft:AddButton({
        Text = mode[1],
        Func = function()
            notify("Joining " .. mode[1] .. "...", 3)
            pcall(function()
                local services = game:GetService("ReplicatedStorage").Packages._Index["sleitnick_knit@1.7.0"].knit.Services
                local rf = services.PartyService and services.PartyService.RF
                if rf and rf:FindFirstChild("RequestTeleport") then
                    rf.RequestTeleport:InvokeServer(mode[2])
                    notify("Joined " .. mode[1] .. "!", 4)
                end
            end)
        end
    })
end

-- Misc claims & shop
MiscLeft:AddButton({
    Text = "Claim Level Rewards",
    Func = function()
        pcall(function()
            local services = game:GetService("ReplicatedStorage").Packages._Index["sleitnick_knit@1.7.0"].knit.Services
            local rf = services.LevelService and services.LevelService.RF
            if rf and rf:FindFirstChild("ClaimLevelRewards") then
                rf.ClaimLevelRewards:InvokeServer()
                notify("Level rewards claimed", 4)
            end
        end)
    end
})
MiscLeft:AddButton({
    Text = "Claim Quest Rewards",
    Func = function()
        pcall(function()
            local services = game:GetService("ReplicatedStorage").Packages._Index["sleitnick_knit@1.7.0"].knit.Services
            local rf = services.QuestService and services.QuestService.RF
            if rf and rf:FindFirstChild("ClaimAll") then
                rf.ClaimAll:InvokeServer(true)
                notify("Quest rewards claimed", 4)
            end
        end)
    end
})
MiscLeft:AddButton({
    Text = "Buy Emote",
    Func = function()
        pcall(function()
            local services = game:GetService("ReplicatedStorage").Packages._Index["sleitnick_knit@1.7.0"].knit.Services
            local rf = services.PackService and services.PackService.RF
            if rf and rf:FindFirstChild("Open") then
                rf.Open:InvokeServer("Emote1")
            end
        end)
    end
})
MiscLeft:AddButton({
    Text = "Buy Effect",
    Func = function()
        pcall(function()
            local services = game:GetService("ReplicatedStorage").Packages._Index["sleitnick_knit@1.7.0"].knit.Services
            local rf = services.PackService and services.PackService.RF
            if rf and rf:FindFirstChild("Open") then
                rf.Open:InvokeServer("ScoreEffect1")
            end
        end)
    end
})

MiscRight:AddButton({
    Text = "Data Rollback",
    Func = function()
        pcall(function()
            local services = game:GetService("ReplicatedStorage").Packages._Index["sleitnick_knit@1.7.0"].knit.Services
            local rf = services.SettingsService and services.SettingsService.RF
            if rf and rf:FindFirstChild("UpdateKeybind") then
                rf.UpdateKeybind:InvokeServer("MouseButton1", true, "Spike")
            end
            TeleportService:Teleport(game.PlaceId)
        end)
    end
})

-- Anti-Lag
local AntiLagEnabled = false
local savedLighting = {}
MiscRight:AddToggle("AntiLagToggle", {
    Text = "Anti-Lag",
    Default = false,
    Tooltip = "Reduce graphics for better FPS",
    Callback = function(Value)
        AntiLagEnabled = Value
        if Value then
            pcall(function()
                local lighting = game:GetService("Lighting")
                savedLighting.Technology = lighting.Technology
                savedLighting.GlobalShadows = lighting.GlobalShadows
                lighting.Technology = Enum.Technology.Compatibility
                lighting.GlobalShadows = false
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end)
            notify("Anti-Lag ON", 4)
        else
            pcall(function()
                local lighting = game:GetService("Lighting")
                if savedLighting.Technology then lighting.Technology = savedLighting.Technology end
                if savedLighting.GlobalShadows ~= nil then lighting.GlobalShadows = savedLighting.GlobalShadows end
            end)
            notify("Anti-Lag OFF", 4)
        end
    end
})

-- Kisuki Dive / Lead Feet / Akari Dash (keybind based)
local KisukiDiveEnabled = false
local LeadFeetEnabled = false
local AkariDashEnabled = false

CharRight:AddToggle("KisukiDiveToggle", {
    Text = "Kisuki Dive",
    Default = false,
    Tooltip = "Enhanced dive",
    Callback = function(Value)
        KisukiDiveEnabled = Value
        notify(Value and "Kisuki Dive ON" or "Kisuki Dive OFF", 4)
    end
})
CharRight:AddToggle("LeadFeetToggle", {
    Text = "Lead Feet",
    Default = false,
    Tooltip = "Slam down with high acceleration",
    Callback = function(Value)
        LeadFeetEnabled = Value
        notify(Value and "Lead Feet ON" or "Lead Feet OFF", 4)
    end
}):AddKeyPicker("LeadFeetKey", {
    Default = "G",
    Mode = "Hold",
    Text = "Lead Feet Key",
})
CharRight:AddToggle("AkariDashToggle", {
    Text = "Akari Dash",
    Default = false,
    Tooltip = "Dash toward the ball",
    Callback = function(Value)
        AkariDashEnabled = Value
        notify(Value and "Akari Dash ON" or "Akari Dash OFF", 4)
    end
}):AddKeyPicker("AkariDashKey", {
    Default = "F",
    Mode = "Press",
    Text = "Akari Dash Key",
})

-- Lead Feet / Akari logic
spawn(function()
    while true do
        if LeadFeetEnabled and Options.LeadFeetKey and Options.LeadFeetKey:GetState() then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -80, root.AssemblyLinearVelocity.Z)
            end
        end
        task.wait(0.03)
    end
end)

SettingsLeft:AddLabel(ScriptName .. " v" .. ScriptVersion)
SettingsLeft:AddLabel("Last Updated: " .. LastUpdated)
SettingsLeft:AddDivider()
SettingsLeft:AddLabel("Creator: thiagxjzu3")
SettingsLeft:AddLabel("Thank you for using Kings Hub!")
SettingsLeft:AddDivider()
SettingsLeft:AddLabel("Credits")
SettingsLeft:AddLabel("Creator: thiagxjzu3")
SettingsLeft:AddLabel("UI Library: Obsidian")
SettingsLeft:AddLabel("Enjoy the script!")

SettingsRight:AddLabel("Menu bind")
    :AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
SettingsRight:AddButton({
    Text = "Unload Script",
    Func = function()
        notify("Unloading", 3)
        getgenv().KingsHubLoaded = false
        AutoFarmEnabled = false
        autoClicking = false
    end,
    Tooltip = "Unload the entire script"
})
SettingsRight:AddButton({
    Text = "Copy Discord Invite",
    Func = function()
        setclipboard("https://discord.gg/KVrZC5BAaF")
        notify("Copied", 3)
    end,
    Tooltip = "Copy discord invite link"
})

Library.ToggleKeybind = Options.MenuKeybind

pcall(function()
    if ThemeManager then
        ThemeManager:SetLibrary(Library)
        ThemeManager:SetFolder("KingsHub")
        ThemeManager:ApplyToTab(Tabs.Settings)
    end
end)

pcall(function()
    if SaveManager then
        SaveManager:SetLibrary(Library)
        SaveManager:SetFolder("KingsHub")
        SaveManager:IgnoreThemeSettings()
        SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
        SaveManager:BuildConfigSection(Tabs.Settings)
        SaveManager:LoadAutoloadConfig()
    end
end)

Library:OnUnload(function()
    getgenv().KingsHubLoaded = false
    StreamerModeEnabled = false
    AutoSpinEnabled = false
    JumpBoostEnabled = false
    SpikeBoostEnabled = false
    SilentSpikeEnabled = false
    AnimDesyncEnabled = false
    AutoReceiveEnabled = false
    AimbotCornerEnabled = false
    disconnectAutoReceive()
    pcall(disableAnimDesync)
    pcall(disableStreamerMode)
    warn("Kings Hub unloaded")
end)

spawn(function()
    while wait(0.12) do
        if Options.AutoSpikeKeybind and Toggles.AutoSpikeToggle then
            local ks = Options.AutoSpikeKeybind:GetState()
            if ks ~= AutoSpikeEnabled then
                AutoSpikeEnabled = ks
                Toggles.AutoSpikeToggle:SetValue(ks)
            end
        end
        if Options.AutoJumpSetKeybind and Toggles.AutoJumpSetToggle then
            local ks = Options.AutoJumpSetKeybind:GetState()
            if ks ~= AutoJumpSetEnabled then
                AutoJumpSetEnabled = ks
                Toggles.AutoJumpSetToggle:SetValue(ks)
                if not ks then jumpSetPhase = 0 end
            end
        end
        if Options.AimbotCornerKeybind and Toggles.AimbotCornerToggle then
            local ks = Options.AimbotCornerKeybind:GetState()
            if ks ~= AimbotCornerEnabled then
                AimbotCornerEnabled = ks
                Toggles.AimbotCornerToggle:SetValue(ks)
            end
        end
        if Options.MaxPowerSpikeKeybind and Toggles.MaxPowerSpikeToggle then
            local ks = Options.MaxPowerSpikeKeybind:GetState()
            if ks ~= MaxPowerSpikeEnabled then
                MaxPowerSpikeEnabled = ks
                Toggles.MaxPowerSpikeToggle:SetValue(ks)
            end
        end
        if SilentSpikeEnabled and Options.SilentSpikeKeybind then
            pcall(function()
                if Options.SilentSpikeKeybind:GetState() then
                    doSilentSpike()
                end
            end)
        end
    end
end)

task.defer(function()
    task.wait(0.6)
    pcall(function()
        if Window and Window.Open then
            Window:Open()
        elseif Library and Library.Toggle then
            Library:Toggle()
        end
    end)
    notify("Welcome to Kings Hub by thiagxjzu3. Enjoy!", 8)
    notify("Kings Hub v" .. ScriptVersion .. " loaded | " .. LastUpdated, 6)
end)
