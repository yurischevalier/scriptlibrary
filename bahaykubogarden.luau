--[[
    Bahay Kubo Garden - YuriGFX UI Auto Buy & Auto Harvest Script
    UI Library: YuriGFX (Source: https://raw.githubusercontent.com/yurischevalier/scriptlibrary/refs/heads/main/virex.lua)
    Game PlaceId: 81403703556465
--]]

task.spawn(function()

-- =========================================================================
-- 1. LOAD YuriGFX UI LIBRARY DIRECTLY FROM SOURCE
-- =========================================================================
local libraryUrl = "https://raw.githubusercontent.com/yurischevalier/scriptlibrary/refs/heads/main/virex.lua"
local successFetch, rawSource = pcall(function()
    return game:HttpGet(libraryUrl)
end)

if not successFetch or not rawSource then
    warn("[YuriGFX] Failed to fetch UI Library from: " .. libraryUrl)
    return
end

-- Extract the self-contained Library module from the repository
local libSource = rawSource:match("%[==%[(.-)%]==%]")
if not libSource then
    warn("[YuriGFX] Failed to extract Library source code from script.")
    return
end

-- Rename branding from VIREX / virex to YuriGFX / yurigfx
libSource = libSource:gsub("VIREX", "YuriGFX"):gsub("virex", "yurigfx")

-- Clean dropdown header display text for multi-selection (strip price tags in collapsed bar)
libSource = string.gsub(libSource, "selected = selected %.%. option %.%. ', '", function()
    return "selected = selected .. (option:gsub('%s*%b()', '')) .. ', '"
end)

local compileLib, compileErr = loadstring(libSource)
if not compileLib then
    warn("[YuriGFX] Failed to compile Library: " .. tostring(compileErr))
    return
end

local Library = compileLib()
local UI = Library._new()

-- =========================================================================
-- 2. SERVICES & REFERENCES
-- =========================================================================
local _cloneref = cloneref or function(x) return x end
local Players           = _cloneref(game:GetService("Players"))
local ReplicatedStorage = _cloneref(game:GetService("ReplicatedStorage"))
local UserInputService  = _cloneref(game:GetService("UserInputService"))
local TweenService      = _cloneref(game:GetService("TweenService"))
local CoreGui           = _cloneref(game:GetService("CoreGui"))

local LocalPlayer = Players.LocalPlayer

-- Custom Floating Notification (YuriGFX Styled)
local function Notify(title, content, duration)
    duration = duration or 2.5
    task.spawn(function()
        pcall(function()
            local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local parent = (gethui and gethui()) or CoreGui or playerGui
            if not parent then return end

            local gui = parent:FindFirstChild("YuriGFX_Notifications")
            if not gui then
                gui = Instance.new("ScreenGui")
                gui.Name = "YuriGFX_Notifications"
                gui.ResetOnSpawn = false
                gui.IgnoreGuiInset = true
                gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                gui.Parent = parent
            end

            local holder = gui:FindFirstChild("Holder")
            if not holder then
                holder = Instance.new("Frame")
                holder.Name = "Holder"
                holder.AnchorPoint = Vector2.new(1, 0)
                holder.Position = UDim2.new(1, -18, 0, 18)
                holder.Size = UDim2.fromOffset(320, 0)
                holder.BackgroundTransparency = 1
                holder.Parent = gui

                local layout = Instance.new("UIListLayout")
                layout.Padding = UDim.new(0, 8)
                layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
                layout.VerticalAlignment = Enum.VerticalAlignment.Top
                layout.Parent = holder
            end

            local frame = Instance.new("Frame")
            frame.Name = "Notification"
            frame.Size = UDim2.fromOffset(320, 64)
            frame.BackgroundColor3 = Color3.fromRGB(18, 19, 24)
            frame.BackgroundTransparency = 0.05
            frame.BorderSizePixel = 0
            frame.ClipsDescendants = true
            frame.Parent = holder

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 10)
            corner.Parent = frame

            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(255, 72, 92)
            stroke.Transparency = 0.35
            stroke.Thickness = 1
            stroke.Parent = frame

            local titleLabel = Instance.new("TextLabel")
            titleLabel.BackgroundTransparency = 1
            titleLabel.Position = UDim2.fromOffset(14, 8)
            titleLabel.Size = UDim2.new(1, -28, 0, 20)
            titleLabel.Font = Enum.Font.GothamBold
            titleLabel.Text = tostring(title)
            titleLabel.TextColor3 = Color3.fromRGB(255, 72, 92)
            titleLabel.TextSize = 13
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.Parent = frame

            local contentLabel = Instance.new("TextLabel")
            contentLabel.BackgroundTransparency = 1
            contentLabel.Position = UDim2.fromOffset(14, 28)
            contentLabel.Size = UDim2.new(1, -28, 0, 28)
            contentLabel.Font = Enum.Font.Gotham
            contentLabel.Text = tostring(content)
            contentLabel.TextColor3 = Color3.fromRGB(245, 245, 248)
            contentLabel.TextSize = 11
            contentLabel.TextWrapped = true
            contentLabel.TextXAlignment = Enum.TextXAlignment.Left
            contentLabel.TextYAlignment = Enum.TextYAlignment.Top
            contentLabel.Parent = frame

            frame.Position = UDim2.new(1, 25, 0, 0)
            TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 0, 0)
            }):Play()

            task.wait(duration)
            local out = TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 25, 0, 0),
                BackgroundTransparency = 1
            })
            out:Play()
            out.Completed:Wait()
            frame:Destroy()
        end)
    end)
