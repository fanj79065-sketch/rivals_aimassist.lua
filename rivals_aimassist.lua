-- =================================================================
-- 項目名稱：RIVALS UE HUB v5 (高階無聲鎖頭與硬體射擊修正系統)
-- 設計理念：轉化自射線重新導向（Raycast Redirect）與高頻射擊觸發技術
-- =================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

-- 引入 Roblox 高級模擬輸入（有些執行器專用，若無則使用高頻數據重寫）
local mouse1click = mouse1click or (Input and Input.mouse1click)

-- 全域配置表
getgenv().UE_Config = {
    AutoKill = false,
    AntiHit = false,
    SkinChanger = false,
    TP_Distance = 4,    -- 縮短瞬移距離，確保進入槍枝的射擊範圍
    Smoothness = 0.05   -- 降低平滑度，極速鎖定，防止鏡頭跟不上
}

-- =================================================================
-- 【GUI 面板渲染】 (保持完美的 UE HUB 介面結構)
-- =================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Rivals_UE_Hub_v5"
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

local MainCorner = Instance.new("UICorner") MainCorner.CornerRadius = UDim.new(0, 8); MainCorner.Parent = MainFrame
local MainStroke = Instance.new("UIStroke") MainStroke.Thickness = 1.2; MainStroke.Color = Color3.fromRGB(0, 120, 255); MainStroke.Parent = MainFrame
local SideBar = Instance.new("Frame") SideBar.Size = UDim2.new(0, 110, 1, 0); SideBar.BackgroundColor3 = Color3.fromRGB(12, 12, 16); SideBar.BorderSizePixel = 0; SideBar.Parent = MainFrame
local HubTitle = Instance.new("TextLabel") HubTitle.Size = UDim2.new(1, 0, 0, 40); HubTitle.BackgroundTransparency = 1; HubTitle.Text = "UE HUB v5"; HubTitle.TextColor3 = Color3.fromRGB(0, 180, 255); HubTitle.TextSize = 14; HubTitle.Font = Enum.Font.Code; HubTitle.Parent = SideBar
local ContentFrame = Instance.new("Frame") ContentFrame.Size = UDim2.new(0, 290, 0, 200); ContentFrame.Position = UDim2.new(0, 120, 0, 50); ContentFrame.BackgroundTransparency = 1; ContentFrame.Parent = MainFrame

local toggleCount = 0
local function createToggle(name, configKey)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(0, 250, 0, 40)
    ToggleFrame.Position = UDim2.new(0, 10, 0, toggleCount * 45)
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    ToggleFrame.BorderSizePixel = 0
    ToggleFrame.Parent = ContentFrame
    
    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(0, 180, 1, 0); TextLabel.Position = UDim2.new(0, 10, 0, 0); TextLabel.BackgroundTransparency = 1; TextLabel.Text = name; TextLabel.TextColor3 = Color3.fromRGB(200, 200, 200); TextLabel.TextSize = 11; TextLabel.Font = Enum.Font.Code; TextLabel.Parent = ToggleFrame
    local Button = Instance.new("TextButton") Button.Size = UDim2.new(0, 50, 0, 24); Button.Position = UDim2.new(0, 190, 0, 8); Button.BackgroundColor3 = Color3.fromRGB(60, 60, 60); Button.Text = "OFF"; Button.TextColor3 = Color3.fromRGB(255, 255, 255); Button.Font = Enum.Font.Code; Button.TextSize = 10; Button.Parent = ToggleFrame
    local BCorner = Instance.new("UICorner") BCorner.CornerRadius = UDim.new(0, 4); BCorner.Parent = Button

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
    local TCorner = Instance.new("UICorner") TCorner.CornerRadius = UDim.new(0, 6); TCorner.Parent = ToggleFrame
    toggleCount = toggleCount + 1
end

createToggle("⚡ Auto Teleport & Kill", "AutoKill")
createToggle("🛡️ Anti-Hit Desync (Bypass)", "AntiHit")
createToggle("🎨 Client Skin Changer", "SkinChanger")

-- =================================================================
-- 【高階技術核心】: 目標獲取與強制射擊同步
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

-- 處理開槍數據的底層事件監聽
RunService.RenderStepped:Connect(function()
    if getgenv().UE_Config.AutoKill then
        local target = getClosestPlayer()
        if target and target.Character and LocalPlayer.Character then
            local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local enemyRoot = target.Character:FindFirstChild("HumanoidRootPart")
            local enemyHead = target.Character:FindFirstChild("Head")

            if myRoot and enemyRoot and enemyHead then
                -- 1. 修正瞬移定位：移動到敵人的正後方，且稍微往下一點防止卡住武器射線
                local behindPosition = enemyRoot.Position + (enemyRoot.CFrame.LookVector * -getgenv().UE_Config.TP_Distance)
                myRoot.CFrame = CFrame.new(behindPosition, enemyRoot.Position)

                -- 2. 極速硬鎖：不再緩慢 Lerp，改為瞬間物理重寫相機朝向，死鎖頭部
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, enemyHead.Position)

                -- 3. 技術修正：突破《RIVALS》防禦的「硬體開槍模擬」
                -- 優先使用外掛環境的高階硬體模擬滑鼠點擊，若無則利用核心工具箱高頻觸發
                if mouse1click then
                    mouse1click() -- 執行硬體級滑鼠左鍵點擊
                else
                    -- 備用方案：高頻調用遊戲內部的開槍邏輯暫存區
                    local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("RemoteEvent") then
                        tool.RemoteEvent:FireServer(enemyHead.Position) -- 直接對伺服器發送「我擊中了頭部」的網路封包
                    end
                end
            end
        end
    end

    -- [其餘功能保持不變] Anti-Hit & SkinChanger...
    if getgenv().UE_Config.AntiHit and LocalPlayer.Character then
        local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then myRoot.AssemblyLinearVelocity = Vector3.new(math.random(-600, 600), 0, math.random(-600, 600)) end
    end
end)

print("[UE HUB v5] 射擊判定與開槍修正版部署完畢。")
