if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(0.5)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local ScriptVersion = "5"
local ScriptName = "KingsHub"
local LastUpdated = "10-08-2026"

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library, ThemeManager, SaveManager

local function safeLoad(url)
    local ok, src = pcall(function() return game:HttpGet(url) end)
    if not ok or type(src) ~= "string" or #src < 100 then return nil end
    local ok2, res = pcall(function() return loadstring(src)() end)
    if ok2 then return res end
    return nil
end

Library = safeLoad(repo .. "Library.lua")
task.wait(0.15)
if Library then
    ThemeManager = safeLoad(repo .. "addons/ThemeManager.lua")
    task.wait(0.1)
    SaveManager = safeLoad(repo .. "addons/SaveManager.lua")
end
if not Library then
    warn("[KingsHub] Failed to load UI library")
    return
end

local Options = Library.Options
local Toggles = Library.Toggles
Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true
Library.ShowCustomCursor = false
pcall(function() Library:SetNotifySide("Left") end)

local function notify(msg, t)
    pcall(function()
        Library:Notify({ Title = ScriptName, Description = tostring(msg), Time = t or 6 })
    end)
end

-- STATE
local HitboxEnabled = false
local HitboxSize = 10
local HitboxColor = Color3.fromRGB(0, 255, 0)
local HitboxTransparency = 0.8
local AutoStrongServeEnabled = false
local AutoStrongServeEveryServeEnabled = false
local ServeBoostPower = 1
local DirectionalHitEnabled = false
local AimbotCornerEnabled = false
local CameraJumpEnabled = false
local MaxPowerSpikeEnabled = false
local SilentSpikeEnabled = false
local lastSilentSpike = 0
local DesyncEnabled = false
local desyncConns = {}
local AntiModEnabled = false
local StreamerModeEnabled = false
local PredictAimEnabled = false
local PredictAimColor = Color3.fromRGB(255, 255, 0)
local PredictAimLength = 25
local JumpBoostEnabled = false
local JumpBoostMult = 1.35
local SpikeBoostEnabled = false
local SpikeBoostCharge = 1
local PerfectSpikeAssistEnabled = true
local OfficialPathEnabled = true
local ScoreEffectEnabled = false
local PotatoModeEnabled = false
local ballJumpRemote, ballInteractRemote
local maxPowerPhase = 0
local PredictAimObjects = {}
local silentSpikeGui = nil
local streamerOriginalDisplay = {}
local moderatorList = {
    "ROBLOX", "Roblox", "Admin", "Moderator", "VolleyballLegends",
}

local function cacheBallRemotes()
    pcall(function()
        local services = ReplicatedStorage:FindFirstChild("Packages")
        if not services then return end
        services = services:FindFirstChild("_Index")
        if not services then return end
        services = services:FindFirstChild("sleitnick_knit@1.7.0")
        if not services then return end
        services = services:FindFirstChild("knit")
        if not services then return end
        services = services:FindFirstChild("Services")
        if not services then return end
        local bs = services:FindFirstChild("BallService")
        local rf = bs and bs:FindFirstChild("RF")
        if rf then
            ballJumpRemote = rf:FindFirstChild("Jump") or ballJumpRemote
            ballInteractRemote = rf:FindFirstChild("Interact") or ballInteractRemote
        end
    end)
end
cacheBallRemotes()
task.spawn(function()
    for _ = 1, 8 do
        if ballJumpRemote and ballInteractRemote then break end
        task.wait(1)
        cacheBallRemotes()
    end
end)

-- HITBOX
local function modifyBallHitbox()
    local size = HitboxSize
    if size <= 0 then return end
    for _, v in pairs(workspace:GetChildren()) do
        local n = tostring(v.Name or "")
        if (n:find("CLIENT_BALL") or n:find("BALL")) and v:IsA("Model") then
            local ball = v:FindFirstChildWhichIsA("BasePart")
            if ball then
                local hb = v:FindFirstChild("ExtendedHitbox")
                if hb and hb:IsA("BasePart") then
                    hb.Size = Vector3.new(size, size, size)
                    hb.Color = HitboxColor
                    hb.Transparency = HitboxTransparency
                    hb.CFrame = ball.CFrame
                else
                    local part = Instance.new("Part")
                    part.Name = "ExtendedHitbox"
                    part.Size = Vector3.new(size, size, size)
                    part.Transparency = HitboxTransparency
                    part.Color = HitboxColor
                    part.Material = Enum.Material.ForceField
                    part.CanCollide = false
                    part.CanTouch = true
                    part.Massless = true
                    part.Shape = Enum.PartType.Ball
                    part.CFrame = ball.CFrame
                    part.Parent = v
                    local w = Instance.new("WeldConstraint")
                    w.Part0 = ball
                    w.Part1 = part
                    w.Parent = part
                end
            end
        end
    end
end

local function removeHitboxes()
    for _, v in pairs(workspace:GetChildren()) do
        if tostring(v.Name):find("CLIENT_BALL") and v:IsA("Model") then
            local hb = v:FindFirstChild("ExtendedHitbox")
            if hb then hb:Destroy() end
        end
    end
end

-- COMBAT
local function getBallId(model)
    if not model then return nil end
    local name = tostring(model.Name or "")
    local id = tonumber(name:match("(%d+)"))
    if id then return id end
    for _, attr in ipairs({ "BallId", "Id", "ballId", "ID", "NetId" }) do
        local v = model:GetAttribute(attr)
        if v ~= nil then
            local n = tonumber(v)
            if n then return n end
        end
    end
    local val = model:FindFirstChild("BallId") or model:FindFirstChild("Id")
    if val and val:IsA("ValueBase") then
        return tonumber(val.Value)
    end
    return nil
end

