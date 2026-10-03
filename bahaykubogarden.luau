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

-- Allow group_manager:create_slider to return slider_frame for visibility control
local sliderPattern = "(function group_manager:create_slider.-user_input_service%.InputChanged:Connect.-end%s*%)%s*)(end%s*\n%s*function group_manager:create_button)"
libSource = libSource:gsub(sliderPattern, "%1\treturn slider_frame\n\t\t%2")

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
local EconomyRemotes = Remotes:WaitForChild("Economy", 10)
local FarmRemotes = Remotes:WaitForChild("Farm", 10)
local PetRemotes = Remotes:WaitForChild("Pets", 10)

local ConfigFolder = Shared:WaitForChild("Config", 10)
local UtilitiesFolder = Shared:WaitForChild("Utilities", 10)
local CropConfig = require(ConfigFolder:WaitForChild("CropConfig"))
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local Language = require(Shared:WaitForChild("Language"))
local Format = UtilitiesFolder and require(UtilitiesFolder:WaitForChild("Format"))

local PetConfig = nil
pcall(function()
    PetConfig = require(ConfigFolder:WaitForChild("PetConfig", 5))
end)

local BuySeedRemote = ShopRemotes:WaitForChild("BuySeed")
local GetShopStateRemote = ShopRemotes:WaitForChild("GetShopState")
local StockChangedRemote = ShopRemotes:WaitForChild("StockChanged")
local GetSellTotalRemote = EconomyRemotes and EconomyRemotes:WaitForChild("GetSellTotal", 10)
local SellAllRemote = EconomyRemotes and EconomyRemotes:WaitForChild("SellAll", 10)

local FarmGetUpgradeRemote = FarmRemotes and FarmRemotes:WaitForChild("GetUpgrade", 10)
local FarmUpgradeRemote = FarmRemotes and FarmRemotes:WaitForChild("UpgradeFarm", 10)
local GetEggShopRemote = PetRemotes and PetRemotes:WaitForChild("GetEggShop", 10)
local BuyEggRemote = PetRemotes and PetRemotes:WaitForChild("BuyEgg", 10)
local EggStockChangedRemote = PetRemotes and PetRemotes:WaitForChild("EggStockChanged", 10)

-- Helper to format numbers compactly with k / m (e.g. 77k, 100k, 1.1m, 3.5m)
local function formatPriceShort(price)
    price = tonumber(price) or 0
    if price >= 1000000 then
        local m = price / 1000000
        if m % 1 == 0 then
            return string.format("%dm", m)
        else
            return string.format("%.1fm", m)
        end
    elseif price >= 1000 then
        local k = price / 1000
        if k % 1 == 0 then
            return string.format("%dk", k)
        else
            return string.format("%.1fk", k)
        end
    else
        return tostring(price)
    end
end

-- Universal live price text parser from game GUI (handles "₱103 (+15%)", "₱3.5M", "₱110,000", "₱7", etc.)
local function parsePriceText(str)
    if not str or str == "" then return nil end
    local m = str:match("₱%s*([%d%.]+)%s*[Mm]")
    if m then
        return math.floor(tonumber(m) * 1000000 + 0.5)
    end
    local k = str:match("₱%s*([%d%.]+)%s*[Kk]")
    if k then
        return math.floor(tonumber(k) * 1000 + 0.5)
    end
    local base = str:match("₱%s*([%d%,]+)")
    if base then
        local clean = base:gsub(",", "")
        return tonumber(clean)
    end
    return nil
end

-- Dynamic Seed Price resolver: dynamically updates for market surges (+15%) or server changes
local function getSeedPrice(internalName)
    local livePrice = nil
    pcall(function()
        local sf = LocalPlayer.PlayerGui.GUI.Frames.SeedsShop.ScrollingFrame
        local item = sf:FindFirstChild(internalName)
        if item then
            local pLbl = item:FindFirstChild("Price", true)
            if pLbl and pLbl.Text then
                livePrice = parsePriceText(pLbl.Text)
            end
        end
    end)
    if livePrice and livePrice > 0 then
        return livePrice
    end

    if CropConfig and CropConfig.Crops and CropConfig.Crops[internalName] then
        local p = tonumber(CropConfig.Crops[internalName].SeedPrice)
        if p and p > 0 then
            return p
        end
    end

    return 0
end

