-- =================================================================
-- 項目名稱：高階高科技位置解耦與平滑追蹤系統 (High-Tech Desync System)
-- 設計理念：轉化自客戶端位置偽裝與網路同步延遲（Desync）架構
-- =================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

-- 建立高科技配置全域變數
if not _G.HighTechConfig then
    _G.HighTechConfig = {
        Enabled = true,
        Smoothness = 0.2,       -- 鎖頭平滑度
        TeleportDistance = 6,    -- 瞬移到敵人身邊的距離（單位：Studs）
        AntiHitMode = true      -- 啟動防打擊不同步（Desync）機制
    }
end

-- 核心函數：尋找最近且生存的玩家
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

-- 主循環：負責處理「鎖頭」與「高科技位置偽裝」
local connection
connection = RunService.RenderStepped:Connect(function()
    if not _G.HighTechConfig.Enabled then
        if connection then connection:Disconnect() end
        return
    end

    local target = getClosestPlayer()
    if target and target.Character and LocalPlayer.Character then
        local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local enemyRoot = target.Character:FindFirstChild("HumanoidRootPart")
        local enemyHead = target.Character:FindFirstChild("Head")

        if myRoot and enemyRoot and enemyHead then
            
            -- =============================================================
            -- 功能一：高科技瞬移定位（保持在敵人旁邊，且自身保持高速運動）
            -- =============================================================
            -- 計算出敵人的後方或側邊位置（加上偏置距離）
            local offsetVector = Vector3.new(0, 2, _G.HighTechConfig.TeleportDistance) 
            local targetTeleportPos = enemyRoot.Position + (enemyRoot.CFrame.LookVector * -_G.HighTechConfig.TeleportDistance) + Vector3.new(0, 2, 0)
            
            -- 執行位置重寫
            myRoot.CFrame = CFrame.new(targetTeleportPos, enemyRoot.Position)

            -- =============================================================
            -- 功能二：高科技防打擊不同步（Anti-Hit Desync / 偽裝殘影）
            -- =============================================================
            if _G.HighTechConfig.AntiHitMode then
                -- 核心原理：在極短的幀率內，高頻率地讓角色的 Velocity（速度向量）在正負極端值之間切換
                -- 這會導致伺服器在計算你的位置時發生「插值失敗」，在敵人的畫面上你是一直在瞬移的殘影，子彈判定會全部落空
                myRoot.AssemblyLinearVelocity = Vector3.new(math.random(-500, 500), 0, math.random(-500, 500))
            end

            -- =============================================================
            -- 功能三：高階平滑鎖頭
            -- =============================================================
            local targetCFrame = CFrame.new(Camera.CFrame.Position, enemyHead.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, _G.HighTechConfig.Smoothness)
        end
    end
end)

print("[System] 高科技防打擊定位系統已成功布署。")