local function fireSpikePayload(root, model, ball)
    cacheBallRemotes()
    if not ballInteractRemote then return false end
    local cam = workspace.CurrentCamera
    local look = (cam and cam.CFrame.LookVector) or root.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, -1) else flat = flat.Unit end
    look = look.Unit
    local id = getBallId(model)
    local payload = {
        Action = "Spike",
        Charge = 1,
        LookVector = look,
        TiltDirection = flat,
        MoveDirection = flat,
        From = "Client",
        SpecialCharge = 0.000001,
    }
    if id then payload.BallId = id end
    local ok = pcall(function()
        if ballInteractRemote:IsA("RemoteFunction") then
            ballInteractRemote:InvokeServer(payload)
        else
            ballInteractRemote:FireServer(payload)
        end
    end)
    -- second style some builds use lowercase action
    pcall(function()
        local p2 = {
            action = "Spike",
            Action = "Spike",
            Charge = 1,
            charge = 1,
            LookVector = look,
            TiltDirection = flat,
            MoveDirection = flat,
            From = "Client",
            BallId = id,
            ballId = id,
        }
        if ballInteractRemote:IsA("RemoteFunction") then
            ballInteractRemote:InvokeServer(p2)
        else
            ballInteractRemote:FireServer(p2)
        end
    end)
    return ok
end

local function getAimLook(root)
    local look = root.CFrame.LookVector
    local cam = workspace.CurrentCamera
    if DirectionalHitEnabled and cam then look = cam.CFrame.LookVector end
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, -1) else flat = flat.Unit end
    return look.Unit, flat
end

local function fireMove(action, root, model, ball, hb)
    if not OfficialPathEnabled or not ballInteractRemote then return false end
    return pcall(function()
        local look, tilt = getAimLook(root)
        local charge = 1
        if (action == "Spike" or action == "spike") then
            if SpikeBoostEnabled then charge = math.clamp(tonumber(SpikeBoostCharge) or 1, 0, 1) end
            if PerfectSpikeAssistEnabled then charge = 1 end
        end
        local payload = {
            Action = action, Charge = charge, LookVector = look,
            TiltDirection = tilt, MoveDirection = tilt, From = "Client", SpecialCharge = 0.000001,
        }
        local id = getBallId(model)
        if id then payload.BallId = id end
        if ballInteractRemote:IsA("RemoteFunction") then
            ballInteractRemote:InvokeServer(payload)
        else
            ballInteractRemote:FireServer(payload)
        end
    end)
end

local function fireJump()
    cacheBallRemotes()
    pcall(function()
        if not ballJumpRemote then return end
        if ballJumpRemote:IsA("RemoteFunction") then
            ballJumpRemote:InvokeServer()
        else
            ballJumpRemote:FireServer()
        end
    end)
end

local function findBallNear(maxDist)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local best, bestD, bestModel, bestBall, bestHb = nil, maxDist or 22, nil, nil, nil
    for _, v in pairs(workspace:GetChildren()) do
        local n = tostring(v.Name or "")
        if (n:find("CLIENT_BALL") or n:find("BALL")) and v:IsA("Model") then
            local ball = v:FindFirstChildWhichIsA("BasePart")
            if ball then
                local hb = v:FindFirstChild("ExtendedHitbox")
                local aim = hb or ball
                local d = (root.Position - aim.Position).Magnitude
                if d < bestD then
                    bestD, best, bestModel, bestBall, bestHb = d, aim, v, ball, hb
                end
            end
        end
    end
    return best, bestModel, bestBall, bestHb
end

local function stopSpikeAnims(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local n = string.lower(tostring(track.Name or ""))
        if n:find("spike") or n:find("attack") or n:find("swing") or n:find("hit") then
            pcall(function() track:Stop(0) end)
        end
    end
end

local function pressGameSpike()
    -- only native input, no remotes / no payloads
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        local cam = workspace.CurrentCamera
        local cx = cam and (cam.ViewportSize.X / 2) or 0
        local cy = cam and (cam.ViewportSize.Y / 2) or 0
        local aim = select(1, findBallNear(30))
        if cam and aim then
            local sp, on = cam:WorldToViewportPoint(aim.Position)
            if on then cx, cy = sp.X, sp.Y end
        end
        VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
        task.wait(0.03)
        VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
    end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, gui in ipairs(pg:GetDescendants()) do
            if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                local t = string.lower(tostring(gui.Text or "") .. " " .. tostring(gui.Name or ""))
                if gui.Visible and (t:find("spike") or t:find("pico")) and not t:find("kingshub") then
                    pcall(function()
                        local VIM = game:GetService("VirtualInputManager")
                        local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
                        local x, y = pos.X + size.X / 2, pos.Y + size.Y / 2
                        VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
                        task.wait(0.02)
                        VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
                    end)
                    break
                end
            end
        end
    end)
end

local function doSilentSpike()
    if not SilentSpikeEnabled then return end
    if tick() - lastSilentSpike < 0.2 then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    lastSilentSpike = tick()
    cacheBallRemotes()

    -- grounded: face camera only (NO jump)
    local c = workspace.CurrentCamera
    if c then
        local look = c.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude > 0.05 then
            root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
        end
    end

    -- silent locally
    stopSpikeAnims(char)
    task.delay(0.05, function() stopSpikeAnims(LocalPlayer.Character) end)
    task.delay(0.12, function() stopSpikeAnims(LocalPlayer.Character) end)

    -- ONLY Spike remote (Interact) — no Jump
    local _, model, ball = findBallNear(28)
    if ball then
        fireSpikePayload(root, model, ball)
        fireMove("Spike", root, model, ball, nil)
    else
        fireSpikePayload(root, nil, nil)
    end
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not SilentSpikeEnabled then return end
    if input.KeyCode == Enum.KeyCode.C then
        doSilentSpike()
    end
end)

local function destroySilentSpikeButton()
    if silentSpikeGui then
        pcall(function() silentSpikeGui:Destroy() end)
        silentSpikeGui = nil
    end
end

local function createSilentSpikeButton()
    destroySilentSpikeButton()
    local pg = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
    if not pg then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "KingsHub_SilentSpike"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 100
    pcall(function()
        if gethui then gui.Parent = gethui() else gui.Parent = pg end
    end)
    if not gui.Parent then gui.Parent = pg end
    silentSpikeGui = gui

    local btn = Instance.new("TextButton")
    btn.Name = "SpikeBtn"
    btn.Size = UDim2.fromOffset(78, 78)
    btn.Position = UDim2.new(1, -110, 0.58, 0)
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
    btn.BackgroundTransparency = 0.1
    btn.BorderSizePixel = 0
    btn.Text = "Pico"
    btn.TextColor3 = Color3.fromRGB(240, 245, 240)
    btn.TextSize = 17
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = true
    btn.ZIndex = 10
    btn.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 255, 160)
    stroke.Thickness = 2.5
    stroke.Transparency = 0.2
    stroke.Parent = btn

    -- drag vs tap
    local dragging = false
    local moved = false
    local dragStart, startPos
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = btn.Position
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and not moved then
                doSilentSpike()
            end
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging or not dragStart then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            if delta.Magnitude > 12 then moved = true end
            if moved then
                btn.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end
    end)
