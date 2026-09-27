-- =================================================================
-- 項目名稱：RIVALS UE HUB 高階自動瞬移盲區與爆頭殺戮系統
-- 設計理念：整合動態 GUI 面板與伺服器位置同步（Kill Aura & Back-Teleport）
-- =================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser") -- 模擬開槍必備服務

-- 全域配置表
getgenv().UE_Config = {
    AutoKill = false, -- 按鈕一：自動瞬移盲區+鎖頭爆頭
    AntiHit = false,  -- 按鈕二：防打擊（Desync）
    TP_Distance = 5   -- 瞬移到敵人後方的距離（單位：Studs）
}

-- =================================================================
-- 【GUI 面板渲染】: 完美復刻 UE HUB 雙分頁介面
-- =================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Rivals_UE_Hub_v3"
local success, err = pcall(function() ScreenGui.Parent = CoreGui end)
if not success then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 420, 0, 260)
MainFrame.Position = UDim2.new(0.3, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.2
MainStroke.Color = Color3.fromRGB(0, 120, 255)
MainStroke.Parent = MainFrame

local SideBar = Instance.new("Frame")
SideBar.Size = UDim2.new(0, 110, 1, 0)
SideBar.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
SideBar.BorderSizePixel = 0
SideBar.Parent = MainFrame

local SideCorner = Instance.new("UICorner")
SideCorner.CornerRadius = UDim.new(0, 8)
SideCorner.Parent = SideBar

local HubTitle = Instance.new("TextLabel")
HubTitle.Size = UDim2.new(1, 0, 0, 40)
HubTitle.BackgroundTransparency = 1
HubTitle.Text = "UE HUB v3"
HubTitle.TextColor3 = Color3.fromRGB(0, 180, 255)
HubTitle.TextSize = 14
HubTitle.Font = Enum.Font.Code
HubTitle.Parent = SideBar

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(0, 290, 0, 200)
ContentFrame.Position = UDim2.new(0, 120, 0, 50)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

-- 開關生成器
local toggleCount = 0
local function createToggle(name, configKey)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(0, 250, 0, 40)
    ToggleFrame.Position = UDim2.new(0, 10, 0, toggleCount * 45)
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    ToggleFrame.BorderSizePixel = 0
    ToggleFrame.Parent = ContentFrame
    
    local TCorner = Instance.new("UICorner")
    TCorner.CornerRadius = UDim.new(0, 6)
    TCorner.Parent = ToggleFrame

    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(0, 180, 1, 0)
    TextLabel.Position = UDim2.new(0, 10, 0, 0)
    TextLabel.BackgroundTransparency = 1
    TextLabel.Text = name
    TextLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel.TextSize = 11
    TextLabel.Font = Enum.Font.Code
    TextLabel.Parent = ToggleFrame

    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0, 50, 0, 24)
    Button.Position = UDim2.new(0, 190, 0, 8)
    Button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    Button.Text = "OFF"
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.Font = Enum.Font.Code
    Button.TextSize = 10
    Button.Parent = ToggleFrame
    
    local BCorner = Instance.new("UICorner")
    BCorner.CornerRadius = UDim.new(0, 4)
    BCorner.Parent = Button

    Button.MouseButton1Click:Connect(function()
        getgenv().UE_Config[configKey] = not getgenv().UE_Config[configKey]
        local state = getgenv().UE_Config[configKey]
        if state then
            Button.Text = "ON"
            TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 120, 255)}):Play()
        else
            Button.Text = "OFF"
            TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
        end
    end)
    toggleCount = toggleCount + 1
end

-- 部署你的專屬高科技功能按鈕
createToggle("⚡ Auto Teleport & Kill", "AutoKill")
createToggle("🛡️ Anti-Hit Desync (Bypass)", "AntiHit")

-- =================================================================
-- 【核心算法】: 最近目標獲取
-- =================================================================
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
                if distance < shortestDistance then
                    closestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end
    return closestPlayer
end

-- =================================================================
-- 【主循環】: 每幀執行瞬移盲區、強制鎖頭與自動開槍
-- =================================================================
RunService.RenderStepped:Connect(function()
    -- 功能一：當打開 AutoKill 開關時
    if getgenv().UE_Config.AutoKill then
        local target = getClosestPlayer()
        if target and target.Character and LocalPlayer.Character then
            local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local enemyRoot = target.Character:FindFirstChild("HumanoidRootPart")
            local enemyHead = target.Character:FindFirstChild("Head")

            if myRoot and enemyRoot and enemyHead then
                -- 1. 瞬移到敵人看不到的背後（盲區偏置計算）
                -- 利用敵人正向的相反向量（LookVector * -距離），把自己定位在敌人身後
                local behindPosition = enemyRoot.Position + (enemyRoot.CFrame.LookVector * -getgenv().UE_Config.TP_Distance) + Vector3.new(0, 1.5, 0)
                myRoot.CFrame = CFrame.new(behindPosition, enemyRoot.Position)

                -- 2. 視角死死鎖定敵人的頭部
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, enemyHead.Position)

                -- 3. 模擬自動點擊滑鼠左鍵開槍打頭
                -- 透過 VirtualUser 服務在底層直接發送 Button1Down（點擊滑鼠）事件
                pcall(function()
                    VirtualUser:Button1Down(Vector2.new(0, 0), Camera.CFrame)
                    task.wait()
                    VirtualUser:Button1Up(Vector2.new(0, 0), Camera.CFrame)
                end)
            end
        end
    end

    -- 功能二：防打擊殘影（Desync）
    if getgenv().UE_Config.AntiHit and LocalPlayer.Character then
        local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            myRoot.AssemblyLinearVelocity = Vector3.new(math.random(-600, 600), 0, math.random(-600, 600))
        end
    end
end)

print("[UE HUB v3] 瞬移盲區殺戮面板布署完畢。")