end

-- =========================================================================
-- 3. CAMERA UNSTICK & PROTECTION LOGIC
-- =========================================================================
local function unstickCamera()
    pcall(function()
        local camera = workspace.CurrentCamera
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if camera and hrp then
            local dist = (camera.CFrame.Position - hrp.Position).Magnitude
            if dist < 6 then
                LocalPlayer.CameraMinZoomDistance = 18
                task.wait(0.04)
                LocalPlayer.CameraMinZoomDistance = 0.5
            end
        end
    end)
end

-- =========================================================================
-- 4. BAHAY KUBO GAME REMOTES & LOCALIZATION
-- =========================================================================
local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
if not Shared then
    Notify("Error", "ReplicatedStorage.Shared not found!", 4)
    return
end

local Remotes = Shared:WaitForChild("Remotes", 10)
local ShopRemotes = Remotes:WaitForChild("Shop", 10)
local ConfigFolder = Shared:WaitForChild("Config", 10)
local UtilitiesFolder = Shared:WaitForChild("Utilities", 10)
local CropConfig = require(ConfigFolder:WaitForChild("CropConfig"))
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local Language = require(Shared:WaitForChild("Language"))
local Format = UtilitiesFolder and require(UtilitiesFolder:WaitForChild("Format"))

local EconomyRemotes = Remotes:WaitForChild("Economy", 10)
local BuySeedRemote = ShopRemotes:WaitForChild("BuySeed")
local GetShopStateRemote = ShopRemotes:WaitForChild("GetShopState")
local StockChangedRemote = ShopRemotes:WaitForChild("StockChanged")
local GetSellTotalRemote = EconomyRemotes and EconomyRemotes:WaitForChild("GetSellTotal", 10)
local SellAllRemote = EconomyRemotes and EconomyRemotes:WaitForChild("SellAll", 10)

-- Build Crop Mappings (Internal Name <-> Display Name <-> Option Label with Price)
local internalToDisplay = {}
local displayToInternal = {}
local internalToOption = {}
local optionToInternal = {}
local cropPrices = {}
local cropRarities = {}
local dropdownOptions = {}
local cleanCropsList = {}

for _, internalName in ipairs(ShopConfig.SoldSeeds or {}) do
    local dispName = Language.Crop(internalName) or internalName
    local cropData = CropConfig.Crops[internalName] or {}
    local price = cropData.SeedPrice or 0
    local rarity = cropData.Rarity or "Common"

    local priceText = (Format and Format.Cash and Format.Cash(price)) or string.format("₱%s", tostring(price))
    local optionLabel = string.format("%s (%s)", dispName, priceText)

    internalToDisplay[internalName] = dispName
    displayToInternal[dispName] = internalName
    internalToOption[internalName] = optionLabel
    optionToInternal[optionLabel] = internalName
    cropPrices[internalName] = price
    cropRarities[internalName] = rarity

    table.insert(dropdownOptions, optionLabel)
    table.insert(cleanCropsList, dispName)
end

-- Sort dropdown options by price then name
table.sort(dropdownOptions, function(a, b)
    local intA = optionToInternal[a]
    local intB = optionToInternal[b]
    local pA = cropPrices[intA] or 0
    local pB = cropPrices[intB] or 0
    if pA ~= pB then
        return pA < pB
    end
    return a < b
end)