end

local function autoStrongServe()
    local pg = LocalPlayer.PlayerGui
    local power = pg and pg:FindFirstChild("Interface") and pg.Interface:FindFirstChild("Game") and pg.Interface.Game:FindFirstChild("Power")
    if not power or not power.Visible then return end
    local arrow, extra = power:FindFirstChild("Arrow"), power:FindFirstChild("ExtraPower")
    if not arrow or not extra then return end
    local ax = arrow.AbsolutePosition.X + arrow.AbsoluteSize.X / 2
    local left, right = extra.AbsolutePosition.X, extra.AbsolutePosition.X + extra.AbsoluteSize.X
    local overlapY = arrow.AbsolutePosition.Y < extra.AbsolutePosition.Y + extra.AbsoluteSize.Y
        and arrow.AbsolutePosition.Y + arrow.AbsoluteSize.Y > extra.AbsolutePosition.Y
    if ax >= left and ax <= right and overlapY then
        local VIM = game:GetService("VirtualInputManager")
        local cy = arrow.AbsolutePosition.Y + arrow.AbsoluteSize.Y / 2
        VIM:SendMouseButtonEvent(ax, cy, 0, true, game, 1)
        task.wait(0.04)
        VIM:SendMouseButtonEvent(ax, cy, 0, false, game, 1)
    end
end

-- light namecall hook
pcall(function()
    local originalNamecall
    local handler = function(self, ...)
        local method = getnamecallmethod()
        local n = select("#", ...)
        local args = { ... }
        if method == "InvokeServer" or method == "FireServer" then
            local name = ""
            pcall(function() name = tostring(self.Name or "") end)
            if name == "Interact" and type(args[1]) == "table" then
                local data = args[1]
                if DirectionalHitEnabled then
                    local cam = workspace.CurrentCamera
                    if cam and data.LookVector ~= nil then
                        local look = cam.CFrame.LookVector
                        local y = (typeof(data.LookVector) == "Vector3") and data.LookVector.Y or 0
                        local lv = Vector3.new(look.X, y, look.Z)
                        if lv.Magnitude > 0.001 then data.LookVector = lv.Unit end
                    end
                end
                local act = tostring(data.Action or "")
                if act == "Spike" or act == "spike" then
                    if SpikeBoostEnabled then data.Charge = math.clamp(tonumber(SpikeBoostCharge) or 1, 0, 1) end
                    if PerfectSpikeAssistEnabled then
                        data.Charge = 1
                        if not data.SpecialCharge or (tonumber(data.SpecialCharge) or 0) < 0.000001 then
                            data.SpecialCharge = 0.000001
                        end
                    end
                end
            end
            if AutoStrongServeEveryServeEnabled and name == "Serve" and args[2] ~= nil then
                args[2] = ServeBoostPower
            end
        end
        return originalNamecall(self, unpack(args, 1, n))
    end
    task.defer(function()
        task.wait(1)
        pcall(function()
            if type(newcclosure) == "function" then
                originalNamecall = hookmetamethod(game, "__namecall", newcclosure(handler))
            else
                originalNamecall = hookmetamethod(game, "__namecall", handler)
            end
        end)
    end)
end)

-- CORNER AIMBOT (RNCRAZY)
local cam = workspace.CurrentCamera
local courtCenter = Vector3.new(-393, -24.2, -1356.6)
local courtW, courtL = 52, 102
local netZ, floorY = -1356.6, -24.2
local CornerFOV = 250
local cornerMySide, cornerCurrent, cornerPinning = nil, nil, false
local cornerPts = { Left = Vector3.zero, Right = Vector3.zero }
local cornerLastJump, cornerWasAir = 0, false
local cornerFolder = Instance.new("Folder")
cornerFolder.Name = "CornerAimVFX"
cornerFolder.Parent = workspace

local function makeMark(name, pos)
    local p = Instance.new("Part")
    p.Name, p.Anchored, p.CanCollide = name, true, false
    p.CanQuery, p.CanTouch = false, false
    p.Material = Enum.Material.SmoothPlastic
    p.Color = Color3.fromRGB(25, 28, 30)
    p.Shape = Enum.PartType.Ball
    p.Size = Vector3.new(3, 1.6, 3)
    p.Position, p.Transparency = pos, 0.35
    p.Parent = cornerFolder
    return p
end

local function findCourt()
    local map = workspace:FindFirstChild("Map")
    local court = map and map:FindFirstChild("Court")
    if court and court:IsA("BasePart") then
        courtCenter, courtW, courtL = court.Position, court.Size.X, court.Size.Z
        netZ, floorY = court.Position.Z, court.Position.Y
    end
end
findCourt()

local function getSide()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return cornerMySide end
    local d = hrp.Position.Z - netZ
    if math.abs(d) < 6 then return cornerMySide end
    return d > 0 and 1 or -1
end

local function corners()
    local s = getSide()
    if s then cornerMySide = s end
    if not cornerMySide then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        cornerMySide = (hrp and hrp.CFrame.LookVector.Z > 0) and -1 or 1
    end
    local enemy = -cornerMySide
    local deepZ = courtCenter.Z + enemy * (courtL / 2 - 3)
    return {
        Right = Vector3.new(courtCenter.X + (courtW / 2 - 2.5), floorY + 1, deepZ),
        Left = Vector3.new(courtCenter.X - (courtW / 2 - 2.5), floorY + 1, deepZ),
    }
end

cornerPts = corners()
local leftMark = makeMark("LeftHalf", Vector3.new(cornerPts.Left.X, floorY + 0.8, cornerPts.Left.Z))
local rightMark = makeMark("RightHalf", Vector3.new(cornerPts.Right.X, floorY + 0.8, cornerPts.Right.Z))