-- Dynamic Egg Price resolver: reads authoritative PetConfig or live UI card
local function getEggPrice(eggId)
    if PetConfig and PetConfig.Eggs and PetConfig.Eggs[eggId] then
        local p = tonumber(PetConfig.Eggs[eggId].Price)
        if p and p > 0 then
            return p
        end
    end

    local livePrice = nil
    pcall(function()
        local sf = LocalPlayer.PlayerGui.GUI.Frames.EggsShop.ScrollingFrame
        local item = sf:FindFirstChild(eggId)
        if item then
            local pLbl = item:FindFirstChild("Price", true)
            if pLbl and pLbl.Text then
                livePrice = parsePriceText(pLbl.Text)
            end
        end
    end)
    if livePrice and livePrice > 0 then
        return livePrice
    end

    return 0
end

-- Build Crop Mappings (Internal Name <-> Display Name <-> Option Label with Compact Price)
-- Format: "Coffee (₱77k)", "Java Plum (₱100k)", "Mangosteen (₱3.8k)"
local internalToDisplay = {}
local displayToInternal = {}
local internalToOption = {}
local optionToInternal = {}
local cropPrices = {}
local cropRarities = {}
local dropdownOptionsList = {}

for _, internalName in ipairs(ShopConfig.SoldSeeds or {}) do
    local dispName = Language.Crop(internalName) or internalName
    local cropData = CropConfig.Crops[internalName] or {}
    local price = getSeedPrice(internalName)
    if price <= 0 then
        price = cropData.SeedPrice or 0
    end
    local rarity = cropData.Rarity or "Common"

    local priceText = string.format("₱%s", formatPriceShort(price))
    local optionLabel = string.format("%s (%s)", dispName, priceText)

    internalToDisplay[internalName] = dispName
    displayToInternal[dispName] = internalName
    internalToOption[internalName] = optionLabel
    optionToInternal[optionLabel] = internalName
    cropPrices[internalName] = price
    cropRarities[internalName] = rarity

    table.insert(dropdownOptionsList, {
        label = optionLabel,
        price = price,
        disp = dispName
    })
end

-- Sort dropdown options by price then name
table.sort(dropdownOptionsList, function(a, b)
    if a.price ~= b.price then
        return a.price < b.price
    end
    return a.disp < b.disp
end)

local seedOptionStrings = {}
for _, item in ipairs(dropdownOptionsList) do
    table.insert(seedOptionStrings, item.label)
end

-- Build Dynamic Egg List: loads all purchasable eggs directly from game's PetConfig / UI
local function buildDynamicEggList()
    local list = {}
    if PetConfig and PetConfig.Eggs then
        for eggId, data in pairs(PetConfig.Eggs) do
            if type(data) == "table" and type(data.Price) == "number" and not data.Robux then
                local dispName = data.DisplayName or (Language and Language.Egg and Language.Egg(eggId)) or eggId
                table.insert(list, {
                    id = eggId,
                    disp = dispName,
                    price = data.Price,
                    hatchTime = data.HatchTime or 0
                })
            end
        end
    end

    if #list == 0 then
        list = {
            { id = "AncientEgg", disp = "Legendary Egg", price = 3500000 },
            { id = "MysticEgg", disp = "Epic Egg", price = 400000 },
            { id = "ProvincialEgg", disp = "Rare Egg", price = 110000 },
            { id = "FarmEgg", disp = "Uncommon Egg", price = 12000 },
            { id = "BasicEgg", disp = "Common Egg", price = 3000 },
        }
    end

    table.sort(list, function(a, b)
        if a.price ~= b.price then
            return a.price > b.price
        end
        return a.disp < b.disp
    end)

    return list
end

local EggList = buildDynamicEggList()
local eggOptionStrings = {}
for _, egg in ipairs(EggList) do
    egg.price = getEggPrice(egg.id)
    egg.priceText = string.format("₱%s", formatPriceShort(egg.price))
    egg.label = string.format("%s (%s)", egg.disp, egg.priceText)
    table.insert(eggOptionStrings, egg.label)
end

-- =========================================================================
-- 5. FEATURE STATE & HELPERS
-- =========================================================================
local Settings = {
    -- Auto Buy Seeds
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
    HarvestLoopRunning = false,

    -- Auto Sell Plants (Customizable Threshold: 250, 500, 600, or slider)
    AutoSellEnabled = false,
    AutoSellThreshold = 250,
    CustomThreshold = 250,
    RunningSell = false,

    -- Land Upgrades
    AutoUpgradeHouse = false,
    AutoUpgradePlot = false,
    RunningLandUpgrade = false,

    -- Eggs Auto Buy
    EggSniperEnabled = false,
    SnipeOnRestock = true,
    SnipeDelay = 0.15,
    SelectedEggs = {},
    CurrentEggStock = {},
    NextEggRestock = 0,
    RunningEggSnipe = false,

    -- General
    ActiveConnections = {},
    CleaningUp = false,
}