table.sort(cleanCropsList)

-- =========================================================================
-- 5. FEATURE STATE & HELPERS
-- =========================================================================
local Settings = {
    -- Auto Buy
    AutoBuyEnabled = false,
    BuyAllInStock = false,
    BuyOnRestock = true,
    BuyDelay = 0.15,
    SelectedSeeds = {}, -- Empty by default: user manually selects what to buy
    CurrentStock = {},
    NextRestock = 0,
    RunningPass = false,
    BuyLoopRunning = false,

    -- Auto Harvest / Plants (Strictly Farm Plot Only)
    AutoHarvestEnabled = true, -- Automatically loads enabled
    RunningHarvest = false,

    -- Auto Sell Plants (Customizable Threshold: 250, 500, 600, or slider)
    AutoSellEnabled = false,
    AutoSellThreshold = 250,
    CustomThreshold = 250,
    RunningSell = false,

    -- General
    ActiveConnections = {},
    CleaningUp = false,
}

-- Automatic Unload Function
local function unloadUI()
    if Settings.CleaningUp then return end
    Settings.CleaningUp = true
    Settings.AutoBuyEnabled = false
    Settings.BuyAllInStock = false
    Settings.AutoHarvestEnabled = false
    Settings.AutoSellEnabled = false
    Settings.RunningSell = false

    for _, conn in ipairs(Settings.ActiveConnections) do
        if conn and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        end
    end

    pcall(function()
        if UI and UI._ui then
            UI._ui:Destroy()
        end
    end)

    pcall(function()
        local parent = (gethui and gethui()) or CoreGui or (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui"))
        if parent then
            local toggle = parent:FindFirstChild("_yurigfx_toggle") or parent:FindFirstChild("_virex_toggle")
            if toggle then toggle:Destroy() end
            local notifs = parent:FindFirstChild("YuriGFX_Notifications") or parent:FindFirstChild("VIREX_Notifications")
            if notifs then notifs:Destroy() end
            local mainGui = parent:FindFirstChild("_yurigfx") or parent:FindFirstChild("_virex")
            if mainGui then mainGui:Destroy() end
        end
    end)

    Notify("YuriGFX", "UI unloaded successfully via Left Shift.", 2.5)
end

local function getPlayerPesos()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local pesos = leaderstats:FindFirstChild("Pesos")
        if pesos then
            if typeof(pesos.Value) == "number" then
                return pesos.Value
            elseif typeof(pesos.Value) == "string" then
                local cleanStr = pesos.Value:gsub("[^%d]", "")
                local num = tonumber(cleanStr)
                if num then return num end
            end
        end
        local money = leaderstats:FindFirstChild("Money")
        if money and typeof(money.Value) == "number" then
            return money.Value
        end
    end
    return 0
end

local function fetchShopState()
    local success, result = pcall(function()
        return GetShopStateRemote:InvokeServer()
    end)
    if success and type(result) == "table" then
        Settings.CurrentStock = result.Stock or {}
        Settings.NextRestock = result.NextRestock or 0
        return true
    end
    return false
end

-- Initial shop fetch
fetchShopState()

local function buyCrop(internalName)
    local price = cropPrices[internalName] or 0
    local myPesos = getPlayerPesos()

    if myPesos < price then
        return false
    end

    BuySeedRemote:FireServer(internalName)
    return true
end

local function executeBuyCycle(isManual)
    if Settings.RunningPass or Settings.CleaningUp then return 0 end
    Settings.RunningPass = true

    fetchShopState()

    local toBuy = {}
    for internalName, stockCount in pairs(Settings.CurrentStock) do
        if stockCount > 0 then
            local dispName = internalToDisplay[internalName] or internalName
            local optName = internalToOption[internalName] or dispName
            local price = cropPrices[internalName] or 0

            local shouldBuy = Settings.BuyAllInStock

            if not shouldBuy then
                shouldBuy = Settings.SelectedSeeds[optName] == true
                    or Settings.SelectedSeeds[dispName] == true
                    or Settings.SelectedSeeds[internalName] == true

                if not shouldBuy then
                    for selKey, isSelected in pairs(Settings.SelectedSeeds) do
                        if isSelected then
                            local cleanKey = tostring(selKey):gsub("%s*%b()", "")
                            if cleanKey == dispName or cleanKey == internalName then
                                shouldBuy = true
                                break
                            end
                        end
                    end
                end
            end

            if shouldBuy then
                table.insert(toBuy, {
                    internal = internalName,
                    display = dispName,
                    stock = stockCount,
                    price = price
                })
            end
        end
    end

    -- User requirement: Buy the HIGHEST PRICE first!
    table.sort(toBuy, function(a, b)
        if a.price ~= b.price then
            return a.price > b.price
        end
        return a.internal < b.internal
    end)

    local totalPurchased = 0
    for _, item in ipairs(toBuy) do
        if not Settings.AutoBuyEnabled and not Settings.BuyAllInStock and not isManual then
            break
        end
        if Settings.CleaningUp then break end

        -- User requirement: depends on money/wallet, buy highest price first but make sure it can buy
        local currentPesos = getPlayerPesos()
        if currentPesos < item.price then
            -- Cannot afford this expensive seed right now, skip to the next highest price seed we CAN afford
            continue
        end

        local countBought = 0
        for i = 1, item.stock do
            if not Settings.AutoBuyEnabled and not Settings.BuyAllInStock and not isManual then
                break
            end
            if Settings.CleaningUp then break end

            currentPesos = getPlayerPesos()
            if currentPesos < item.price then
                -- Cannot afford any more of this seed, break to buy cheaper seeds with remaining change
                break
            end

            local success = buyCrop(item.internal)
            if success then
                countBought = countBought + 1
                totalPurchased = totalPurchased + 1
                task.wait(Settings.BuyDelay)
            else
                break
            end
        end

        if countBought > 0 then
            Settings.CurrentStock[item.internal] = math.max(0, (Settings.CurrentStock[item.internal] or 0) - countBought)
        end
    end

    Settings.RunningPass = false
    return totalPurchased
end

-- Controller to ensure background Auto-Buy loop runs whenever either toggle is active
local function isAutoBuyActive()
    return (Settings.AutoBuyEnabled or Settings.BuyAllInStock) and not Settings.CleaningUp
end

local function ensureBuyLoop()
    if Settings.BuyLoopRunning then return end
    Settings.BuyLoopRunning = true
    task.spawn(function()
        while isAutoBuyActive() do
            pcall(function()
                executeBuyCycle(false)
            end)
            task.wait(math.max(Settings.BuyDelay, 0.4))
        end
        Settings.BuyLoopRunning = false
    end)
end

-- =========================================================================
-- 6. FARM & HARVEST LOGIC (STRICTLY ON PLAYER'S FARM PLOT)
-- =========================================================================
local function getPlayerFarm()
    local activeFarms = workspace:FindFirstChild("ActiveFarms")
    if not activeFarms then return nil end

    -- Check direct match by OwnerUserId attribute
    for _, farm in ipairs(activeFarms:GetChildren()) do
        if farm:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return farm
        end
    end

    -- Check by name Farm_<UserId>
    local farmName = "Farm_" .. tostring(LocalPlayer.UserId)
    local myFarm = activeFarms:FindFirstChild(farmName)
    if myFarm then return myFarm end

    -- Fallback check other attributes
    for _, farm in ipairs(activeFarms:GetChildren()) do
        if farm:GetAttribute("Owner") == LocalPlayer.UserId
            or farm:GetAttribute("OwnerName") == LocalPlayer.Name
            or farm:FindFirstChild(LocalPlayer.Name) then
            return farm
        end
    end

    return nil
end

local function getFarmPlantClusters()
    local myFarm = getPlayerFarm()
    if not myFarm then return {} end

    local plantsFolder = myFarm:FindFirstChild("Plants")
    if not plantsFolder then return {} end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end

    local clusters = {}

    -- Group ripe fruits by plant model strictly on the player's farm plot
    for _, plant in ipairs(plantsFolder:GetChildren()) do
        local ripePrompts = {}
        for _, desc in ipairs(plant:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.ActionText == "Pick" and desc.Enabled then
                local part = desc.Parent
                if part and part:IsA("BasePart") then
                    table.insert(ripePrompts, {
                        prompt = desc,
                        part = part,
                    })
                end
            end
        end

        if #ripePrompts > 0 then
            local primaryPart = plant.PrimaryPart or (ripePrompts[1] and ripePrompts[1].part)
            if primaryPart then
                local dist = (primaryPart.Position - hrp.Position).Magnitude
                table.insert(clusters, {
                    plant = plant,
                    primaryPart = primaryPart,
                    prompts = ripePrompts,
                    dist = dist,
                })
            end
        end
    end

    -- Nearest plants first
    table.sort(clusters, function(a, b)
        return a.dist < b.dist
    end)

    return clusters
end

local function executeSellCycle(isManual)
    if Settings.RunningSell or Settings.CleaningUp then return false end
    if not SellAllRemote or not GetSellTotalRemote then return false end
    Settings.RunningSell = true

    local sellSuccess = false

    local success, err = pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local sellData
        pcall(function()
            sellData = GetSellTotalRemote:InvokeServer()
        end)

        local currentCount = (sellData and sellData.Count) or 0
        if not isManual and currentCount < Settings.AutoSellThreshold then
            return
        end

        if currentCount <= 0 then
            if isManual then
                Notify("Auto Sell", "No harvested plants in inventory to sell!", 2)
            end
            return
        end

        -- Find Buyer prompt (workspace.SellProx)
        local sellProx = workspace:FindFirstChild("SellProx")
        if not sellProx then
            for _, desc in ipairs(workspace:GetDescendants()) do
                if desc.Name == "SellProx" and desc:IsA("BasePart") then
                    sellProx = desc
                    break
                end
            end
        end

        local sellPos = sellProx and sellProx.Position or Vector3.new(-374.4, 22.15, 609.3)
        local originalCFrame = hrp.CFrame

        -- Teleport safely in front of Buyer NPC
        hrp.CFrame = CFrame.new(sellPos + Vector3.new(0, 1.5, 3), sellPos)
        task.wait(0.08)

        -- Fire sell remote
        SellAllRemote:FireServer()
        task.wait(0.2)

        -- Smoothly return to farm plot and restore camera
        if hrp and hrp.Parent then
            pcall(function()
                hrp.CFrame = originalCFrame
            end)
            task.wait(0.04)
            unstickCamera()
        end

        sellSuccess = true
        local earnedCash = (Format and Format.CashFull and Format.CashFull(sellData.Total or 0)) or tostring(sellData.Total or 0)
        Notify("Auto Sell", string.format("Sold %d plants for ₱%s!", currentCount, earnedCash), 3)
    end)

    Settings.RunningSell = false
    return sellSuccess
end

local function executeHarvestPass(isManual)
    if Settings.RunningHarvest or Settings.CleaningUp then return 0 end
    Settings.RunningHarvest = true

    local harvestedCount = 0

    local success, err = pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local clusters = getFarmPlantClusters()
        if #clusters == 0 then
            return
        end

        local originalCFrame = hrp.CFrame
        local moved = false

        for _, cluster in ipairs(clusters) do
            if not Settings.AutoHarvestEnabled and not isManual then break end
            if Settings.CleaningUp then break end

            local targetPart = cluster.primaryPart or (cluster.prompts[1] and cluster.prompts[1].part)
            if targetPart and targetPart.Parent and hrp and hrp.Parent then
                local currentHrpPos = hrp.Position
                local targetPos = targetPart.Position
                local horizDiff = Vector3.new(currentHrpPos.X - targetPos.X, 0, currentHrpPos.Z - targetPos.Z)
                local dist = horizDiff.Magnitude

                -- Stand 4.5 studs outside the tree trunk in the approach direction to prevent camera clipping inside tree trunk
                local dir
                if dist > 0.5 then
                    dir = horizDiff.Unit
                else
                    dir = Vector3.new(0, 0, 1)
                end

                local standPos = Vector3.new(targetPos.X + dir.X * 4.5, currentHrpPos.Y, targetPos.Z + dir.Z * 4.5)
                local standDist = (standPos - currentHrpPos).Magnitude

                -- Teleport safely outside the plant
                if standDist > 6 then
                    hrp.CFrame = CFrame.lookAt(standPos, Vector3.new(targetPos.X, standPos.Y, targetPos.Z))
                    moved = true
                    task.wait(0.04) -- replication sync
                end

                -- Pick all ripe fruits on this plant with NO delay
                for _, item in ipairs(cluster.prompts) do
                    if not Settings.AutoHarvestEnabled and not isManual then break end
                    if Settings.CleaningUp then break end

                    local prompt = item.prompt
                    if prompt and prompt.Parent and prompt.Enabled then
                        pcall(function()
                            prompt:InputHoldBegin()
                            prompt:InputHoldEnd()
                        end)
                        if fireproximityprompt then
                            pcall(function()
                                fireproximityprompt(prompt, 0)
                            end)
                        end
                        harvestedCount = harvestedCount + 1
                    end
                end
            end
        end

        -- Smoothly restore player to initial position and unstick camera
        if moved and hrp and hrp.Parent then
            pcall(function()
                hrp.CFrame = originalCFrame
            end)
            task.wait(0.04)
            unstickCamera()
        end
    end)

    -- Guaranteed reset so harvest loop never gets stuck
    Settings.RunningHarvest = false

    if not success then
        warn("[YuriGFX] Harvest execution error: " .. tostring(err))
    end

    -- Trigger Auto Sell pass if enabled
    if Settings.AutoSellEnabled and not Settings.CleaningUp then
        task.spawn(function()
            task.wait(0.1)
            executeSellCycle(false)
        end)
    end

    return harvestedCount
end

-- =========================================================================
-- 7. BUILD YuriGFX UI (Main Tab Only)
-- =========================================================================
local Category = UI:create_category("YuriGFX")

-- MAIN TAB
local MainTab = Category:create_tab("Main", "76499042599127")

-- -------------------------------------------------------------------------
-- LEFT COLUMN: SEEDS (Auto Buy Controls)
-- -------------------------------------------------------------------------
local SeedsGroup = MainTab:create_group("Seeds", "left")

SeedsGroup:create_toggle("AutoBuyMaster", {
    title = "Auto Buy",
    default = false,
    callback = function(val)
        Settings.AutoBuyEnabled = val
        if val then
            Notify("Auto Buy", "Auto Buy loop activated!", 2)
            ensureBuyLoop()
        else
            Notify("Auto Buy", "Auto Buy paused.", 2)
        end
    end
})

-- Multi-selection Dropdown: options show prices like "Calamansi (₱7)", header displays clean "Calamansi, Corn" or "None"
SeedsGroup:create_dropdown("TargetSeedsDropdown", {
    title = "Target Seeds",
    options = dropdownOptions,
    multi = true,
    default = {}, -- Empty by default: user manually chooses what to buy
    callback = function(selected)
        if type(selected) == "table" then
            Settings.SelectedSeeds = selected
        end
    end
})

SeedsGroup:create_slider("BuyDelaySlider", {
    title = "Buy Delay",
    minimum = 0.05,
    maximum = 1.0,
    default = 0.15,
    rounding = true,
    callback = function(val)
        Settings.BuyDelay = val
    end
})

SeedsGroup:create_toggle("BuyAllInStockToggle", {
    title = "Buy All In-Stock",
    default = false,
    callback = function(val)
        Settings.BuyAllInStock = val
        if val then
            Notify("Buy All In-Stock", "Auto-buying all seeds (Highest price first)!", 2.5)
            ensureBuyLoop()
        else
            Notify("Buy All In-Stock", "Buy All In-Stock disabled.", 2)
        end
    end
})

SeedsGroup:create_toggle("BuyOnRestockToggle", {
    title = "Buy On Restock",
    default = true,
    callback = function(val)
        Settings.BuyOnRestock = val
    end
})

-- -------------------------------------------------------------------------
-- RIGHT COLUMN: PLANTS (Automatic Farm-Plot Harvesting)
-- -------------------------------------------------------------------------
local PlantsGroup = MainTab:create_group("Plants", "right")

PlantsGroup:create_toggle("AutoHarvestMaster", {
    title = "Auto Harvest",
    default = true, -- Automatically loads enabled!
    callback = function(val)
        Settings.AutoHarvestEnabled = val
        if val then
            Notify("Plants", "Auto Harvest activated on your plot!", 2)
            task.spawn(function()
                while Settings.AutoHarvestEnabled and not Settings.CleaningUp do
                    pcall(function()
                        executeHarvestPass(false)
                    end)
                    task.wait(0.5)
                end
            end)
        else
            Notify("Plants", "Auto Harvest paused.", 2)
        end
    end
})

PlantsGroup:create_toggle("AutoSellMaster", {
    title = "Auto Sell",
    default = false,
    callback = function(val)
        Settings.AutoSellEnabled = val
        if val then
            Notify("Auto Sell", "Auto Sell enabled (Threshold: " .. tostring(Settings.AutoSellThreshold) .. " plants)!", 2.5)
            task.spawn(function()
                executeSellCycle(false)
            end)
        else
            Notify("Auto Sell", "Auto Sell disabled.", 2)
        end
    end
})

PlantsGroup:create_dropdown("SellThresholdPreset", {
    title = "Threshold Preset",
    options = { "250 Plants", "500 Plants", "600 Plants", "Custom (Slider)" },
    multi = false,
    default = "250 Plants",
    callback = function(chosen)
        if chosen == "250 Plants" then
            Settings.AutoSellThreshold = 250
            Notify("Auto Sell", "Threshold set to 250 plants.", 2)
        elseif chosen == "500 Plants" then
            Settings.AutoSellThreshold = 500
            Notify("Auto Sell", "Threshold set to 500 plants.", 2)
        elseif chosen == "600 Plants" then
            Settings.AutoSellThreshold = 600
            Notify("Auto Sell", "Threshold set to 600 plants.", 2)
        elseif chosen == "Custom (Slider)" then
            Settings.AutoSellThreshold = Settings.CustomThreshold or 250
            Notify("Auto Sell", "Using custom threshold: " .. tostring(Settings.AutoSellThreshold) .. " plants.", 2)
        end
    end
})

PlantsGroup:create_slider("SellThresholdSlider", {
    title = "Sell Threshold",
    minimum = 25,
    maximum = 1000,
    default = 250,
    rounding = false,
    callback = function(val)
        val = math.floor(tonumber(val) or 250)
        Settings.CustomThreshold = val
        Settings.AutoSellThreshold = val
    end
})

PlantsGroup:create_button("SellNowButton", {
    title = "Sell All Now",
    callback = function()
        task.spawn(function()
            executeSellCycle(true)
        end)
    end
})

-- =========================================================================
-- 8. EVENT LISTENERS & BACKGROUND WORKERS
-- =========================================================================
local restockConn = StockChangedRemote.OnClientEvent:Connect(function(newStock, nextRestock)
    Settings.CurrentStock = newStock or {}
    if nextRestock then
        Settings.NextRestock = nextRestock
    end

    if Settings.BuyOnRestock and (Settings.AutoBuyEnabled or Settings.BuyAllInStock) then
        Notify("Restock Alert", "New seed stock detected! Running auto-buy...", 2)
        task.spawn(function()
            task.wait(0.05)
            pcall(function()
                executeBuyCycle(false)
            end)
        end)
    end
end)
table.insert(Settings.ActiveConnections, restockConn)

-- Recover state on character respawn
local charConn = LocalPlayer.CharacterAdded:Connect(function()
    Settings.RunningHarvest = false
    Settings.RunningPass = false
    Settings.RunningSell = false
    task.wait(1)
    unstickCamera()
end)
table.insert(Settings.ActiveConnections, charConn)

-- Automatic Unload on Left Shift Key
local shiftConn = UserInputService.InputBegan:Connect(function(input, processed)
    if input.KeyCode == Enum.KeyCode.LeftShift and not UserInputService:GetFocusedTextBox() then
        unloadUI()
    end
end)
table.insert(Settings.ActiveConnections, shiftConn)

-- Immediately pop camera out from inside any tree or mesh
unstickCamera()

-- Periodic camera unstick daemon: ensures camera never gets stuck inside trees or obstacles
task.spawn(function()
    while not Settings.CleaningUp do
        task.wait(1.5)
        pcall(function()
            local camera = workspace.CurrentCamera
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if camera and hrp and not Settings.RunningHarvest then
                local dist = (camera.CFrame.Position - hrp.Position).Magnitude
                if dist < 4.5 then
                    unstickCamera()
                end
            end
        end)
    end
end)

-- Periodic Auto Sell daemon: triggers sell if player inventory reaches or exceeds threshold
task.spawn(function()
    while not Settings.CleaningUp do
        task.wait(2.5)
        if Settings.AutoSellEnabled and not Settings.RunningHarvest and not Settings.RunningSell then
            pcall(function()
                executeSellCycle(false)
            end)
        end
    end
end)

-- Automatically start Auto Harvest loop on script load
task.spawn(function()
    task.wait(0.4)
    while Settings.AutoHarvestEnabled and not Settings.CleaningUp do
        pcall(function()
            executeHarvestPass(false)
        end)
        task.wait(0.5)
    end
end)

Notify("YuriGFX", "Main loaded! Press Left Shift to unload, Insert to toggle.", 3.5)

end)