local function refreshMarks()
    cornerPts = corners()
    leftMark.Position = Vector3.new(cornerPts.Left.X, floorY + 0.8, cornerPts.Left.Z)
    rightMark.Position = Vector3.new(cornerPts.Right.X, floorY + 0.8, cornerPts.Right.Z)
end

local function pickCorner()
    local m = UserInputService:GetMouseLocation()
    local inset = GuiService:GetGuiInset()
    local mp = Vector2.new(m.X, m.Y - inset.Y)
    local best, bestD = nil, CornerFOV
    for name, pos in pairs(cornerPts) do
        local sp, vis = cam:WorldToViewportPoint(pos + Vector3.new(0, 2, 0))
        if vis then
            local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
            if d < bestD then bestD, best = d, name end
        end
    end
    return best
end

local function snapTo(pos)
    if cornerPinning then return end
    cornerPinning = true
    task.spawn(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not hrp then cornerPinning = false return end
        local oldAuto = hum and hum.AutoRotate
        if hum then hum.AutoRotate = false end
        local start = os.clock()
        while os.clock() - start < 1.2 do
            if not AimbotCornerEnabled or not cornerPinning then break end
            hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then break end
            hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                local st = hum:GetState()
                if (st == Enum.HumanoidStateType.Landed or st == Enum.HumanoidStateType.Running)
                    and (hrp.Position.Y - floorY) < 4 and os.clock() - start > 0.3 then break end
            end
            local hp = hrp.Position
            hrp.CFrame = CFrame.lookAt(hp, Vector3.new(pos.X, hp.Y, pos.Z))
            task.wait()
        end
        if hum and oldAuto ~= nil then hum.AutoRotate = oldAuto end
        cornerPinning = false
    end)
end

local function doJumpAim()
    if not AimbotCornerEnabled or cornerPinning then return end
    local pick = pickCorner() or cornerCurrent
    if pick and cornerPts[pick] then
        cornerCurrent = pick
        cornerLastJump = os.clock()
        snapTo(cornerPts[pick])
    end
end

local function applyJumpBoost()
    if not JumpBoostEnabled then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        if hum.UseJumpPower then hum.JumpPower = 50 * JumpBoostMult
        else hum.JumpHeight = 7.2 * JumpBoostMult end
    end)
end

-- DESYNC (animation + light network break; full reverse = rejoin)
local DESYNC_ANIM_KEYWORDS = {
    "spike", "set", "bump", "receive", "attack", "hit", "swing", "dig",
}

local function isDesyncAnim(track)
    if not track then return false end
    local name = ""
    pcall(function()
        name = string.lower(tostring(track.Name or "") .. " " .. tostring(track.Animation and track.Animation.AnimationId or ""))
    end)
    for _, kw in ipairs(DESYNC_ANIM_KEYWORDS) do
        if name:find(kw, 1, true) then return true end
    end
    return false
end

local function stripCharacterAnims(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if isDesyncAnim(track) then
            pcall(function()
                track:Stop(0)
                track:Destroy()
            end)
        end
    end
end

local function disableDesync()
    for _, c in pairs(desyncConns) do
        pcall(function() c:Disconnect() end)
    end
    desyncConns = {}
    DesyncEnabled = false
end

local function enableDesync()
    if #desyncConns > 0 then return end
    DesyncEnabled = true

    -- Animation desync: hide spike/set/bump locally, keep jump
    local function hookChar(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        table.insert(desyncConns, animator.AnimationPlayed:Connect(function(track)
            if not DesyncEnabled then return end
            if isDesyncAnim(track) then
                pcall(function()
                    track:Stop(0)
                end)
            end
        end))
        stripCharacterAnims(char)
    end

    if LocalPlayer.Character then hookChar(LocalPlayer.Character) end
    table.insert(desyncConns, LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.2)
        if DesyncEnabled then hookChar(char) end
    end))

    -- Optional FFlags if executor supports setfflag (network desync)
    pcall(function()
        if type(setfflag) == "function" then
            setfflag("DFIntTimestepArbiterThresholdCappedMaxFrameMs", "999")
            setfflag("DFIntTimestepArbiterThresholdCappedMinFrameMs", "999")
            setfflag("DFIntS2PhysicsSenderRate", "15")
            setfflag("DFIntMaxInterpolationDistance", "0")
        end
    end)
end

-- CAMERA JUMP
UserInputService.JumpRequest:Connect(function()
    if AimbotCornerEnabled then return end
    if not CameraJumpEnabled then return end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local c = workspace.CurrentCamera
    if not c then return end
    local look = c.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude > 0 then
        root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
    end
end)

local function runMaxPowerSpike()
    if not MaxPowerSpikeEnabled then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local st = hum:GetState()
    if st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall then return end
    if hum.MoveDirection.Magnitude > 0.05 then return end
    maxPowerPhase = maxPowerPhase + 0.22
    hum:Move(Vector3.new(math.sin(maxPowerPhase), 0, math.cos(maxPowerPhase)), true)
end

-- ANTI-MOD
local function isModerator(name)
    local lower = string.lower(tostring(name or ""))
    for _, m in ipairs(moderatorList) do
        if lower:find(string.lower(m), 1, true) then return true end
    end
    return false
end

local function checkForModerators()
    if not AntiModEnabled then return end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isModerator(plr.Name) then
            notify("Moderator detected: " .. plr.Name .. " — leaving", 5)
            pcall(function() LocalPlayer:Kick("Anti-Mod: " .. plr.Name) end)
            return
        end
    end
end

Players.PlayerAdded:Connect(function(plr)
    if AntiModEnabled and isModerator(plr.Name) then
        notify("Moderator joined: " .. plr.Name, 5)
        pcall(function() LocalPlayer:Kick("Anti-Mod: " .. plr.Name) end)
    end
end)