-- Dynamically select the top tier eggs by default
for i = 1, math.min(3, #EggList) do
    Settings.SelectedEggs[EggList[i].label] = true
end

-- Automatic Unload Function
local function unloadUI()
    if Settings.CleaningUp then return end
    Settings.CleaningUp = true
    Settings.AutoBuyEnabled = false
    Settings.BuyAllInStock = false
    Settings.AutoHarvestEnabled = false
    Settings.AutoSellEnabled = false
    Settings.AutoUpgradeHouse = false
    Settings.AutoUpgradePlot = false
    Settings.EggSniperEnabled = false
    Settings.RunningSell = false
    Settings.RunningHarvest = false
    Settings.RunningPass = false
    Settings.RunningLandUpgrade = false
    Settings.RunningEggSnipe = false

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

local function isAutoBuyActive()
    return (Settings.AutoBuyEnabled or Settings.BuyAllInStock) and not Settings.CleaningUp
end

local function executeBuyCycle(isManual)
    if Settings.RunningPass or Settings.CleaningUp then return 0 end
    Settings.RunningPass = true

    -- Fetch latest stock if empty or triggered manually
    if next(Settings.CurrentStock) == nil or isManual then
        fetchShopState()
    end

    local toBuy = {}
    for internalName, stockCount in pairs(Settings.CurrentStock) do
        if stockCount > 0 then
            local dispName = internalToDisplay[internalName] or internalName
            local optName = internalToOption[internalName] or dispName
            local price = getSeedPrice(internalName)
            if price <= 0 then
                price = cropPrices[internalName] or 0
            end

            local shouldBuy = Settings.BuyAllInStock

            if not shouldBuy then
                shouldBuy = Settings.SelectedSeeds[optName] == true
                    or Settings.SelectedSeeds[dispName] == true
                    or Settings.SelectedSeeds[internalName] == true

                if not shouldBuy then
                    local cleanDisp = dispName:lower():gsub("%s+", "")
                    local cleanInternal = internalName:lower():gsub("%s+", "")

                    for selKey, isSelected in pairs(Settings.SelectedSeeds) do
                        if isSelected then
                            local cleanKey = tostring(selKey):gsub("%s*%b()", ""):lower():gsub("%s+", "")
                            if cleanKey == cleanDisp or cleanKey == cleanInternal then
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

    local simulatedPesos = getPlayerPesos()
    local totalPurchased = 0

    for _, item in ipairs(toBuy) do
        if not isAutoBuyActive() and not isManual then
            break
        end
        if Settings.CleaningUp then break end

        -- Skip item if we can't afford even a single seed at dynamic live price, move to cheaper seeds
        local livePrice = getSeedPrice(item.internal)
        if livePrice <= 0 then livePrice = item.price end

        if simulatedPesos < livePrice then
            continue
        end

        local countBought = 0
        for _ = 1, item.stock do
            if not isAutoBuyActive() and not isManual then
                break
            end
            if Settings.CleaningUp then break end

            local actualPesos = getPlayerPesos()
            if actualPesos < simulatedPesos then
                simulatedPesos = actualPesos
            end

            livePrice = getSeedPrice(item.internal)
            if livePrice <= 0 then livePrice = item.price end

            if simulatedPesos < livePrice then
                -- Can't afford more of this seed; move to cheaper seeds with remaining change
                break
            end

            BuySeedRemote:FireServer(item.internal)
            simulatedPesos = simulatedPesos - livePrice
            countBought = countBought + 1
            totalPurchased = totalPurchased + 1
            task.wait(Settings.BuyDelay)
        end

        if countBought > 0 then
            Settings.CurrentStock[item.internal] = math.max(0, (Settings.CurrentStock[item.internal] or 0) - countBought)
        end
    end

    Settings.RunningPass = false
    return totalPurchased
end

local function ensureBuyLoop()
    if Settings.BuyLoopRunning then return end
    Settings.BuyLoopRunning = true
    task.spawn(function()
        while isAutoBuyActive() do
            pcall(function()
                executeBuyCycle(false)
            end)
            task.wait(math.max(Settings.BuyDelay, 0.5))
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

-- Land Upgrades Executor
local function executeLandUpgrade(track, isManual)
    if Settings.RunningLandUpgrade or Settings.CleaningUp then return false end
    if not FarmGetUpgradeRemote or not FarmUpgradeRemote then return false end

    Settings.RunningLandUpgrade = true
    local upgraded = false

    local success, err = pcall(function()
        local upgradeData = FarmGetUpgradeRemote:InvokeServer()
        if type(upgradeData) ~= "table" then return end

        local info = upgradeData[track]
        if type(info) ~= "table" then return end

        local trackTitle = (track == "Plot" and "Backyard") or track
        local currentName = info.CurrentName or trackTitle
        local nextName = info.NextName or (trackTitle .. " " .. tostring(info.NextLevel or 2))
        local cost = tonumber(info.Cost) or 0
        local isMaxed = info.Maxed == true
        local isAffordable = info.Affordable == true or (getPlayerPesos() >= cost and cost > 0)

        if isMaxed then
            if isManual then
                Notify("Land Upgrade", string.format("%s is already at max level!", trackTitle), 2.5)
            end
            return
        end

        if not isAffordable then
            if isManual then
                local missing = math.max(0, cost - getPlayerPesos())
                Notify("Land Upgrade", string.format("Need ₱%s more for %s!", formatPriceShort(missing), nextName), 3)
            end
            return
        end

        FarmUpgradeRemote:FireServer(track)
        upgraded = true
        Notify("Land Upgrade", string.format("Upgrading %s to %s for ₱%s!", currentName, nextName, formatPriceShort(cost)), 3.5)
        task.wait(0.5)
    end)

    Settings.RunningLandUpgrade = false
    return upgraded
end

-- Egg Sniper Helpers & Executor
local function fetchEggShopState()
    if not GetEggShopRemote then return false end
    local success, result = pcall(function()
        return GetEggShopRemote:InvokeServer()
    end)
    if success and type(result) == "table" then
        Settings.CurrentEggStock = result.Stock or {}
        Settings.NextEggRestock = result.NextRestock or 0
        return true
    end
    return false
end

-- Initial egg shop fetch
fetchEggShopState()

local function executeEggSnipe(isManual)
    if Settings.RunningEggSnipe or Settings.CleaningUp then return 0 end
    if not BuyEggRemote then return 0 end

    Settings.RunningEggSnipe = true
    local totalSniped = 0

    local success, err = pcall(function()
        if next(Settings.CurrentEggStock) == nil or isManual then
            fetchEggShopState()
        end

        local simulatedPesos = getPlayerPesos()

        -- Process eggs in priority order (Highest tier first)
        for _, egg in ipairs(EggList) do
            if not Settings.EggSniperEnabled and not isManual then break end
            if Settings.CleaningUp then break end

            local isSelected = false
            if Settings.SelectedEggs[egg.label] == true
                or Settings.SelectedEggs[egg.disp] == true
                or Settings.SelectedEggs[egg.id] == true then
                isSelected = true
            else
                local cleanEgg = egg.disp:lower():gsub("%s+", "")
                for selKey, val in pairs(Settings.SelectedEggs) do
                    if val then
                        local cleanKey = tostring(selKey):gsub("%s*%b()", ""):lower():gsub("%s+", "")
                        if cleanKey == cleanEgg or cleanKey == egg.id:lower() then
                            isSelected = true
                            break
                        end
                    end
                end
            end

            local availableStock = Settings.CurrentEggStock[egg.id] or 0
            if isSelected and availableStock > 0 then
                -- Live egg price directly from authoritative game data / live UI
                local liveEggPrice = getEggPrice(egg.id)
                if liveEggPrice <= 0 then liveEggPrice = egg.price or 0 end

                if simulatedPesos < liveEggPrice then
                    continue
                end

                local countBought = 0
                for _ = 1, availableStock do
                    if not Settings.EggSniperEnabled and not isManual then break end
                    if Settings.CleaningUp then break end

                    local actualPesos = getPlayerPesos()
                    if actualPesos < simulatedPesos then
                        simulatedPesos = actualPesos
                    end

                    liveEggPrice = getEggPrice(egg.id)
                    if liveEggPrice <= 0 then liveEggPrice = egg.price or 0 end

                    if simulatedPesos < liveEggPrice then
                        break
                    end

                    BuyEggRemote:FireServer(egg.id)
                    simulatedPesos = simulatedPesos - liveEggPrice
                    countBought = countBought + 1
                    totalSniped = totalSniped + 1

                    Notify("Eggs", string.format("Bought %s for ₱%s!", egg.disp, formatPriceShort(liveEggPrice)), 2.5)
                    task.wait(Settings.SnipeDelay)
                end

                if countBought > 0 then
                    Settings.CurrentEggStock[egg.id] = math.max(0, (Settings.CurrentEggStock[egg.id] or 0) - countBought)
                end
            end
        end
    end)

    Settings.RunningEggSnipe = false
    return totalSniped
end

local function executeSellCycle(isManual)
    if Settings.RunningSell or Settings.CleaningUp then return false end
    if not SellAllRemote or not GetSellTotalRemote then return false end

    -- If currently in the middle of teleporting harvest pass, wait briefly for it to return
    if Settings.RunningHarvest then
        return false
    end

    Settings.RunningSell = true
    local sellSuccess = false

    local _ok, _execErr = pcall(function()
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

        local originalCFrame = hrp.CFrame
        local sellPos = sellProx and sellProx.Position or Vector3.new(-374.4, 22.15, 609.3)

        -- Teleport safely directly in front of Buyer NPC
        hrp.CFrame = CFrame.new(sellPos + Vector3.new(0, 1.5, 2), sellPos)
        task.wait(0.2) -- Replication sync so the server acknowledges the position

        -- Fire sell remote
        SellAllRemote:FireServer()
        task.wait(0.2)

        -- Smoothly return to original position and restore camera
        if hrp and hrp.Parent then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.CFrame = originalCFrame
            end)
            task.wait(0.04)
            unstickCamera()
        end

        sellSuccess = true
        local earnedCash = (Format and Format.CashFull and Format.CashFull(sellData.Total or 0)) or tostring(sellData.Total or 0)
        Notify("Auto Sell", string.format("Sold %d plants for ₱%s!", currentCount, earnedCash), 3)

        -- Immediately trigger land upgrade check if enabled (synergy with cash gained)
        if (Settings.AutoUpgradePlot or Settings.AutoUpgradeHouse) and not Settings.CleaningUp and not Settings.RunningLandUpgrade then
            task.spawn(function()
                task.wait(0.3)
                if Settings.AutoUpgradePlot then
                    executeLandUpgrade("Plot", false)
                end
                if Settings.AutoUpgradeHouse then
                    executeLandUpgrade("House", false)
                end
            end)
        end
    end)

    Settings.RunningSell = false
    return sellSuccess
end

local function executeHarvestPass(isManual)
    if Settings.RunningHarvest or Settings.RunningSell or Settings.CleaningUp then return 0 end
    Settings.RunningHarvest = true

    local harvestedCount = 0

    local _ok, _err = pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp then return end

        local myFarm = getPlayerFarm()
        if not myFarm then return end

        local plantsFolder = myFarm:FindFirstChild("Plants")
        if not plantsFolder then return end

        -- Fast group ripe prompts by plant model for instant multi-picking
        local ripePlants = {}
        for _, plant in ipairs(plantsFolder:GetChildren()) do
            local prompts = {}
            for _, desc in ipairs(plant:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.ActionText == "Pick" and desc.Enabled then
                    local part = desc.Parent
                    if part and part:IsA("BasePart") then
                        table.insert(prompts, {
                            prompt = desc,
                            part = part,
                        })
                    end
                end
            end
            if #prompts > 0 then
                table.insert(ripePlants, {
                    plant = plant,
                    prompts = prompts,
                    firstPart = prompts[1].part,
                    dist = (prompts[1].part.Position - hrp.Position).Magnitude
                })
            end
        end

        if #ripePlants == 0 then
            return
        end

        -- Sort nearest plant first for seamless navigation
        table.sort(ripePlants, function(a, b)
            return a.dist < b.dist
        end)

        -- Save where the player is currently standing
        local originalCFrame = hrp.CFrame
        local moved = false

        for _, plantData in ipairs(ripePlants) do
            if not Settings.AutoHarvestEnabled and not isManual then break end
            if Settings.CleaningUp then break end

            local firstPart = plantData.firstPart
            if firstPart and firstPart.Parent and hrp and hrp.Parent then
                -- Teleport directly onto the plant's fruit cluster
                hrp.CFrame = CFrame.new(firstPart.Position + Vector3.new(0, 0.5, 0))
                moved = true
                task.wait() -- Single frame yield: ultra-fast yet reliable

                for _, pData in ipairs(plantData.prompts) do
                    local prompt = pData.prompt
                    local part = pData.part
                    if prompt and prompt.Parent and prompt.Enabled and hrp and hrp.Parent then
                        -- If fruit is farther out on wide branches, hop directly to it
                        if part and (part.Position - hrp.Position).Magnitude > 8 then
                            hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 0.5, 0))
                        end

                        if fireproximityprompt then
                            fireproximityprompt(prompt)
                        else
                            pcall(function()
                                prompt:InputHoldBegin()
                                task.wait(prompt.HoldDuration or 0)
                                prompt:InputHoldEnd()
                            end)
                        end
                        harvestedCount = harvestedCount + 1
                    end
                end
            end
        end

        -- Smoothly restore player to the exact spot where they were standing
        if moved and hrp and hrp.Parent then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.CFrame = originalCFrame
            end)
            if hum and hum.Health > 0 then
                hum.PlatformStand = false
                hum.Sit = false
            end
            task.wait(0.04)
            unstickCamera()
        end
    end)

    Settings.RunningHarvest = false

    -- Immediately trigger Auto Sell right after harvest finishes so inventory is sold without delay
    if Settings.AutoSellEnabled and not Settings.CleaningUp and not Settings.RunningSell then
        task.spawn(function()
            executeSellCycle(false)
        end)
    end

    return harvestedCount