-- STREAMER MODE
local function hidePlayerName(p)
    if not p or p == LocalPlayer then return end
    pcall(function()
        if streamerOriginalDisplay[p] == nil then
            streamerOriginalDisplay[p] = {
                DisplayName = p.DisplayName,
                Name = p.Name,
            }
        end
    end)
    local char = p.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            if streamerOriginalDisplay[p] and streamerOriginalDisplay[p].DisplayDistanceType == nil then
                streamerOriginalDisplay[p].DisplayDistanceType = hum.DisplayDistanceType
                streamerOriginalDisplay[p].NameDisplayDistance = hum.NameDisplayDistance
                streamerOriginalDisplay[p].HealthDisplayDistance = hum.HealthDisplayDistance
            end
            hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            hum.NameDisplayDistance = 0
            hum.HealthDisplayDistance = 0
        end)
    end
    -- hide nametag billboards / overhead text
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BillboardGui") then
            pcall(function()
                if not streamerOriginalDisplay[d] then
                    streamerOriginalDisplay[d] = d.Enabled
                end
                d.Enabled = false
            end)
        elseif d:IsA("TextLabel") or d:IsA("TextBox") then
            local parent = d.Parent
            if parent and (parent:IsA("BillboardGui") or parent:IsA("SurfaceGui")) then
                pcall(function()
                    if streamerOriginalDisplay[d] == nil then
                        streamerOriginalDisplay[d] = d.Text
                    end
                    d.Text = ""
                end)
            end
        end
    end
end

local function restorePlayerName(p)
    if not p then return end
    local char = p.Character
    if not char then return end
    local data = streamerOriginalDisplay[p]
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and type(data) == "table" then
        pcall(function()
            if data.DisplayDistanceType ~= nil then
                hum.DisplayDistanceType = data.DisplayDistanceType
            end
            if data.NameDisplayDistance ~= nil then
                hum.NameDisplayDistance = data.NameDisplayDistance
            end
            if data.HealthDisplayDistance ~= nil then
                hum.HealthDisplayDistance = data.HealthDisplayDistance
            end
        end)
    end
    for _, d in ipairs(char:GetDescendants()) do
        if streamerOriginalDisplay[d] ~= nil then
            pcall(function()
                if d:IsA("BillboardGui") then
                    d.Enabled = streamerOriginalDisplay[d] and true or false
                elseif d:IsA("TextLabel") or d:IsA("TextBox") then
                    d.Text = tostring(streamerOriginalDisplay[d])
                end
            end)
        end
    end
end

local function applyStreamerMode()
    for _, p in pairs(Players:GetPlayers()) do
        hidePlayerName(p)
    end
end

local function disableStreamerMode()
    for _, p in pairs(Players:GetPlayers()) do
        restorePlayerName(p)
    end
    streamerOriginalDisplay = {}
end

-- keep streamer applied on new characters
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        if StreamerModeEnabled then
            task.defer(function() hidePlayerName(p) end)
        end
    end)
end)
for _, p in pairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function()
        if StreamerModeEnabled then
            task.defer(function() hidePlayerName(p) end)
        end
    end)
end

-- PREDICT AIM
local function clearPredictAim()
    for plr, obj in pairs(PredictAimObjects) do
        pcall(function() if obj then obj:Destroy() end end)
        PredictAimObjects[plr] = nil
    end
end

local function updatePredictAim()
    if not PredictAimEnabled then return end
    local len = math.max(5, PredictAimLength or 25)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then
                if PredictAimObjects[plr] then
                    PredictAimObjects[plr]:Destroy()
                    PredictAimObjects[plr] = nil
                end
            else
                local dir = root.CFrame.LookVector
                local start = root.Position + Vector3.new(0, 1.5, 0)
                local finish = start + dir * len
                local line = PredictAimObjects[plr]
                if not line or not line.Parent then
                    line = Instance.new("Part")
                    line.Name = "PredictAimLine"
                    line.Anchored = true
                    line.CanCollide = false
                    line.CanQuery = false
                    line.Material = Enum.Material.Neon
                    line.Color = PredictAimColor
                    line.Transparency = 0.35
                    line.Parent = workspace
                    PredictAimObjects[plr] = line
                end
                local mid = (start + finish) / 2
                local dist = (finish - start).Magnitude
                line.Size = Vector3.new(0.2, 0.2, dist)
                line.CFrame = CFrame.lookAt(mid, finish)
                line.Color = PredictAimColor
            end
        end
    end
end

Players.PlayerRemoving:Connect(function(plr)
    if PredictAimObjects[plr] then
        PredictAimObjects[plr]:Destroy()
        PredictAimObjects[plr] = nil
    end
end)

-- SCORE EFFECT
local scoreEffect = "SupernovaScoreEffect"
local scoreEffectList = {}
local scoreEffectConns = {}
local scoreBusy, scoreScored = false, false

local function buildScoreEffectList()
    scoreEffectList = {}
    pcall(function()
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        if not assets then return end
        local se = assets:FindFirstChild("ScoreEffect")
        if se then
            for _, c in ipairs(se:GetChildren()) do
                if c:IsA("ModuleScript") then table.insert(scoreEffectList, c.Name) end
            end
        end
        local fx = assets:FindFirstChild("Effects")
        if fx then
            for _, n in ipairs({"GroundHit1", "GroundHit2"}) do
                if fx:FindFirstChild(n) then table.insert(scoreEffectList, n) end
            end
        end
    end)
    table.sort(scoreEffectList)
    if #scoreEffectList == 0 then table.insert(scoreEffectList, "SupernovaScoreEffect") end
end
buildScoreEffectList()

local function disableScoreEffect()
    for _, c in pairs(scoreEffectConns) do pcall(function() c:Disconnect() end) end
    scoreEffectConns = {}
    scoreBusy, scoreScored = false, false
end

local function enableScoreEffect()
    if #scoreEffectConns > 0 then return end
    local hitGround
    pcall(function()
        hitGround = ReplicatedStorage.Packages._Index["sleitnick_knit@1.7.0"].knit.Services.BallService.RE.HitGround
    end)
    if not hitGround then return end
    table.insert(scoreEffectConns, hitGround.OnClientEvent:Connect(function(...)
        for _, v in pairs({...}) do
            if tostring(v) == LocalPlayer.Name then scoreScored = true break end
        end
    end))
    local function fireFx(pos)
        if scoreBusy or not scoreScored or not ScoreEffectEnabled then return end
        scoreBusy = true
        local effectName, useAlt = scoreEffect, true
        if effectName == "GroundHit1" or effectName == "GroundHit2" then
            useAlt = effectName == "GroundHit2"
            effectName = nil
        end
        if firesignal then
            pcall(function()
                firesignal(hitGround.OnClientEvent, table.unpack({
                    pos, useAlt, false, 5, effectName,
                    workspace:FindFirstChild(LocalPlayer.Name),
                    Vector3.new(-0.0000020885916001134, 1, -0.000004710930170404),
                }, 1, 7))
            end)
        end
        task.wait(0.5)
        scoreBusy, scoreScored = false, false
    end
    table.insert(scoreEffectConns, workspace.ChildAdded:Connect(function(c)
        if c.Name == "HitIndicator" and c.Color == Color3.fromRGB(0, 255, 0) then fireFx(c.Position) end
    end))