end

local function ensureHarvestLoop()
    if Settings.HarvestLoopRunning then return end
    Settings.HarvestLoopRunning = true
    task.spawn(function()
        while Settings.AutoHarvestEnabled and not Settings.CleaningUp do
            pcall(function()
                executeHarvestPass(false)
            end)
            task.wait(0.5)
        end
        Settings.HarvestLoopRunning = false
    end)
end

-- =========================================================================
-- 7. BUILD YuriGFX UI (Main and Upgrader Tabs)
-- =========================================================================
local Category = UI:create_category("YuriGFX")

-- -------------------------------------------------------------------------
-- TAB 1: MAIN
-- -------------------------------------------------------------------------
local MainTab = Category:create_tab("Main", "76499042599127")

-- LEFT COLUMN: SEEDS (Auto Buy Controls)
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

-- Multi-selection Dropdown: options formatted cleanly with compact price e.g. "Coffee (₱77k)", "Java Plum (₱100k)"
SeedsGroup:create_dropdown("TargetSeedsDropdown", {
    title = "Target Seeds",
    options = seedOptionStrings,
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

-- RIGHT COLUMN: PLANTS (Automatic Farm-Plot Harvesting & Selling)
local PlantsGroup = MainTab:create_group("Plants", "right")

PlantsGroup:create_toggle("AutoHarvestMaster", {
    title = "Auto Harvest",
    default = true, -- Automatically loads enabled!
    callback = function(val)
        Settings.AutoHarvestEnabled = val
        if val then
            Notify("Plants", "Auto Harvest activated on your plot!", 2)
            ensureHarvestLoop()
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

local sellSlider

local function updateSliderVisibility(chosen)
    local isCustom = (chosen == "Custom" or chosen == "Custom (Slider)")
    if sellSlider and typeof(sellSlider) == "Instance" then
        sellSlider.Visible = isCustom
    end
    if PlantsGroup and PlantsGroup._frame then
        for _, child in ipairs(PlantsGroup._frame:GetChildren()) do
            if child:IsA("Frame") then
                local lbl = child:FindFirstChildWhichIsA("TextLabel")
                if lbl and (lbl.Text == "Custom Threshold" or lbl.Text == "Sell Threshold") then
                    child.Visible = isCustom
                    break
                end
            end
        end
    end
end

-- Threshold Preset title: "AutoSell When reach out in ..."
PlantsGroup:create_dropdown("SellThresholdPreset", {
    title = "AutoSell When reach out in ...",
    options = { "250 Plants", "500 Plants", "600 Plants", "Custom" },
    multi = false,
    default = "250 Plants",
    callback = function(chosen)
        if chosen == "250 Plants" then
            Settings.AutoSellThreshold = 250
            updateSliderVisibility(chosen)
            Notify("Auto Sell", "AutoSell threshold set to 250 plants.", 2)
        elseif chosen == "500 Plants" then
            Settings.AutoSellThreshold = 500
            updateSliderVisibility(chosen)
            Notify("Auto Sell", "AutoSell threshold set to 500 plants.", 2)
        elseif chosen == "600 Plants" then
            Settings.AutoSellThreshold = 600
            updateSliderVisibility(chosen)
            Notify("Auto Sell", "AutoSell threshold set to 600 plants.", 2)
        elseif chosen == "Custom" or chosen == "Custom (Slider)" then
            Settings.AutoSellThreshold = Settings.CustomThreshold or 250
            updateSliderVisibility(chosen)
            Notify("Auto Sell", "Using custom threshold: " .. tostring(Settings.AutoSellThreshold) .. " plants.", 2)
        end

        -- Immediately check if current inventory satisfies new threshold
        if Settings.AutoSellEnabled and not Settings.RunningSell and not Settings.RunningHarvest then
            task.spawn(function()
                executeSellCycle(false)
            end)
        end
    end
})

sellSlider = PlantsGroup:create_slider("SellThresholdSlider", {
    title = "Custom Threshold",
    minimum = 25,
    maximum = 1000,
    default = 250,
    rounding = false,
    callback = function(val)
        val = math.floor(tonumber(val) or 250)
        Settings.CustomThreshold = val
        Settings.AutoSellThreshold = val

        -- Immediately trigger sell if inventory is already at or above new custom threshold
        if Settings.AutoSellEnabled and not Settings.RunningSell and not Settings.RunningHarvest then
            task.spawn(function()
                executeSellCycle(false)
            end)
        end
    end
})

-- Only show slider if dropdown is Custom! Hide by default.
updateSliderVisibility("250 Plants")

PlantsGroup:create_button("SellNowButton", {
    title = "Sell All Now",
    callback = function()
        task.spawn(function()
            executeSellCycle(true)
        end)
    end
})

-- -------------------------------------------------------------------------
-- LEFT COLUMN: LAND UPGRADES (Inside Main Tab)
-- -------------------------------------------------------------------------
local LandGroup = MainTab:create_group("Land Upgrades", "left")

LandGroup:create_toggle("AutoUpgradePlotToggle", {
    title = "Auto Backyard",
    default = false,
    callback = function(val)
        Settings.AutoUpgradePlot = val
        if val then
            Notify("Land Upgrades", "Auto Backyard enabled!", 2)
            task.spawn(function()
                executeLandUpgrade("Plot", false)
            end)
        else
            Notify("Land Upgrades", "Auto Backyard paused.", 2)
        end
    end
})

LandGroup:create_toggle("AutoUpgradeHouseToggle", {
    title = "Auto House",
    default = false,
    callback = function(val)
        Settings.AutoUpgradeHouse = val
        if val then
            Notify("Land Upgrades", "Auto House enabled!", 2)
            task.spawn(function()
                executeLandUpgrade("House", false)
            end)
        else
            Notify("Land Upgrades", "Auto House paused.", 2)
        end
    end
})

LandGroup:create_button("UpgradePlotButton", {
    title = "Upgrade Backyard Now",
    callback = function()
        task.spawn(function()
            executeLandUpgrade("Plot", true)
        end)
    end
})

LandGroup:create_button("UpgradeHouseButton", {
    title = "Upgrade House Now",
    callback = function()
        task.spawn(function()
            executeLandUpgrade("House", true)
        end)
    end
})

LandGroup:create_button("CheckUpgradeStatusButton", {
    title = "Check Upgrade Costs",
    callback = function()
        task.spawn(function()
            local success, upData = pcall(function()
                return FarmGetUpgradeRemote:InvokeServer()
            end)
            if success and type(upData) == "table" then
                local plotInfo = upData.Plot
                local houseInfo = upData.House
                local pText = (plotInfo and type(plotInfo) == "table") and (plotInfo.Maxed and "Maxed" or string.format("%s (₱%s)", plotInfo.NextName or "Next", formatPriceShort(plotInfo.Cost or 0))) or "N/A"
                local hText = (houseInfo and type(houseInfo) == "table") and (houseInfo.Maxed and "Maxed" or string.format("%s (₱%s)", houseInfo.NextName or "Next", formatPriceShort(houseInfo.Cost or 0))) or "N/A"
                Notify("Upgrade Status", string.format("Backyard: %s\nHouse: %s", pText, hText), 4)
            else
                Notify("Upgrade Status", "Failed to retrieve upgrade information.", 2.5)
            end
        end)
    end
})

-- -------------------------------------------------------------------------
-- RIGHT COLUMN: EGGS (Inside Main Tab)
-- -------------------------------------------------------------------------
local EggGroup = MainTab:create_group("Eggs", "right")

EggGroup:create_toggle("EggSniperMasterToggle", {
    title = "Auto Buy",
    default = false,
    callback = function(val)
        Settings.EggSniperEnabled = val
        if val then
            Notify("Eggs", "Egg Auto Buy activated! Monitoring stock...", 2)
            task.spawn(function()
                executeEggSnipe(false)
            end)
        else
            Notify("Eggs", "Egg Auto Buy paused.", 2)
        end
    end
})

local defaultSelectedEggs = {}
for i = 1, math.min(3, #EggList) do
    table.insert(defaultSelectedEggs, EggList[i].label)
end

EggGroup:create_dropdown("TargetEggsDropdown", {
    title = "Target Eggs",
    options = eggOptionStrings,
    multi = true,
    default = defaultSelectedEggs,
    callback = function(selected)
        if type(selected) == "table" then
            Settings.SelectedEggs = selected
        end
    end
})

EggGroup:create_toggle("SnipeOnRestockToggle", {
    title = "Buy On Restock",
    default = true,
    callback = function(val)
        Settings.SnipeOnRestock = val
    end
})

EggGroup:create_slider("SnipeDelaySlider", {
    title = "Buy Delay",
    minimum = 0.05,
    maximum = 1.0,
    default = 0.15,
    rounding = true,
    callback = function(val)
        Settings.SnipeDelay = val
    end
})

EggGroup:create_button("SnipeNowButton", {
    title = "Buy Available Now",
    callback = function()
        task.spawn(function()
            local sniped = executeEggSnipe(true)
            if sniped == 0 then
                Notify("Eggs", "No target eggs available or affordable right now.", 2.5)
            end
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

if EggStockChangedRemote then
    local eggRestockConn = EggStockChangedRemote.OnClientEvent:Connect(function(newStock, nextRestock)
        Settings.CurrentEggStock = newStock or {}
        if nextRestock then
            Settings.NextEggRestock = nextRestock
        end

        if Settings.EggSniperEnabled and Settings.SnipeOnRestock then
            Notify("Egg Restock", "Egg stock refreshed! Sniping target eggs...", 2)
            task.spawn(function()
                task.wait(0.05)
                pcall(function()
                    executeEggSnipe(false)
                end)
            end)
        end
    end)
    table.insert(Settings.ActiveConnections, eggRestockConn)
end

if FarmUpgradeRemote then
    local farmUpgradeConn = FarmUpgradeRemote.OnClientEvent:Connect(function(track, success)
        if success then
            local trackTitle = (track == "Plot" and "Backyard") or tostring(track)
            Notify("Land Upgrade", string.format("%s was upgraded successfully!", trackTitle), 3.5)
        end
    end)
    table.insert(Settings.ActiveConnections, farmUpgradeConn)
end

if BuyEggRemote then
    local buyEggConn = BuyEggRemote.OnClientEvent:Connect(function(eggId, success, errMsg)
        if not success and errMsg then
            warn("[Egg Sniper]", eggId, errMsg)
        end
    end)
    table.insert(Settings.ActiveConnections, buyEggConn)
end

-- Recover state on character respawn
local charConn = LocalPlayer.CharacterAdded:Connect(function()
    Settings.RunningHarvest = false
    Settings.RunningPass = false
    Settings.RunningSell = false
    Settings.RunningLandUpgrade = false
    Settings.RunningEggSnipe = false
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

-- Responsive Auto Sell daemon: triggers sell if player inventory reaches or exceeds threshold
task.spawn(function()
    while not Settings.CleaningUp do
        task.wait(1.0)
        if Settings.AutoSellEnabled and not Settings.RunningSell and not Settings.RunningHarvest then
            pcall(function()
                executeSellCycle(false)
            end)
        end
    end
end)

-- Auto Land Upgrades background daemon
task.spawn(function()
    while not Settings.CleaningUp do
        task.wait(2.5)
        if (Settings.AutoUpgradePlot or Settings.AutoUpgradeHouse) and not Settings.RunningLandUpgrade and not Settings.RunningHarvest and not Settings.RunningSell then
            pcall(function()
                if Settings.AutoUpgradePlot then
                    executeLandUpgrade("Plot", false)
                end
                if Settings.AutoUpgradeHouse then
                    executeLandUpgrade("House", false)
                end
            end)
        end
    end
end)

-- Egg Sniper periodic background daemon
task.spawn(function()
    while not Settings.CleaningUp do
        task.wait(1.5)
        if Settings.EggSniperEnabled and not Settings.RunningEggSnipe and not Settings.RunningHarvest and not Settings.RunningSell then
            pcall(function()
                executeEggSnipe(false)
            end)
        end
    end
end)

-- Automatically start Auto Harvest loop on script load
task.spawn(function()
    task.wait(0.4)
    ensureHarvestLoop()
end)

Notify("YuriGFX", "Main loaded! Press Left Shift to unload, Insert to toggle.", 3.5)

end)