end

-- POTATO MODE
local potatoSaved = {}
local function potatoSet(obj, prop, val)
    if not obj then return end
    local key = tostring(obj) .. "." .. prop
    if potatoSaved[key] == nil then
        local ok, v = pcall(function() return obj[prop] end)
        if ok then potatoSaved[key] = { obj = obj, prop = prop, val = v } end
    end
    pcall(function() obj[prop] = val end)
end

local function enablePotatoMode()
    potatoSet(Lighting, "GlobalShadows", false)
    potatoSet(Lighting, "FogEnd", 1e9)
    potatoSet(Lighting, "Brightness", 1)
    potatoSet(Lighting, "EnvironmentDiffuseScale", 0)
    potatoSet(Lighting, "EnvironmentSpecularScale", 0)
    pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
    pcall(function() Lighting.Ambient = Color3.fromRGB(120, 120, 120) end)
    pcall(function() Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 120) end)
    for _, c in ipairs(Lighting:GetChildren()) do
        if c:IsA("Sky") then
            potatoSet(c, "StarCount", 0)
            potatoSet(c, "CelestialBodiesShown", false)
        elseif c:IsA("Atmosphere") then
            potatoSet(c, "Density", 0)
            potatoSet(c, "Haze", 0)
        elseif c:IsA("BloomEffect") or c:IsA("BlurEffect") or c:IsA("SunRaysEffect")
            or c:IsA("ColorCorrectionEffect") or c:IsA("DepthOfFieldEffect") then
            potatoSet(c, "Enabled", false)
        end
    end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        potatoSet(terrain, "Decoration", false)
        potatoSet(terrain, "WaterWaveSize", 0)
    end
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    -- Only strip lights/particles in Map + characters (skip full workspace walk)
    local function stripFolder(folder)
        if not folder then return end
        for _, d in ipairs(folder:GetDescendants()) do
            if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
                potatoSet(d, "Enabled", false)
            elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
                or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                potatoSet(d, "Enabled", false)
            end
        end
    end
    stripFolder(workspace:FindFirstChild("Map"))
    for _, plr in pairs(Players:GetPlayers()) do
        stripFolder(plr.Character)
    end
end

local function disablePotatoMode()
    for _, data in pairs(potatoSaved) do
        if type(data) == "table" and data.obj and data.prop then
            pcall(function() data.obj[data.prop] = data.val end)
        end
    end
    potatoSaved = {}
end

local function doDataRollback()
    notify("Rollback: sending payload...", 4)
    local ok = pcall(function()
        local rf = ReplicatedStorage.Packages._Index["sleitnick_knit@1.7.0"].knit.Services.SettingsService.RF
        rf.UpdateKeybind:InvokeServer("MouseButton1", true, "Spike\143")
    end)
    if not ok then notify("Rollback failed", 5) return end
    notify("Rollback sent. Rejoining...", 4)
    task.wait(0.35)
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end

-- SINGLE THROTTLED LOOP
local tickCount = 0
local cornerMarksDimmed = false
local GREEN = Color3.fromRGB(0, 255, 170)
local DARK = Color3.fromRGB(25, 28, 30)

RunService.Heartbeat:Connect(function()
    tickCount = tickCount + 1

    -- Max power needs frequent updates when on
    if MaxPowerSpikeEnabled then
        pcall(runMaxPowerSpike)
    end

    -- Hitbox every 4 frames
    if HitboxEnabled and tickCount % 4 == 0 then
        pcall(modifyBallHitbox)
    end

    -- Serve UI every 3 frames
    if AutoStrongServeEnabled and tickCount % 3 == 0 then
        pcall(autoStrongServe)
    end

    -- Predict aim every 5 frames
    if PredictAimEnabled and tickCount % 5 == 0 then
        pcall(updatePredictAim)
    end

    -- Rare tasks
    if tickCount % 15 == 0 then
        if JumpBoostEnabled then pcall(applyJumpBoost) end
        if DesyncEnabled then pcall(stripCharacterAnims, LocalPlayer.Character) end
    end
    if StreamerModeEnabled and tickCount % 45 == 0 then
        pcall(applyStreamerMode)
    end
    if AntiModEnabled and tickCount % 60 == 0 then
        pcall(checkForModerators)
    end

    -- Corner aimbot (only when enabled)
    if AimbotCornerEnabled then
        cornerMarksDimmed = false
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            if tickCount % 12 == 0 then
                local map = workspace:FindFirstChild("Map")
                local court = map and map:FindFirstChild("Court")
                if court and (court.Position - courtCenter).Magnitude > 20 then
                    findCourt()
                    cornerMySide = nil
                    refreshMarks()
                end
                local s = getSide()
                if s and s ~= cornerMySide then
                    cornerMySide = s
                    refreshMarks()
                end
            end
            if not cornerPinning and tickCount % 2 == 0 then
                local pick = pickCorner()
                if pick then cornerCurrent = pick end
                leftMark.Color = (pick == "Left") and GREEN or DARK
                rightMark.Color = (pick == "Right") and GREEN or DARK
                leftMark.Transparency = (pick == "Left") and 0.15 or 0.35
                rightMark.Transparency = (pick == "Right") and 0.15 or 0.35
            end
            local air = hrp.AssemblyLinearVelocity.Y > 8
            if not cornerWasAir and air and os.clock() - cornerLastJump > 0.5 then
                doJumpAim()
            end
            cornerWasAir = air
        end
    elseif not cornerMarksDimmed then
        leftMark.Color = DARK
        rightMark.Color = DARK
        leftMark.Transparency = 0.35
        rightMark.Transparency = 0.35
        cornerWasAir = false
        cornerMarksDimmed = true
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    cornerMySide, cornerCurrent, cornerPinning = nil, nil, false
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Jumping:Connect(function(active)
            if active and AimbotCornerEnabled and os.clock() - cornerLastJump > 0.5 then
                task.wait(); doJumpAim()
            end
        end)
    end
end)

-- UI
task.wait(0.2)
local Window = Library:CreateWindow({
    Title = ScriptName, Center = true, AutoShow = true, Resizable = true,
    ShowCustomCursor = false, UnlockMouseWhileOpen = true, NotifySide = "Left",
    TabPadding = 8, MenuFadeTime = 0.15,
})

local Tabs = {
    Main = Window:AddTab("Main", "activity"),
    Boost = Window:AddTab("Boost", "zap"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Rollback = Window:AddTab("Rollback", "rotate-ccw"),
    Settings = Window:AddTab("Settings", "settings"),
}
local MainLeft = Tabs.Main:AddLeftGroupbox("Combat", "sword")
local MainRight = Tabs.Main:AddRightGroupbox("Aim & Serve", "target")
local BoostLeft = Tabs.Boost:AddLeftGroupbox("Jump", "arrow-up")
local BoostRight = Tabs.Boost:AddRightGroupbox("Spike", "zap")
local VisLeft = Tabs.Visuals:AddLeftGroupbox("Effects", "sparkles")
local VisRight = Tabs.Visuals:AddRightGroupbox("Performance", "gauge")
local RollbackBox = Tabs.Rollback:AddLeftGroupbox("Data Rollback", "rotate-ccw")
local SettingsLeft = Tabs.Settings:AddLeftGroupbox("Info", "info")
local SettingsRight = Tabs.Settings:AddRightGroupbox("Actions", "settings")

MainLeft:AddToggle("HitboxToggle", {
    Text = "Ball Hitbox", Default = false,
    Callback = function(v) HitboxEnabled = v; if not v then removeHitboxes() end; notify(v and "Hitbox ON" or "Hitbox OFF", 4) end,
})
MainLeft:AddSlider("HitboxSize", {
    Text = "Hitbox Size", Default = 10, Min = 0, Max = 50, Rounding = 0, Suffix = " studs",
    Callback = function(v) HitboxSize = v end,
})
MainLeft:AddLabel("Hitbox Color"):AddColorPicker("HitboxColor", {
    Default = HitboxColor, Callback = function(v) HitboxColor = v end,
})
MainLeft:AddDivider()
MainLeft:AddToggle("DirectionalHitToggle", {
    Text = "Directional Hit", Default = false,
    Callback = function(v) DirectionalHitEnabled = v end,
})
MainLeft:AddToggle("OfficialPathToggle", {
    Text = "Official Move Path", Default = true,
    Callback = function(v) OfficialPathEnabled = v end,
})
MainLeft:AddToggle("PerfectSpikeToggle", {
    Text = "Perfect Spike Assist", Default = true,
    Callback = function(v) PerfectSpikeAssistEnabled = v end,
})
MainLeft:AddToggle("MaxPowerSpikeToggle", {
    Text = "Max Power Spike (TSH)", Default = false,
    Tooltip = "Tiny movement while idle keeps spike meter full",
    Callback = function(v)
        MaxPowerSpikeEnabled = v
        notify(v and "Max Power Spike ON" or "Max Power Spike OFF", 4)
    end,
}):AddKeyPicker("MaxPowerSpikeKey", { Default = "T", SyncToggleState = true, Mode = "Toggle", Text = "Max Power Spike" })
MainLeft:AddToggle("SilentSpikeToggle", {
    Text = "Silent Spike", Default = false,
    Tooltip = "Ground spike via Spike remote only. No jump, no anim. Face camera. Tap Pico or press C.",
    Callback = function(v)
        SilentSpikeEnabled = v
        if v then
            createSilentSpikeButton()
            notify("Silent Spike ON — Spike remote, no jump (C / Pico)", 5)
        else
            destroySilentSpikeButton()
            notify("Silent Spike OFF", 4)
        end
    end,
}):AddKeyPicker("SilentSpikeKey", {
    Default = "C",
    Mode = "Hold",
    Text = "Silent Spike Key",
    Callback = function() end,
    ChangedCallback = function() end,
})
MainLeft:AddToggle("DesyncToggle", {
    Text = "Desync", Default = false,
    Tooltip = "Breaks local replication on purpose (hides spike/set anims). Some effects only fully reverse by rejoining.",
    Callback = function(v)
        if v then
            enableDesync()
            notify("Desync ON — rejoin to fully reverse", 6)
        else
            disableDesync()
            notify("Desync OFF (rejoin if still weird)", 5)
        end
    end,
})
MainLeft:AddToggle("AntiModToggle", {
    Text = "Anti-Moderator", Default = false,
    Tooltip = "Leave if a moderator joins",
    Callback = function(v)
        AntiModEnabled = v
        if v then checkForModerators() end
        notify(v and "Anti-Mod ON" or "Anti-Mod OFF", 4)
    end,
})

MainRight:AddToggle("CornerAimbotToggle", {
    Text = "Corner Aimbot", Default = false,
    Tooltip = "Corner Aimbot by RNCRAZY",
    Callback = function(v)
        AimbotCornerEnabled = v
        if v then cornerMySide = nil; refreshMarks(); notify("Corner Aimbot ON (RNCRAZY)", 5)
        else cornerPinning = false; cornerCurrent = nil; notify("Corner Aimbot OFF", 4) end
    end,
}):AddKeyPicker("CornerAimbotKey", { Default = "Z", SyncToggleState = true, Mode = "Toggle", Text = "Corner Aimbot" })
MainRight:AddLabel("Corner Aimbot by RNCRAZY")
MainRight:AddToggle("CameraJumpToggle", {
    Text = "Camera Jump", Default = false,
    Tooltip = "Face camera direction when jumping",
    Callback = function(v)
        CameraJumpEnabled = v
        notify(v and "Camera Jump ON" or "Camera Jump OFF", 4)
    end,
})
MainRight:AddDivider()
MainRight:AddToggle("AutoStrongServeUI", {
    Text = "Auto Strong Serve (UI)", Default = false,
    Callback = function(v) AutoStrongServeEnabled = v end,
})
MainRight:AddToggle("AutoStrongServeForce", {
    Text = "Force Strong Serve", Default = false,
    Callback = function(v) AutoStrongServeEveryServeEnabled = v end,
})
MainRight:AddSlider("ServePower", {
    Text = "Serve Boost Power", Default = 1, Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) ServeBoostPower = v end,
})

BoostLeft:AddToggle("JumpBoostToggle", {
    Text = "Jump Boost", Default = false,
    Callback = function(v) JumpBoostEnabled = v; if v then applyJumpBoost() end end,
})
BoostLeft:AddSlider("JumpBoostMult", {
    Text = "Jump Multiplier", Default = 1.35, Min = 1, Max = 2, Rounding = 2, Suffix = "x",
    Callback = function(v) JumpBoostMult = v; if JumpBoostEnabled then applyJumpBoost() end end,
})
BoostRight:AddToggle("SpikeBoostToggle", {
    Text = "Spike Boost", Default = false,
    Callback = function(v) SpikeBoostEnabled = v end,
})
BoostRight:AddSlider("SpikeCharge", {
    Text = "Spike Charge", Default = 1, Min = 0.5, Max = 1, Rounding = 2,
    Callback = function(v) SpikeBoostCharge = v end,
})

VisLeft:AddDropdown("ScoreEffectSelect", {
    Text = "Select Score Effect", Values = scoreEffectList,
    Default = scoreEffectList[1] or "SupernovaScoreEffect",
    Callback = function(v) if v then scoreEffect = v; notify("Effect: " .. v, 3) end end,
})
VisLeft:AddToggle("ScoreEffectToggle", {
    Text = "ScoreEffect Changer", Default = false,
    Callback = function(v)
        ScoreEffectEnabled = v
        if v then enableScoreEffect() else disableScoreEffect() end
    end,
})
VisLeft:AddToggle("PredictAimToggle", {
    Text = "Predict Aim", Default = false,
    Tooltip = "Show prediction lines on enemies",
    Callback = function(v)
        PredictAimEnabled = v
        if not v then clearPredictAim() end
        notify(v and "Predict Aim ON" or "Predict Aim OFF", 4)
    end,
})
VisLeft:AddSlider("PredictAimLength", {
    Text = "Prediction Length", Default = 25, Min = 5, Max = 50, Rounding = 0, Suffix = " studs",
    Callback = function(v) PredictAimLength = v end,
})
VisLeft:AddLabel("Predict Color"):AddColorPicker("PredictAimColor", {
    Default = PredictAimColor, Callback = function(v) PredictAimColor = v end,
})
VisRight:AddToggle("PotatoModeToggle", {
    Text = "Potato Mode", Default = false,
    Tooltip = "Lowest graphics for max FPS",
    Callback = function(v)
        PotatoModeEnabled = v
        if v then pcall(enablePotatoMode); notify("Potato Mode ON", 4)
        else pcall(disablePotatoMode); notify("Potato Mode OFF", 4) end
    end,
})
VisRight:AddToggle("StreamerModeToggle", {
    Text = "Streamer Mode", Default = false,
    Tooltip = "Hide other player names",
    Callback = function(v)
        StreamerModeEnabled = v
        if v then applyStreamerMode() else disableStreamerMode() end
        notify(v and "Streamer Mode ON" or "Streamer Mode OFF", 4)
    end,
})

SettingsLeft:AddLabel(ScriptName .. " v" .. ScriptVersion)
SettingsLeft:AddLabel("Last Updated: " .. LastUpdated)
SettingsLeft:AddDivider()
SettingsLeft:AddLabel("Creator: thiagxjzu3")
SettingsLeft:AddLabel("UI Library: Obsidian")
SettingsLeft:AddLabel("Enjoy the script!")

RollbackBox:AddLabel("Restores spent Yen / Spins")
RollbackBox:AddLabel("Sends a save payload then rejoins")
RollbackBox:AddLabel("Use after spending currency")
RollbackBox:AddDivider()
RollbackBox:AddButton({
    Text = "Run Rollback",
    Func = doDataRollback,
    Tooltip = "Send rollback payload and rejoin the game",
})
RollbackBox:AddLabel("You will be teleported automatically")

SettingsRight:AddLabel("Menu bind")
    :AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
SettingsRight:AddButton({
    Text = "Unload Script",
    Func = function()
        notify("Unloading", 3)
        HitboxEnabled = false
        AimbotCornerEnabled = false
        MaxPowerSpikeEnabled = false
        SilentSpikeEnabled = false
        PredictAimEnabled = false
        StreamerModeEnabled = false
        ScoreEffectEnabled = false
        PotatoModeEnabled = false
        AntiModEnabled = false
        pcall(disableDesync)
        pcall(disableScoreEffect)
        pcall(disablePotatoMode)
        pcall(disableStreamerMode)
        pcall(clearPredictAim)
        pcall(removeHitboxes)
        pcall(destroySilentSpikeButton)
        if cornerFolder then cornerFolder:Destroy() end
        Library:Unload()
    end,
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
        SaveManager:SetIgnoreIndexes({"MenuKeybind"})
        SaveManager:BuildConfigSection(Tabs.Settings)
        SaveManager:LoadAutoloadConfig()
    end
end)

task.spawn(function()
    while true do
        local waitTime = SilentSpikeEnabled and 0.08 or 0.35
        task.wait(waitTime)
        pcall(function()
            if Options.CornerAimbotKey and Toggles.CornerAimbotToggle then
                local s = Options.CornerAimbotKey:GetState()
                if s ~= AimbotCornerEnabled then
                    AimbotCornerEnabled = s
                    Toggles.CornerAimbotToggle:SetValue(s)
                end
            end
            if Options.MaxPowerSpikeKey and Toggles.MaxPowerSpikeToggle then
                local s = Options.MaxPowerSpikeKey:GetState()
                if s ~= MaxPowerSpikeEnabled then
                    MaxPowerSpikeEnabled = s
                    Toggles.MaxPowerSpikeToggle:SetValue(s)
                end
            end
            if SilentSpikeEnabled and Options.SilentSpikeKey and Options.SilentSpikeKey:GetState() then
                doSilentSpike()
            end
        end)
    end
end)

notify("Welcome to KingsHub by thiagxjzu3. Enjoy!", 8)
notify("KingsHub v" .. ScriptVersion .. " loaded | " .. LastUpdated, 5)
